/// Qué hace que un fanfic sea *ese* fanfic y no otro.
///
/// # El problema
///
/// Los fanfics los carga la gente, no un catálogo. Y en cuanto haya
/// comunidad, el mismo fanfic va a entrar cargado por cuatro mil personas
/// distintas: una escribe «Todo lo que somos», otra «todo lo q somos»,
/// otra le pone el nombre del ship adelante y otra el del fandom. Con eso,
/// un mismo fic serían cuatro mil fichas y la biblioteca compartida no
/// serviría para nada.
///
/// Para los libros ese problema es difícil y lo resolvimos a medias,
/// comparando título y apellido. Para los fanfics es fácil, porque tienen
/// algo que los libros no: **una dirección propia**, que nadie escribe a
/// mano y que no se puede tipear distinto.
///
/// # Por qué el enlace es la identidad
///
/// `archiveofourown.org/works/1234567` es un número que puso el sitio. Dos
/// personas que carguen ese fic van a pegar enlaces que *se ven* distintos
/// —una con el capítulo, otra con parámetros pegados, otra sin `www`— pero
/// abajo de todo hay un solo número.
///
/// Esto no es una teoría: se lo preguntamos a AO3. Pedirle
/// `/works/1234567/chapters/2345678` contesta **302 hacia
/// `/works/1234567`**. El sitio mismo dice cuál es la forma buena, y es la
/// que usamos.
///
/// # Qué garantiza
///
/// Dos personas no pueden cargar el mismo fanfic dos veces sin que la app
/// lo sepa, **sin pedirle nada a internet y sin comparar títulos**. Y el
/// día que haya servidor, esa identidad ya está calculada del lado de
/// cada teléfono.
library;

enum Sitio {
  ao3('Archive of Our Own'),
  wattpad('Wattpad'),
  fanfiction('FanFiction.net'),
  otro('otro sitio');

  final String nombre;
  const Sitio(this.nombre);
}

class Fanfic {
  /// La identidad de un fanfic a partir de su enlace.
  ///
  /// Devuelve algo como `ao3:1234567`. Null si eso no parece una dirección.
  static String? identidad(String enlace) {
    final uri = _leer(enlace);
    if (uri == null) return null;

    final host = _host(uri);
    final partes = uri.pathSegments.where((p) => p.isNotEmpty).toList();

    // Archive of Our Own. El número de la obra es lo único que cuenta:
    // el capítulo, la colección y los parámetros son formas de mirarla.
    if (host.endsWith('archiveofourown.org')) {
      final i = partes.indexOf('works');
      if (i != -1 && i + 1 < partes.length) {
        final n = _numero(partes[i + 1]);
        if (n != null) return 'ao3:$n';
      }
    }

    // Wattpad. Las historias son /story/336699-el-titulo; el número de
    // adelante es el de la historia y el resto es el título pegado.
    if (host.endsWith('wattpad.com')) {
      final i = partes.indexOf('story');
      if (i != -1 && i + 1 < partes.length) {
        final n = _numero(partes[i + 1].split('-').first);
        if (n != null) return 'wattpad:$n';
      }
      // Un enlace a un capítulo suelto no dice a qué historia pertenece:
      // el número es del capítulo. No se puede inventar cuál es la
      // historia, así que se trata como una dirección más.
    }

    // FanFiction.net: /s/1234567/1/Titulo. El primero es la historia.
    if (host.endsWith('fanfiction.net')) {
      final i = partes.indexOf('s');
      if (i != -1 && i + 1 < partes.length) {
        final n = _numero(partes[i + 1]);
        if (n != null) return 'ffn:$n';
      }
    }

    // Cualquier otro sitio: el dominio y el camino, sin adornos. No es tan
    // firme como un número de obra —dos direcciones distintas pueden
    // llevar a lo mismo— pero sigue siendo mucho mejor que comparar
    // títulos escritos a mano.
    final camino = partes.join('/');
    return 'web:$host${camino.isEmpty ? '' : '/$camino'}';
  }

  /// De qué sitio es, para poder decirlo en pantalla.
  static Sitio sitioDe(String enlace) {
    final uri = _leer(enlace);
    if (uri == null) return Sitio.otro;

    final host = _host(uri);
    if (host.endsWith('archiveofourown.org')) return Sitio.ao3;
    if (host.endsWith('wattpad.com')) return Sitio.wattpad;
    if (host.endsWith('fanfiction.net')) return Sitio.fanfiction;
    return Sitio.otro;
  }

  /// El enlace limpio, para guardarlo y para abrirlo.
  ///
  /// Se guarda el que la persona pegó, pero ordenado: siempre `https`, sin
  /// `www`, sin los parámetros de sesión que a veces se cuelan al copiar
  /// desde el teléfono.
  static String? limpiar(String enlace) {
    final uri = _leer(enlace);
    if (uri == null) return null;

    final camino = uri.pathSegments.where((p) => p.isNotEmpty).join('/');
    return 'https://${_host(uri)}${camino.isEmpty ? '' : '/$camino'}';
  }

  static bool pareceEnlace(String texto) => identidad(texto) != null;

  /// Acepta lo que la gente pega de verdad: con espacios, sin `https://`,
  /// copiado desde el navegador del teléfono.
  static Uri? _leer(String crudo) {
    var texto = crudo.trim();
    if (texto.isEmpty) return null;

    if (!texto.startsWith('http://') && !texto.startsWith('https://')) {
      texto = 'https://$texto';
    }

    final uri = Uri.tryParse(texto);
    if (uri == null || uri.host.isEmpty) return null;

    // Un dominio de verdad tiene al menos un punto. Sin esto, escribir
    // «cometierra» daría una identidad válida.
    if (!uri.host.contains('.')) return null;

    return uri;
  }

  static String _host(Uri uri) {
    var host = uri.host.toLowerCase();
    for (final prefijo in ['www.', 'm.', 'mobile.']) {
      if (host.startsWith(prefijo)) host = host.substring(prefijo.length);
    }
    return host;
  }

  static String? _numero(String s) => RegExp(r'^\d+$').hasMatch(s) ? s : null;
}
