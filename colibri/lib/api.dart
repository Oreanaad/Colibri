import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';

/// Open Library: abierta, gratis y sin clave.
/// Es floja en ediciones latinoamericanas, y esta demo sirve justamente
/// para medir cuánto le falta con los libros que lee tu comunidad.
class Api {
  static const _campos =
      'key,title,author_name,cover_i,first_publish_year,publisher,number_of_pages_median';

  static Future<List<Libro>> buscar(String consulta) async {
    if (consulta.trim().length < 3) return [];

    final uri = Uri.https('openlibrary.org', '/search.json', {
      'q': consulta.trim(),
      'limit': '20',
      'fields': _campos,
    });

    final respuesta = await http
        .get(uri, headers: {'User-Agent': 'Colibri/0.1 (demo)'})
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
