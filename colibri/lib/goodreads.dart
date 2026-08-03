import 'package:csv/csv.dart';

import 'isbn.dart';
import 'modelos.dart';

/// Traer tu biblioteca de Goodreads.
///
/// # Qué se rescata
///
/// Casi todo, porque Goodreads guarda justo lo mismo que guardamos acá:
/// el estante donde está el libro, el puntaje, las fechas, tus estantes
/// inventados, la reseña y hasta si avisaste que tiene spoilers. Nada de
/// eso hay que volver a cargarlo a mano.
///
/// # Cómo se saca el archivo
///
/// En Goodreads: *My Books → Import and Export → Export Library*. Tarda un
/// rato en generarse y llega un correo con un `.csv`.
///
/// # Por qué se buscan las columnas por nombre y no por posición
///
/// Goodreads cambió las columnas de lugar más de una vez y agregó otras
/// nuevas. Un lector que cuente «la novena columna es el puntaje» se rompe
/// el día que agreguen una décima, y se rompe **en silencio**: importaría
/// todo con datos corridos. Buscando por nombre, una columna nueva es una
/// columna que ignoramos.
///
/// # Nada de internet
///
/// Esto no pide una sola cosa a ningún servidor. Doscientos libros entran
/// al instante y funciona en el subte. Las tapas son otro problema y se
/// resuelven después: es mejor ver tu biblioteca entera sin tapas que
/// esperar dos minutos mirando una rueda girar.
class Goodreads {
  /// Lo que Goodreads llama «estante exclusivo»: dónde está el libro.
  /// Son las mismas tres que tenemos, con otros nombres.
  static const _estados = {
    'read': Estado.leido,
    'currently-reading': Estado.leyendo,
    'to-read': Estado.pendiente,
  };

  static Importacion leer(String contenido) {
    // `dynamicTyping` apagado a propósito: sin esto, un ISBN se
    // convertiría en número y perdería los ceros de adelante, que es
    // exactamente lo que Goodreads intenta evitar envolviéndolos en una
    // fórmula de planilla.
    final filas = Csv(dynamicTyping: false).decode(contenido);

    if (filas.isEmpty) {
      return const Importacion(libros: [], filas: 0, sinTitulo: 0);
    }

    // El encabezado, normalizado, para poder pedir columnas por nombre.
    final columnas = <String, int>{};
    for (final (i, celda) in filas.first.indexed) {
      columnas[_normalizar('$celda')] = i;
    }

    if (!columnas.containsKey('title')) {
      return Importacion(
        libros: const [],
        filas: filas.length - 1,
        sinTitulo: filas.length - 1,
        noEsDeGoodreads: true,
      );
    }

    final libros = <Libro>[];
    var sinTitulo = 0;

    for (final fila in filas.skip(1)) {
      String campo(String nombre) {
        final i = columnas[nombre];
        if (i == null || i >= fila.length) return '';
        return '${fila[i]}'.trim();
      }

      final titulo = campo('title');
      if (titulo.isEmpty) {
        sinTitulo++;
        continue;
      }

      final isbn = _isbn(campo('isbn13'), campo('isbn'));
      final estado = _estados[campo('exclusive shelf')] ?? Estado.pendiente;
      final terminado = _fecha(campo('date read'));

      libros.add(
        Libro(
          // Con prefijo, como los de Google: así nunca se confunde con una
          // obra de Open Library ni con un libro cargado a mano.
          id: 'goodreads:${campo('book id')}-$titulo',
          titulo: _limpiarTitulo(titulo),
          autor: campo('author').isEmpty
              ? 'Autor desconocido'
              : campo('author'),
          editorial: _oNada(campo('publisher')),
          anio:
              _entero(campo('original publication year')) ??
              _entero(campo('year published')),
          paginas: _entero(campo('number of pages')),
          estado: estado,
          puntaje: (_entero(campo('my rating')) ?? 0).clamp(0, 5),
          // Solo si Goodreads la tiene. Poner la fecha de hoy sería
          // inventar que terminaste doscientos libros esta tarde.
          terminado: estado == Estado.leido ? terminado : null,
          resena: _oNada(_limpiarResena(campo('my review'))),
          resenaConSpoilers: campo('spoiler').isNotEmpty,
          estantes: _estantes(campo('bookshelves')),
          // Aunque el ISBN venga, el libro entra como propio: los datos
          // son los que trajiste vos, no los de un catálogo.
          origen: Origen.propio,
          isbn: isbn,
        ),
      );
    }

    return Importacion(
      libros: libros,
      filas: filas.length - 1,
      sinTitulo: sinTitulo,
    );
  }

  /// Los ISBN vienen envueltos en una fórmula de planilla: `="9780439023481"`.
  /// Goodreads lo hace para que Excel no los convierta en números y les
  /// coma los ceros de adelante. Adentro puede no haber nada.
  static String? _isbn(String trece, String diez) {
    for (final crudo in [trece, diez]) {
      final limpio = Isbn.limpiar(crudo.replaceAll(RegExp(r'^="|"$'), ''));
      if (Isbn.valido(limpio)) return Isbn.aTrece(limpio);
    }
    return null;
  }

  /// Goodreads mete la colección en el título: «Cometierra (Trilogía, #1)».
  /// Se saca porque ensucia la ficha y rompe las coincidencias con la
  /// misma obra cargada desde otro lado.
  static String _limpiarTitulo(String titulo) =>
      titulo.replaceAll(RegExp(r'\s*\([^)]*#\d+[^)]*\)\s*$'), '').trim();

  /// Las reseñas viejas de Goodreads traen HTML de cuando su editor era
  /// una caja de texto con etiquetas.
  static String _limpiarResena(String texto) => texto
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .trim();

  /// Tus estantes inventados, separados por coma. Se saltean los tres que
  /// Goodreads usa para el estado, porque acá eso ya es el estado y
  /// tendrías un estante «to-read» al lado de la solapa Pendientes.
  static Set<String> _estantes(String crudo) => crudo
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && !_estados.containsKey(e))
      .toSet();

  /// Goodreads escribe «2019/03/15», y a veces no escribe nada.
  static DateTime? _fecha(String crudo) {
    final m = RegExp(r'(\d{4})/(\d{1,2})/(\d{1,2})').firstMatch(crudo);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  static int? _entero(String crudo) => int.tryParse(crudo.trim());

  static String? _oNada(String s) => s.isEmpty ? null : s;

  static String _normalizar(String s) => s.trim().toLowerCase();
}

/// Lo que salió de leer el archivo.
///
/// Además de los libros trae la cuenta de lo que había, para poder decir
/// «de tus 214 líneas entraron 211 y 3 no tenían título» en vez de un
/// «listo» que no deja verificar nada.
class Importacion {
  final List<Libro> libros;

  /// Cuántas filas tenía el archivo, sin contar el encabezado.
  final int filas;

  final int sinTitulo;

  /// El archivo se pudo leer como planilla pero no es de Goodreads.
  final bool noEsDeGoodreads;

  const Importacion({
    required this.libros,
    required this.filas,
    required this.sinTitulo,
    this.noEsDeGoodreads = false,
  });

  int get conIsbn => libros.where((l) => l.isbn != null).length;

  bool get vacia => libros.isEmpty;
}
