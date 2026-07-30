import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dónde está un libro en tu lectura. Es uno solo y siempre hay uno.
enum Estado { leyendo, leido, pendiente }

extension NombreEstado on Estado {
  String get nombre => switch (this) {
        Estado.leyendo => 'Leyendo',
        Estado.leido => 'Leídos',
        Estado.pendiente => 'Pendientes',
      };
}

/// Una frase que alguien subrayó.
///
/// Es lo único de un libro digital que sale del teléfono: el fragmento
/// que la lectora eligió, no el archivo. Es exactamente lo mismo que si
/// lo hubiera tipeado a mano mirando el libro de papel.
class Frase {
  /// Cuánto texto se puede guardar de una vez.
  ///
  /// No es un capricho técnico: **es la protección legal del proyecto.**
  /// Con un tope, nadie puede reconstruir un libro guardando frase por
  /// frase, y la app queda del lado de citar y no del de repartir.
  static const topeDeCaracteres = 800;

  final String texto;
  final DateTime guardada;

  /// En qué parte del libro estaba, de 0 a 1. Sirve para decir
  /// "cerca del final" sin depender de números de página, que cambian
  /// con cada edición.
  final double? posicion;

  Frase({required String texto, DateTime? guardada, this.posicion})
      : texto = _recortar(texto),
        guardada = guardada ?? DateTime.now();

  static String _recortar(String t) {
    final limpio = t.trim();
    if (limpio.length <= topeDeCaracteres) return limpio;
    return '${limpio.substring(0, topeDeCaracteres).trimRight()}…';
  }

  Map<String, dynamic> aJson() => {
        'texto': texto,
        'guardada': guardada.toIso8601String(),
        'posicion': posicion,
      };

  factory Frase.desdeJson(Map<String, dynamic> j) => Frase(
        texto: j['texto'] as String,
        guardada: DateTime.tryParse((j['guardada'] as String?) ?? ''),
        posicion: (j['posicion'] as num?)?.toDouble(),
      );
}

class Libro {
  final String id;
  final String titulo;
  final String autor;
  final int? tapaId;
  final String? editorial;
  final int? anio;

  Estado estado;
  int puntaje; // 0 = sin puntuar
  int paginaActual;
  int? paginas;

  /// Cuándo lo empezaste y cuándo lo terminaste. Guardamos solo la fecha,
  /// sin hora: a nadie le importa haber terminado un libro a las 23:47.
  DateTime? empezado;
  DateTime? terminado;

  /// Tu reseña. La marca de spoilers la ponés vos al escribirla, y si está
  /// puesta el texto se muestra tapado hasta que alguien decida verlo.
  String? resena;
  bool resenaConSpoilers;

  /// Tu personaje favorito. Hoy es un dato tuyo; el día que haya
  /// comunidad se convierte en una coincidencia más.
  String? personaje;

  /// Las frases que subrayaste de este libro.
  final List<Frase> frases;

  /// Estantes propios: los nombres que inventa cada persona.
  ///
  /// A diferencia del estado, un libro puede estar en varios a la vez:
  /// "los que me rompieron" no compite con "leído".
  final Set<String> estantes;

  Libro({
    required this.id,
    required this.titulo,
    required this.autor,
    this.tapaId,
    this.editorial,
    this.anio,
    this.estado = Estado.pendiente,
    this.puntaje = 0,
    this.paginaActual = 0,
    this.paginas,
    this.empezado,
    this.terminado,
    this.resena,
    this.resenaConSpoilers = false,
    this.personaje,
    Set<String>? estantes,
    List<Frase>? frases,
  })  : estantes = estantes ?? <String>{},
        frases = frases ?? <Frase>[];

  bool get tieneResena => (resena ?? '').trim().isNotEmpty;

  /// Cuántos días te llevó. Contamos el primero y el último, así que
  /// empezar y terminar el mismo día da 1 y no 0.
  int? get diasDeLectura {
    if (empezado == null || terminado == null) return null;
    final d = terminado!.difference(empezado!).inDays + 1;
    return d < 1 ? 1 : d;
  }

  /// Clave para detectar que dos personas tienen el mismo libro,
  /// aunque lo hayan cargado desde ediciones distintas.
  String get clave => '${_normalizar(titulo)}|${_claveAutor(autor)}';

  /// El nombre del autor viene en cualquier orden: Open Library suele
  /// devolver "Juan Rulfo" y a mano se escribe "Rulfo, Juan". Ordenamos
  /// las palabras alfabéticamente para que las dos formas den lo mismo.
  ///
  /// Lo que todavía no resuelve: las iniciales. "G. Cabezón Cámara" y
  /// "Gabriela Cabezón Cámara" siguen siendo dos claves distintas.
  static String _claveAutor(String autor) {
    final palabras = _normalizar(autor).split(' ')
      ..removeWhere((p) => p.isEmpty)
      ..sort();
    return palabras.join(' ');
  }

  static String _normalizar(String s) {
    const acentos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
      'ü': 'u', 'ñ': 'n', 'Á': 'a', 'É': 'e', 'Í': 'i',
      'Ó': 'o', 'Ú': 'u', 'Ñ': 'n',
    };
    var r = s.toLowerCase().trim();
    acentos.forEach((k, v) => r = r.replaceAll(k, v));
    return r.replaceAll(RegExp(r'[^a-z0-9 ]'), '').replaceAll(RegExp(r'\s+'), ' ');
  }

  factory Libro.desdeOpenLibrary(Map<String, dynamic> d) {
    final autores = (d['author_name'] as List?)?.cast<String>() ?? const [];
    final editoriales = (d['publisher'] as List?)?.cast<String>() ?? const [];
    return Libro(
      id: (d['key'] as String?) ?? '${d['title']}-${d['cover_i']}',
      titulo: (d['title'] as String?) ?? 'Sin título',
      autor: autores.isEmpty ? 'Autor desconocido' : autores.first,
      tapaId: d['cover_i'] as int?,
      editorial: editoriales.isEmpty ? null : editoriales.first,
      anio: d['first_publish_year'] as int?,
      paginas: d['number_of_pages_median'] as int?,
    );
  }

  Map<String, dynamic> aJson() => {
        'id': id,
        'titulo': titulo,
        'autor': autor,
        'tapaId': tapaId,
        'editorial': editorial,
        'anio': anio,
        'estado': estado.index,
        'puntaje': puntaje,
        'paginaActual': paginaActual,
        'paginas': paginas,
        'estantes': estantes.toList(),
        'empezado': empezado?.toIso8601String(),
        'terminado': terminado?.toIso8601String(),
        'resena': resena,
        'resenaConSpoilers': resenaConSpoilers,
        'personaje': personaje,
        'frases': frases.map((f) => f.aJson()).toList(),
      };

  static DateTime? _fecha(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  factory Libro.desdeJson(Map<String, dynamic> j) => Libro(
        id: j['id'] as String,
        titulo: j['titulo'] as String,
        autor: j['autor'] as String,
        tapaId: j['tapaId'] as int?,
        editorial: j['editorial'] as String?,
        anio: j['anio'] as int?,
        // 'estante' es el nombre viejo: lo leemos para no perder datos
        // de quien ya venía usando la demo.
        estado: Estado.values[(j['estado'] ?? j['estante'] ?? 2) as int],
        puntaje: (j['puntaje'] as int?) ?? 0,
        paginaActual: (j['paginaActual'] as int?) ?? 0,
        paginas: j['paginas'] as int?,
        estantes: ((j['estantes'] as List?) ?? const [])
            .map((e) => e as String)
            .toSet(),
        empezado: _fecha(j['empezado']),
        terminado: _fecha(j['terminado']),
        resena: j['resena'] as String?,
        resenaConSpoilers: (j['resenaConSpoilers'] as bool?) ?? false,
        personaje: j['personaje'] as String?,
        frases: ((j['frases'] as List?) ?? const [])
            .map((f) => Frase.desdeJson(f as Map<String, dynamic>))
            .toList(),
      );
}

/// La biblioteca de quien usa la app. Se guarda en el teléfono.
class Biblioteca extends ChangeNotifier {
  static const _claveLibros = 'colibri.biblioteca.v1';
  static const _claveEstantes = 'colibri.estantes.v1';
  static const _claveConTexto = 'colibri.conTexto.v1';

  final List<Libro> _libros = [];

  /// Los nombres de estantes, en el orden en que se crearon.
  /// Viven acá y no solo dentro de los libros para que un estante
  /// recién creado, todavía vacío, no desaparezca.
  final List<String> _estantes = [];

  List<Libro> get todos => List.unmodifiable(_libros);
  List<String> get estantes => List.unmodifiable(_estantes);

  List<Libro> enEstado(Estado e) =>
      _libros.where((l) => l.estado == e).toList();

  List<Libro> enEstante(String nombre) =>
      _libros.where((l) => l.estantes.contains(nombre)).toList();

  Libro? get leyendoAhora {
    final l = enEstado(Estado.leyendo);
    return l.isEmpty ? null : l.first;
  }

  bool tiene(Libro libro) => _libros.any((l) => l.clave == libro.clave);

  Libro? buscarPorClave(String clave) {
    for (final l in _libros) {
      if (l.clave == clave) return l;
    }
    return null;
  }

  Future<void> agregar(Libro libro) async {
    if (tiene(libro)) return;
    _libros.insert(0, libro);
    await _guardar();
  }

  Future<void> quitar(Libro libro) async {
    _libros.removeWhere((l) => l.clave == libro.clave);
    await _guardar();
  }

  /// Para cuando se cambia algo de un libro que ya está guardado.
  Future<void> actualizar() => _guardar();

  /// Cambia el estado y, de paso, anota las fechas si estaban vacías.
  ///
  /// Es el tipo de ayuda que se agradece sin notarla: si marcaste
  /// "leyendo" hoy, empezaste hoy. Nunca pisa una fecha ya puesta, y
  /// siempre se puede corregir a mano.
  ///
  /// El parámetro [hoy] existe para que los tests no dependan del
  /// día en que se corran.
  Future<void> cambiarEstado(Libro libro, Estado nuevo, {DateTime? hoy}) async {
    libro.estado = nuevo;

    final h = hoy ?? DateTime.now();
    final fecha = DateTime(h.year, h.month, h.day);

    if (nuevo == Estado.leyendo) {
      libro.empezado ??= fecha;
    } else if (nuevo == Estado.leido) {
      libro.empezado ??= fecha;
      libro.terminado ??= fecha;
    }

    await _guardar();
  }

  // ---------- Estantes propios ----------

  /// Devuelve el nombre creado, o null si estaba repetido o vacío.
  Future<String?> crearEstante(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return null;
    final yaEsta = _estantes.any(
      (e) => e.toLowerCase() == limpio.toLowerCase(),
    );
    if (yaEsta) return null;
    _estantes.add(limpio);
    await _guardar();
    return limpio;
  }

  Future<void> borrarEstante(String nombre) async {
    _estantes.remove(nombre);
    for (final l in _libros) {
      l.estantes.remove(nombre);
    }
    await _guardar();
  }

  Future<void> renombrarEstante(String viejo, String nuevo) async {
    final limpio = nuevo.trim();
    if (limpio.isEmpty || limpio == viejo) return;
    final i = _estantes.indexOf(viejo);
    if (i == -1) return;
    _estantes[i] = limpio;
    for (final l in _libros) {
      if (l.estantes.remove(viejo)) l.estantes.add(limpio);
    }
    await _guardar();
  }

  Future<void> alternarEstante(Libro libro, String nombre) async {
    if (!libro.estantes.remove(nombre)) libro.estantes.add(nombre);
    await _guardar();
  }

  // ---------- Texto de los libros digitales ----------
  //
  // Guardamos el TEXTO extraído, nunca el archivo. El .epub se abre una
  // vez y se descarta: en la app no queda ningún archivo que se pueda
  // compartir, mandar ni descargar.
  //
  // El texto vive en el teléfono y no sale de ahí. Lo único que puede
  // volverse público es la frase que la lectora eligió a mano.

  final Set<String> _conTexto = {};

  bool tieneTexto(Libro l) => _conTexto.contains(l.clave);

  static String _claveTexto(Libro l) => 'colibri.texto.${l.clave}';

  /// Guarda el texto comprimido.
  ///
  /// La compresión no es una optimización: es lo que hace que la función
  /// exista. En la web el guardado del navegador tiene un tope de unos
  /// 5 MB por sitio, y una novela entera lo pasa fácil, así que guardarla
  /// tal cual lanzaba un error y la importación fallaba entera.
  ///
  /// Comprimida ocupa alrededor de un tercio. Además va como un solo
  /// texto y no como lista, que se guarda mucho más chico.
  ///
  /// Devuelve false si no entró. En ese caso la app sigue andando con el
  /// libro en memoria hasta que se cierre.
  Future<bool> guardarTexto(Libro libro, List<String> parrafos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = utf8.encode(parrafos.join('\u0000'));
      final comprimido = base64Encode(GZipEncoder().encode(crudo));
      await prefs.setString(_claveTexto(libro), comprimido);
      _conTexto.add(libro.clave);
      await _guardar();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>?> textoDe(Libro libro) async {
    if (!tieneTexto(libro)) return null;
    final prefs = await SharedPreferences.getInstance();

    // Preguntamos por el valor sin decirle de qué tipo es.
    //
    // `getString` no devuelve null cuando lo guardado es una lista: lanza
    // un error de tipo. Y lo guardado ES una lista para quien importó un
    // libro con la versión anterior, así que pedirlo con tipo hacía que
    // esos libros rompieran la pantalla en lugar de migrar.
    final guardado = prefs.get(_claveTexto(libro));

    if (guardado is String) {
      try {
        final crudo = GZipDecoder().decodeBytes(base64Decode(guardado));
        return utf8.decode(crudo).split('\u0000');
      } catch (_) {
        return null;
      }
    }

    // Formato viejo, sin comprimir: lo leemos igual para no perderle el
    // libro a quien ya lo había sumado.
    if (guardado is List) return guardado.cast<String>();

    return null;
  }

  /// Borra el texto pero deja las frases: son tuyas, las elegiste vos.
  Future<void> borrarTexto(Libro libro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveTexto(libro));
    _conTexto.remove(libro.clave);
    await _guardar();
  }

  // ---------- Guardado ----------

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();

    _conTexto
      ..clear()
      ..addAll(prefs.getStringList(_claveConTexto) ?? const []);

    final crudoLibros = prefs.getString(_claveLibros);
    if (crudoLibros != null) {
      try {
        final lista = jsonDecode(crudoLibros) as List;
        _libros
          ..clear()
          ..addAll(lista.map((j) => Libro.desdeJson(j as Map<String, dynamic>)));
      } catch (_) {
        // Si el formato guardado quedó viejo, arrancamos limpio en vez de romper.
      }
    }

    final crudoEstantes = prefs.getStringList(_claveEstantes);
    if (crudoEstantes != null) {
      _estantes
        ..clear()
        ..addAll(crudoEstantes);
    }

    // Por las dudas: si un libro quedó con un estante que ya no está en
    // la lista, lo recuperamos en vez de perderlo en silencio.
    for (final l in _libros) {
      for (final e in l.estantes) {
        if (!_estantes.contains(e)) _estantes.add(e);
      }
    }

    notifyListeners();
  }

  Future<void> _guardar() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _claveLibros,
      jsonEncode(_libros.map((l) => l.aJson()).toList()),
    );
    await prefs.setStringList(_claveEstantes, _estantes);
    await prefs.setStringList(_claveConTexto, _conTexto.toList());
  }
}

/// Una sola instancia para toda la app. Alcanza para una demo.
final biblioteca = Biblioteca();

/// "12 mar 2026". Sin paquetes de fechas: para tres usos alcanza y sobra,
/// y evita arrastrar una dependencia entera por doce palabras.
String fechaCorta(DateTime d) {
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  return '${d.day} ${meses[d.month - 1]} ${d.year}';
}
