import 'dart:convert';

import 'package:http/http.dart' as http;

import 'isbn.dart';
import 'modelos.dart';

/// Google Books: el segundo catálogo.
///
/// # Por qué hace falta un segundo
///
/// Open Library encuentra bien por título —probamos con narrativa
/// latinoamericana de ahora y los encontró todos— pero flaquea en dos
/// puntos, y los dos los medimos:
///
/// 1. **Por código de barras.** De un clásico en castellano tiene unas
///    cincuenta ediciones con ISBN; de la narrativa latinoamericana
///    reciente tiene una, y de algunos títulos ninguna. El escáner falla
///    ahí, no en otro lado.
/// 2. **En qué idioma contesta.** Open Library devuelve el título de la
///    obra original. Google devuelve el de la edición, que es el que está
///    impreso en el libro que tenés en la mano.
///
/// # Por qué la clave no es opcional
///
/// Google Books contesta sin clave, pero mete a todo el mundo en un mismo
/// proyecto anónimo compartido. Al probarlo, la respuesta fue:
///
/// > Quota exceeded for quota metric 'Queries' and limit 'Queries per day'
/// > … for consumer 'project_number:624717413613'
///
/// Ese número no es nuestro: es de todos. La cuota del día ya estaba
/// agotada por gente que no conocemos, y eso pasa casi siempre. Sin clave
/// esto no funciona de forma confiable para nadie.
///
/// # Dónde vive la clave
///
/// **No está en el código y no puede estar**, porque este repositorio es
/// público. Entra al compilar:
///
///     flutter run -d chrome --dart-define=GOOGLE_BOOKS=tu_clave
///
/// Si no se pasa ninguna, [disponible] queda en falso y la app funciona
/// exactamente como antes: sin Google, sin errores y sin avisos raros.
/// Nunca se rompe por falta de clave.
///
/// # Una advertencia honesta
///
/// Una clave que viaja dentro de una app es pública: cualquiera puede
/// sacarla del archivo instalado. No hay forma de esconderla del lado del
/// que la usa, en ninguna app de ningún lenguaje. Lo que sí se hace es
/// **limitarla** desde el panel de Google —que solo funcione desde tu
/// dirección web y solo para la API de libros—, y cuando exista servidor
/// propio, moverla ahí.
class Google {
  /// Se fija al compilar, no al ejecutar. Por eso es `const`: si no se
  /// pasa ninguna, el compilador se lleva puesto todo este código y ni
  /// siquiera queda en la app.
  static const clave = String.fromEnvironment('GOOGLE_BOOKS');

  static bool get disponible => clave.isNotEmpty;

  static Future<List<Libro>> buscar(String consulta, {int maximo = 12}) async {
    if (!disponible || consulta.trim().length < 3) return const [];

    return _pedir({
      'q': consulta.trim(),
      'maxResults': '$maximo',
      // Solo libros: sin esto vuelven revistas y previews sueltas.
      'printType': 'books',
    });
  }

  /// El libro de un código de barras.
  ///
  /// Es el motivo principal por el que este catálogo está acá. Google usa
  /// `isbn:` como prefijo igual que Open Library, así que la consulta se
  /// parece; lo que cambia es qué tan seguido contesta.
  static Future<Libro?> porIsbn(String isbn) async {
    if (!disponible) return null;

    final codigo = Isbn.aTrece(isbn);
    if (codigo == null) return null;

    final encontrados = await _pedir({
      'q': 'isbn:$codigo',
      'maxResults': '1',
      'printType': 'books',
    });
    return encontrados.isEmpty ? null : encontrados.first;
  }

  /// El único lugar que habla con Google.
  ///
  /// Se traga cualquier problema y devuelve una lista vacía. Es a
  /// propósito: este catálogo es **el segundo**, y que se caiga no puede
  /// dejar sin buscar a alguien que igual iba a encontrar su libro en
  /// Open Library.
  static Future<List<Libro>> _pedir(Map<String, String> consulta) async {
    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      ...consulta,
      'key': clave,
    });

    try {
      final respuesta = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));

      if (respuesta.statusCode != 200) return const [];

      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      final items = (datos['items'] as List?) ?? const [];

      return [
        for (final v in items) Libro.desdeGoogle(v as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }
}
