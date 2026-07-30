import 'dart:convert';
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
    Set<String>? estantes,
  }) : estantes = estantes ?? <String>{};

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
      };

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
      );
}

/// La biblioteca de quien usa la app. Se guarda en el teléfono.
class Biblioteca extends ChangeNotifier {
  static const _claveLibros = 'colibri.biblioteca.v1';
  static const _claveEstantes = 'colibri.estantes.v1';

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

  // ---------- Guardado ----------

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();

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
  }
}

/// Una sola instancia para toda la app. Alcanza para una demo.
final biblioteca = Biblioteca();
