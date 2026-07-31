import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'modelos.dart';

/// Open Library: abierta, gratis y sin clave.
/// Es floja en ediciones latinoamericanas, y esta demo sirve justamente
/// para medir cuánto le falta con los libros que lee tu comunidad.
class Api {
  static const _campos =
      'key,title,author_name,cover_i,first_publish_year,publisher,number_of_pages_median';

  /// Open Library pide que las apps se identifiquen con un User-Agent, y
  /// en Android y iOS se lo mandamos. **En web no**, y no es un descuido:
  ///
  /// User-Agent es una cabecera "prohibida" para el navegador. Al pedirla,
  /// dispara una consulta previa de permiso (preflight), y Open Library
  /// responde que solo acepta Accept, Accept-Language, Content-Language y
  /// Content-Type. User-Agent no está en la lista, así que el navegador
  /// cancela el pedido **antes de mandarlo**: la búsqueda no funcionaba
  /// en la versión web y sí en la de escritorio.
  ///
  /// Sin la cabecera es un pedido "simple", no hay preflight, y anda.
  static Map<String, String> get _cabeceras =>
      kIsWeb ? const {} : const {'User-Agent': 'Colibri/0.1 (demo)'};

  static Future<List<Libro>> buscar(String consulta) async {
    if (consulta.trim().length < 3) return [];

    final uri = Uri.https('openlibrary.org', '/search.json', {
      'q': consulta.trim(),
      'limit': '20',
      'fields': _campos,
    });

    final respuesta = await http
        .get(uri, headers: _cabeceras)
        .timeout(const Duration(seconds: 15));

    if (respuesta.statusCode != 200) return [];

    final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
    final docs = (datos['docs'] as List?) ?? const [];
    return docs
        .map((d) => Libro.desdeOpenLibrary(d as Map<String, dynamic>))
        .toList();
  }

  /// Un solo resultado, para resolver los libros de la biblioteca de ejemplo.
  static Future<Libro?> primero(String titulo, String autor) async {
    final r = await buscar('$titulo $autor');
    return r.isEmpty ? null : r.first;
  }

  /// Las ediciones de una obra, para poder elegir la que una tiene.
  ///
  /// # Por qué hace falta una segunda consulta
  ///
  /// La búsqueda de Open Library encuentra el libro en cualquier idioma
  /// —probado con español, portugués, francés y japonés— pero **siempre
  /// devuelve el título de la obra original**. Buscás "harry potter y la
  /// piedra filosofal" y te contesta "Harry Potter and the Philosopher's
  /// Stone", que no es el libro que tenés en la mano.
  ///
  /// El título traducido vive en las ediciones, no en la obra, y no hay
  /// forma de traerlo en la misma consulta: probamos con el filtro de
  /// idioma, con los títulos alternativos y con el campo `editions`, y
  /// ninguna lo devuelve. Así que se piden aparte, y solo cuando alguien
  /// quiere cambiar de edición.
  ///
  /// [idioma] es el código de tres letras: spa, por, eng, fre, ita.
  static Future<List<Libro>> ediciones(
    Libro obra, {
    String? idioma,
    int maximo = 40,
  }) async {
    // El id de la obra viene de la búsqueda, con la forma /works/OL123W.
    if (!obra.id.startsWith('/works/')) return const [];

    final uri = Uri.https('openlibrary.org', '${obra.id}/editions.json', {
      'limit': '200',
    });

    final respuesta = await http
        .get(uri, headers: _cabeceras)
        .timeout(const Duration(seconds: 20));
    if (respuesta.statusCode != 200) return const [];

    final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
    final entradas = (datos['entries'] as List?) ?? const [];

    final salida = <Libro>[];
    for (final e in entradas.cast<Map<String, dynamic>>()) {
      final idiomas = ((e['languages'] as List?) ?? const [])
          .map((l) => ((l as Map)['key'] as String?) ?? '')
          .map((k) => k.split('/').last)
          .toList();

      if (idioma != null && !idiomas.contains(idioma)) continue;

      final tapas = (e['covers'] as List?)?.whereType<int>().toList();
      final editoriales = (e['publishers'] as List?)?.cast<String>();

      salida.add(
        Libro(
          id: (e['key'] as String?) ?? '${obra.id}-${salida.length}',
          titulo: (e['title'] as String?) ?? obra.titulo,
          autor: obra.autor,
          tapaId: (tapas == null || tapas.isEmpty) ? null : tapas.first,
          editorial: (editoriales == null || editoriales.isEmpty)
              ? null
              : editoriales.first,
          anio: _anio(e['publish_date'] as String?),
          paginas: e['number_of_pages'] as int?,
        ),
      );

      if (salida.length >= maximo) break;
    }

    // Primero las que tienen tapa: son las que sirven para elegir.
    salida.sort((a, b) {
      if ((a.tapaId != null) == (b.tapaId != null)) return 0;
      return a.tapaId != null ? -1 : 1;
    });
    return salida;
  }

  /// Las fechas vienen de mil formas: "2018", "08/08/2015", "Jun 04, 2020".
  /// Lo único que siempre está es el año, así que sacamos eso.
  static int? _anio(String? fecha) {
    if (fecha == null) return null;
    final m = RegExp(r'(1[5-9]\d{2}|20[0-4]\d)').firstMatch(fecha);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// La tapa. 'M' para la grilla, 'L' para la ficha.
  ///
  /// El `?default=false` es clave: sin eso Open Library devuelve un
  /// cuadradito gris en vez de un 404 cuando no tiene la tapa, y terminás
  /// mostrando basura que parece una portada.
  static String? urlTapa(int? tapaId, {String tamano = 'M'}) {
    if (tapaId == null) return null;
    return 'https://covers.openlibrary.org/b/id/$tapaId-$tamano.jpg?default=false';
  }
}
