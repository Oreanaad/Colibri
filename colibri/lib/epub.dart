import 'dart:convert';
import 'package:archive/archive.dart';

/// Le saca el texto a un EPUB para poder buscar frases adentro.
///
/// # La regla que sostiene todo esto
///
/// **El archivo no se guarda nunca.** Se abre una vez, se le extrae el
/// texto, y el `.epub` se descarta ahí mismo. En la app no queda ningún
/// archivo que se pueda compartir, mandar ni descargar: no hay nada que
/// bajar, y por lo tanto no hay nada que reclamar.
///
/// Lo único que después puede volverse público es **la frase que la
/// lectora eligió**, que es exactamente lo mismo que si la hubiera
/// tipeado a mano mirando el libro de papel. La app solo le ahorra el
/// trabajo de tipearla.
///
/// # Por qué EPUB y no PDF
///
/// Un EPUB es un ZIP con archivos de texto adentro: se abre, se lee y
/// listo. Un PDF guarda posiciones de letras en una página, no párrafos,
/// y sacarle texto legible es un problema en serio —columnas, ligaduras,
/// guiones de corte— y encima los escaneados no tienen texto ninguno.
/// EPUB primero; PDF cuando el resto funcione.
class Epub {
  /// Los párrafos del libro, en orden y ya limpios de etiquetas.
  final List<String> parrafos;

  /// Metadatos del propio archivo, para avisar si no coincide con el
  /// libro al que se lo está sumando.
  final String? titulo;
  final String? autor;

  const Epub({required this.parrafos, this.titulo, this.autor});

  int get cantidadDePalabras =>
      parrafos.fold(0, (n, p) => n + p.split(' ').length);

  /// Abre los bytes de un EPUB y devuelve su texto.
  ///
  /// Devuelve null si el archivo no es un EPUB válido o si no tiene
  /// texto adentro (por ejemplo, si son imágenes escaneadas).
  static Epub? abrir(List<int> bytes) {
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return null; // no era un ZIP, así que no era un EPUB
    }

    final orden = _ordenDeLectura(zip);
    final parrafos = <String>[];

    for (final nombre in orden) {
      final archivo = _buscar(zip, nombre);
      if (archivo == null) continue;

      final crudo = _texto(archivo);
      if (crudo == null) continue;
      parrafos.addAll(_aParrafos(crudo));
    }

    if (parrafos.isEmpty) return null;

    final (titulo, autor) = _metadatos(zip);
    return Epub(parrafos: parrafos, titulo: titulo, autor: autor);
  }

  /// Busca un texto y devuelve los párrafos que lo contienen.
  ///
  /// Compara sin acentos ni mayúsculas, así que "corazon" encuentra
  /// "corazón": nadie se acuerda de una frase con la puntuación exacta.
  List<Coincidencia> buscar(String texto, {int maximo = 12}) {
    final aguja = normalizar(texto);
    if (aguja.length < 4) return const [];

    final encontrados = <Coincidencia>[];
    for (var i = 0; i < parrafos.length; i++) {
      final donde = normalizar(parrafos[i]).indexOf(aguja);
      if (donde == -1) continue;
      encontrados.add(Coincidencia(parrafo: parrafos[i], indice: i));
      if (encontrados.length >= maximo) break;
    }
    return encontrados;
  }

  // ---------- Adentro ----------

  static ArchiveFile? _buscar(Archive zip, String nombre) {
    for (final f in zip.files) {
      if (f.name == nombre) return f;
    }
    return null;
  }

  /// El orden de lectura sale del "spine" del EPUB, que es el índice de
  /// verdad. Si el archivo está mal armado, caemos a ordenar por nombre,
  /// que acierta casi siempre porque suelen numerarse.
  static List<String> _ordenDeLectura(Archive zip) {
    try {
      final contenedor = _buscar(zip, 'META-INF/container.xml');
      final rutaOpf = RegExp(
        r'full-path="([^"]+)"',
      ).firstMatch(_texto(contenedor!)!)?.group(1);
      if (rutaOpf == null) throw Exception();

      final xml = _texto(_buscar(zip, rutaOpf)!)!;
      final base = rutaOpf.contains('/')
          ? '${rutaOpf.substring(0, rutaOpf.lastIndexOf('/'))}/'
          : '';

      // id -> href, según el manifest
      final manifiesto = <String, String>{};
      for (final m in RegExp(r'<item\b[^>]*>').allMatches(xml)) {
        final etiqueta = m.group(0)!;
        final id = RegExp(r'id="([^"]+)"').firstMatch(etiqueta)?.group(1);
        final href = RegExp(r'href="([^"]+)"').firstMatch(etiqueta)?.group(1);
        if (id != null && href != null) manifiesto[id] = '$base$href';
      }

      // el orden lo manda el spine
      final orden = <String>[];
      for (final m in RegExp(r'idref="([^"]+)"').allMatches(xml)) {
        final ruta = manifiesto[m.group(1)];
        if (ruta != null) orden.add(ruta);
      }
      if (orden.isNotEmpty) return orden;
    } catch (_) {
      // seguimos con el plan B
    }

    final sueltos =
        zip.files
            .map((f) => f.name)
            .where(
              (n) =>
                  n.endsWith('.xhtml') ||
                  n.endsWith('.html') ||
                  n.endsWith('.htm'),
            )
            .toList()
          ..sort();
    return sueltos;
  }

  static String? _texto(ArchiveFile a) {
    try {
      return utf8.decode(a.content as List<int>, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static (String?, String?) _metadatos(Archive zip) {
    for (final f in zip.files) {
      if (!f.name.endsWith('.opf')) continue;
      final xml = _texto(f);
      if (xml == null) continue;
      String? sacar(String etiqueta) => RegExp(
        '<dc:$etiqueta[^>]*>(.*?)</dc:$etiqueta>',
        dotAll: true,
      ).firstMatch(xml)?.group(1)?.trim();
      return (sacar('title'), sacar('creator'));
    }
    return (null, null);
  }

  /// De HTML a párrafos de texto limpio.
  static List<String> _aParrafos(String html) {
    var t = html;

    // Lo que no es texto para leer se va entero, con contenido y todo.
    t = t.replaceAll(
      RegExp(
        r'<(script|style|head)[^>]*>.*?</\1>',
        dotAll: true,
        caseSensitive: false,
      ),
      ' ',
    );

    // Los cortes de párrafo se marcan antes de borrar las etiquetas,
    // porque si no el libro entero queda como un solo bloque.
    t = t.replaceAll(
      RegExp(r'</(p|div|h[1-6]|li|blockquote|br)\s*/?>', caseSensitive: false),
      '\n\n',
    );

    t = t.replaceAll(RegExp(r'<[^>]+>'), ' '); // el resto de las etiquetas

    // Las entidades más comunes de un libro.
    const entidades = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&apos;': "'",
      '&mdash;': '—',
      '&ndash;': '–',
      '&hellip;': '…',
      '&laquo;': '«',
      '&raquo;': '»',
      '&ldquo;': '“',
      '&rdquo;': '”',
      '&lsquo;': '‘',
      '&rsquo;': '’',
    };
    entidades.forEach((k, v) => t = t.replaceAll(k, v));
    t = t.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    );

    return t
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
        // Menos de 40 caracteres suele ser un título, un número de página
        // o una nota al pie: nadie subraya eso.
        .where((p) => p.length >= 40)
        .toList();
  }

  /// Sin acentos, sin mayúsculas y sin comillas raras: así "corazon"
  /// encuentra "corazón" y «hola» encuentra "hola".
  static String normalizar(String s) {
    const reemplazos = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
      'à': 'a',
      'è': 'e',
      'ì': 'i',
      'ò': 'o',
      'ù': 'u',
      '“': '"',
      '”': '"',
      '‘': "'",
      '’': "'",
      '«': '"',
      '»': '"',
      '—': '-',
      '–': '-',
      '…': '...',
    };
    var r = s.toLowerCase();
    reemplazos.forEach((k, v) => r = r.replaceAll(k, v));
    return r.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class Coincidencia {
  final String parrafo;
  final int indice;
  const Coincidencia({required this.parrafo, required this.indice});

  /// Aproximación de en qué parte del libro está, para mostrar
  /// "cerca del final" sin necesidad de números de página.
  double porcentaje(int totalDeParrafos) =>
      totalDeParrafos == 0 ? 0 : indice / totalDeParrafos;
}
