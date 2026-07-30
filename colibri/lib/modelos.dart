import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Estante { leyendo, leido, pendiente }

extension NombreEstante on Estante {
  String get nombre => switch (this) {
        Estante.leyendo => 'Leyendo',
        Estante.leido => 'Leídos',
        Estante.pendiente => 'Pendientes',
      };
}

class Libro {
  final String id;
  final String titulo;
  final String autor;
  final int? tapaId;
  final String? editorial;
  final int? anio;

  Estante estante;
  int puntaje; // 0 = sin puntuar
  int paginaActual;
  int? paginas;

  Libro({
    required this.id,
    required this.titulo,
    required this.autor,
    this.tapaId,
    this.editorial,
    this.anio,
    this.estante = Estante.pendiente,
    this.puntaje = 0,
    this.paginaActual = 0,
    this.paginas,
  });

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
        'estante': estante.index,
        'puntaje': puntaje,
        'paginaActual': paginaActual,
        'paginas': paginas,
      };

  factory Libro.desdeJson(Map<String, dynamic> j) => Libro(
        id: j['id'] as String,
        titulo: j['titulo'] as String,
        autor: j['autor'] as String,
        tapaId: j['tapaId'] as int?,
        editorial: j['editorial'] as String?,
        anio: j['anio'] as int?,
        estante: Estante.values[(j['estante'] as int?) ?? 2],
        puntaje: (j['puntaje'] as int?) ?? 0,
        paginaActual: (j['paginaActual'] as int?) ?? 0,
        paginas: j['paginas'] as int?,
      );
}

/// La biblioteca de quien usa la app. Se guarda en el teléfono.
class Biblioteca extends ChangeNotifier {
  static const _clave = 'colibri.biblioteca.v1';
  final List<Libro> _libros = [];

  List<Libro> get todos => List.unmodifiable(_libros);

  List<Libro> enEstante(Estante e) =>
      _libros.where((l) => l.estante == e).toList();

  Libro? get leyendoAhora {
    final l = enEstante(Estante.leyendo);
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
    notifyListeners();
    await guardar();
  }

  Future<void> quitar(Libro libro) async {
    _libros.removeWhere((l) => l.clave == libro.clave);
    notifyListeners();
    await guardar();
  }

  Future<void> actualizar() async {
    notifyListeners();
    await guardar();
  }

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null) return;
    try {
      final lista = jsonDecode(crudo) as List;
      _libros
        ..clear()
        ..addAll(lista.map((j) => Libro.desdeJson(j as Map<String, dynamic>)));
      notifyListeners();
    } catch (_) {
      // Si el formato guardado quedó viejo, arrancamos limpio en vez de romper.
    }
  }

  Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode(_libros.map((l) => l.aJson()).toList()),
    );
  }
}

/// Una sola instancia para toda la app. Alcanza para una demo.
final biblioteca = Biblioteca();
