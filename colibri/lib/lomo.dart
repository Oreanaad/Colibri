import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'foto.dart';
import 'modelos.dart';

/// Cómo se ve el lomo de cada libro en la repisa.
///
/// # Las dos formas de que un lomo se parezca al libro
///
/// **La foto.** Alguien saca una foto del canto del libro que tiene en la
/// mano y esa es la imagen. Es lo más fiel posible, y es la única forma de
/// que el lomo diga lo que dice el lomo de verdad.
///
/// **El color de su tapa.** Automático, sin que nadie haga nada.
///
/// # Por qué «automático» no puede ser la foto del lomo
///
/// Porque no existe de dónde sacarla. Se comprobó: Open Library solo
/// publica tapas de frente —`spine` y `back` contestan 404, y la ficha de
/// una edición solo declara `covers`— y Google Books solo da `thumbnail`,
/// que también es la tapa. **Nadie tiene fotos de lomos.**
///
/// Prometer «la app lo busca» y devolver siempre nada sería peor que no
/// ofrecerlo. Lo que sí se puede buscar solo es el **color** de la tapa, y
/// alcanza para bastante: una repisa donde cada lomo tiene el color de su
/// libro se parece muchísimo más a una biblioteca que una donde los colores
/// salen de un número inventado a partir del título.
///
/// # Por qué se guarda el color y no se calcula cada vez
///
/// Porque calcularlo pide bajar la imagen y recorrerla. Una vez por libro
/// está bien; en cada dibujo de la repisa, con veinte libros, sería bajar
/// veinte imágenes cada vez que se hace scroll.
class Lomos {
  static const _claveFotos = 'colibri.lomos.fotos.v1';
  static const _claveColores = 'colibri.lomos.colores.v1';

  /// La foto del lomo de cada libro, en base64.
  final Map<String, String> _fotos = {};

  /// El color sacado de la tapa. Guardado como número.
  ///
  /// Un libro que ya se miró y no dio color queda anotado igual, con null:
  /// si no, se volvería a bajar su tapa en cada arranque para volver a no
  /// encontrar nada. Una tapa en blanco y negro no tiene color que ganar.
  final Map<String, int?> _colores = {};

  /// Los que se están mirando ahora, para no pedir dos veces lo mismo
  /// cuando la repisa dibuja el mismo libro en dos lugares.
  final Set<String> _enCamino = {};

  /// Quién baja las tapas.
  ///
  /// Se puede reemplazar solo para probar. Sin esto no había forma de
  /// escribir la prueba que importa —«un fallo de red no deja el libro
  /// marcado para siempre»— porque `flutter test` no corta el HTTP: lo
  /// contesta con una imagen transparente de 1×1 y estado 200. La primera
  /// versión de esa prueba pasaba por el motivo equivocado y falló al
  /// escribirla, que es exactamente para lo que sirve escribirla.
  final http.Client _cliente;

  Lomos({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  String? fotoDe(String clave) => _fotos[clave];
  bool tieneFoto(String clave) => _fotos.containsKey(clave);

  /// El color de la tapa, si ya se calculó.
  int? colorDe(String clave) => _colores[clave];
  bool yaSeMiro(String clave) => _colores.containsKey(clave);

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _fotos.clear();
    _colores.clear();

    try {
      final f = prefs.getString(_claveFotos);
      if (f != null) {
        (jsonDecode(f) as Map<String, dynamic>).forEach((k, v) {
          if (v is String) _fotos[k] = v;
        });
      }

      final c = prefs.getString(_claveColores);
      if (c != null) {
        (jsonDecode(c) as Map<String, dynamic>).forEach((k, v) {
          _colores[k] = v is int ? v : null;
        });
      }
    } catch (_) {
      // Formato roto: se arranca sin nada, que es un estado válido. Los
      // colores se vuelven a calcular solos y las fotos se pueden sacar de
      // nuevo; no abrir la repisa sería peor.
    }
  }

  Future<void> guardarFoto(String clave, String base64) async {
    _fotos[clave] = base64;
    await _guardarFotos();
  }

  Future<void> quitarFoto(String clave) async {
    _fotos.remove(clave);
    await _guardarFotos();
  }

  Future<void> _guardarFotos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveFotos, jsonEncode(_fotos));
  }

  /// Mira la tapa de un libro y se queda con su color.
  ///
  /// Devuelve true si aprendió algo nuevo, para que la pantalla se redibuje
  /// solo cuando hay algo distinto que mostrar.
  ///
  /// No falla nunca hacia afuera: sin internet, con una tapa que no se pudo
  /// bajar o con una imagen rota, el lomo se queda con el color de siempre.
  Future<bool> mirarLaTapa(Libro libro) async {
    final clave = libro.clave;
    if (_colores.containsKey(clave) || _enCamino.contains(clave)) return false;

    final url = Api.tapaDe(libro, tamano: 'M');
    if (url == null) {
      _colores[clave] = null;
      return false;
    }

    _enCamino.add(clave);
    try {
      final r = await _cliente
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (r.statusCode != 200) {
        // Un 404 es una respuesta: esa tapa no existe y no va a aparecer
        // por preguntar de nuevo. Se anota para no volver a pedirla en
        // cada arranque. Un 500 o un 503 es el servidor teniendo un mal
        // día, y eso sí se reintenta.
        if (r.statusCode >= 400 && r.statusCode < 500) {
          _colores[clave] = null;
          _sinGuardar = true;
        }
        return false;
      }

      // En otro hilo: decodificar un JPEG en Dart puro lleva decenas de
      // milisegundos, y en el hilo de la pantalla eso es la repisa
      // trabándose mientras se desliza.
      _colores[clave] = await compute(FotoDeLomo.colorQueManda, r.bodyBytes);
      _sinGuardar = true;
      return _colores[clave] != null;
    } catch (_) {
      // Sin anotar nada: se vuelve a intentar la próxima vez. Anotar un
      // fallo de red como «este libro no tiene color» dejaría el lomo gris
      // para siempre por haber abierto la app en el subte.
      return false;
    } finally {
      _enCamino.remove(clave);
    }
  }

  /// Mira las tapas de un estante entero.
  ///
  /// Devuelve true si aprendió al menos un color, para redibujar una sola
  /// vez y no una por libro.
  ///
  /// # De a tres
  ///
  /// Un estante puede tener cincuenta libros y cada tapa es una bajada. De
  /// a cincuenta a la vez la red se tapa y las primeras pantallas de la app
  /// —que están pidiendo tapas para las grillas— quedan esperando detrás.
  /// De a uno tarda cincuenta veces lo que tarda una. Tres es el punto
  /// donde deja de notarse sin llevarse la conexión puesta.
  ///
  /// Los que ya se miraron no cuentan: `mirarLaTapa` corta al toque, así
  /// que la segunda vez que se abre el estante esto no hace ni un pedido.
  Future<bool> mirarLasTapas(List<Libro> libros) async {
    final faltan = libros.where((l) => !yaSeMiro(l.clave)).toList();
    if (faltan.isEmpty) return false;

    var aprendio = false;
    try {
      for (var i = 0; i < faltan.length; i += 3) {
        final tanda = faltan.sublist(i, (i + 3).clamp(0, faltan.length));
        final r = await Future.wait(tanda.map(mirarLaTapa));
        if (r.contains(true)) aprendio = true;
      }
    } finally {
      // Una escritura por estante y no una por libro: cada una reescribe
      // todos los colores, y con quinientos libros eran quinientas
      // escrituras cada vez más largas.
      await guardarColores();
    }
    return aprendio;
  }

  /// Si [mirarLaTapa] aprendió algo, lo deja en el disco.
  ///
  /// [mirarLaTapa] no guarda sola para que un estante entero se guarde de
  /// una vez; quien la llame suelta tiene que llamar a esto después.
  Future<void> guardarColores() async {
    if (!_sinGuardar) return;
    _sinGuardar = false;
    await _guardarColores();
  }

  bool _sinGuardar = false;

  Future<void> _guardarColores() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveColores, jsonEncode(_colores));
  }
}

final lomos = Lomos();
