import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fanfic.dart';

/// Dónde está un libro en tu lectura. Es uno solo y siempre hay uno.
enum Estado { leyendo, leido, pendiente }

/// Cómo se ordena tu estante.
///
/// # Por qué «como los cargaste» es el orden de fábrica
///
/// Porque es el único que no le impone una idea a la biblioteca. Alfabético
/// es cómodo para encontrar, pero convierte el estante en un fichero; por
/// título perdés de vista lo último que sumaste, que es justo lo que
/// alguien suele estar buscando cuando abre la app.
enum Orden { cargados, titulo, autoria, terminados }

extension DatosDeOrden on Orden {
  String get nombre => switch (this) {
    Orden.cargados => 'Como los cargué',
    Orden.titulo => 'Por título',
    Orden.autoria => 'Por autoría',
    Orden.terminados => 'Por cuándo lo leí',
  };

  /// Corto, para la ficha que se muestra en pantalla.
  String get corto => switch (this) {
    Orden.cargados => 'Recientes',
    Orden.titulo => 'Título',
    Orden.autoria => 'Autoría',
    Orden.terminados => 'Leídos',
  };
}

/// Ordena una lista de libros, sin tocar la original.
///
/// # Por qué es una función aparte y no un método de Biblioteca
///
/// Para poder probarla con una lista escrita a mano, sin armar una
/// biblioteca ni tocar el disco. Ordenar es una regla, y una regla se
/// prueba sola.
///
/// # Los que no tienen el dato van al final, siempre
///
/// Un libro sin fecha de fin ordenado «por cuándo lo leí» no está ni
/// primero ni último: no tiene lugar en esa pregunta. Mandarlos al final
/// —en vez de al principio, que es lo que hace un null si se lo deja— es
/// lo que evita que ordenar por fecha te tape los libros que sí terminaste
/// con una pila de pendientes.
List<Libro> ordenados(List<Libro> libros, Orden orden) {
  final lista = [...libros];

  switch (orden) {
    case Orden.cargados:
      // Ya vienen así: `agregar` inserta al principio. No se toca, porque
      // reordenar por algo "equivalente" es la forma de introducir un
      // cambio de orden que nadie pidió.
      break;

    case Orden.titulo:
      lista.sort(
        (a, b) =>
            Libro._normalizar(a.titulo).compareTo(Libro._normalizar(b.titulo)),
      );

    case Orden.autoria:
      // Por apellido y no por nombre de pila: en un estante los libros de
      // Cortázar van juntos, no debajo de la J de Julio. Es la misma
      // cuenta que usa `claveDeObra` para saber si dos fichas son el mismo
      // libro, así que no hay dos ideas de "quién escribió esto".
      lista.sort((a, b) {
        final r = Libro._claveAutor(
          a.autor,
        ).compareTo(Libro._claveAutor(b.autor));
        // Del mismo autor, por título: si no, el orden de sus libros
        // cambia cada vez que se recarga la lista.
        return r != 0
            ? r
            : Libro._normalizar(
                a.titulo,
              ).compareTo(Libro._normalizar(b.titulo));
      });

    case Orden.terminados:
      lista.sort((a, b) {
        final ta = a.terminado;
        final tb = b.terminado;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1; // sin fecha, al final
        if (tb == null) return -1;
        return tb.compareTo(ta); // el más reciente primero
      });
  }

  return lista;
}

extension NombreEstado on Estado {
  String get nombre => switch (this) {
    Estado.leyendo => 'Leyendo',
    Estado.leido => 'Leídos',
    Estado.pendiente => 'Pendientes',
  };
}

/// De dónde salió la ficha de un libro.
///
/// Se guarda porque permite confiar en un dato sin revisarlo a mano, y
/// porque más adelante deja limpiar el catálogo sin romper nada. Hoy son
/// dos; cuando haya servidor se suma el de las autoras verificadas.
enum Origen {
  /// Vino de Open Library: tiene ficha, tapa y datos verificados.
  catalogo,

  /// Lo cargó una lectora porque no estaba en ningún lado. Acá va a
  /// vivir casi toda la narrativa latinoamericana reciente.
  propio,

  /// Un fanfic. No está ni va a estar en ningún catálogo de libros: los
  /// carga quien los lee, con su dirección.
  ///
  /// Es un origen propio y no un estante ni una etiqueta porque cambia
  /// cómo se identifica la ficha —por la dirección y no por el título— y
  /// eso es una regla del modelo, no una forma de ordenar.
  fanfic,
}

/// Las etiquetas de «cómo te deja».
///
/// # Por qué es una lista cerrada y no texto libre
///
/// Escribir lo que una quiera suena mejor, pero no suma: «me destruyó»,
/// «me destrozó» y «me rompió» son lo mismo dicho de tres maneras, y para
/// la app serían tres etiquetas con una persona cada una. Si nadie
/// coincide, no se puede buscar «algo que me destruya», que era el punto.
///
/// # Por qué son pocas
///
/// Con veinte lectoras y treinta etiquetas, cada una tendría cero o un
/// uso y la función se vería muerta el día que se abre. Doce que seguro
/// se usen valen más que treinta bien pensadas. Las demás entran después,
/// cuando la gente las pida y haya volumen para sostenerlas.
///
/// # La regla para agregar una
///
/// La etiqueta no describe el libro: describe lo que te hizo. «Triste» o
/// «bien escrito» hablan del libro, y para eso están las estrellas y las
/// reseñas. Ante la duda, probale poner «me» adelante.
class Animos {
  /// Cuántas se pueden elegir por libro.
  ///
  /// El tope es lo que convierte una opinión en un dato: si alguien tuvo
  /// que descartar «tierno» para dejar «me destruyó», ese «me destruyó»
  /// vale. Sin tope, la mitad marca ocho y ninguna significa nada.
  static const maximo = 3;

  static const todas = <String>[
    // Lo que te hizo
    'me destruyó',
    'me hizo llorar',
    'me dejó pensando',
    'me incomodó',
    // Cómo se leyó
    'no pude parar',
    'me costó entrar',
    'lento pero vale',
    // El clima
    'oscuro',
    'tierno',
    'gracioso',
    // Después
    'lo voy a releer',
    // La verdad. Si todas fueran buenas, todos los libros se verían bien
    // y ninguna serviría para decidir.
    'me aburrió',
  ];
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

  /// No es `final`, como casi todo lo demás de esta clase, y por el mismo
  /// motivo: la tapa se completa después. Un libro puede entrar sin
  /// portada —importado de una lista, cargado a mano— y conseguirla más
  /// tarde sin dejar de ser el mismo libro.
  int? tapaId;

  /// De dónde se lee: la dirección del fanfic.
  ///
  /// En un fanfic esto no es un dato más, **es la identidad**: dos fichas
  /// con la misma dirección son el mismo fic aunque tengan títulos
  /// distintos. Ver [clave].
  final String? enlace;

  /// De qué es el fanfic: «Harry Potter», «Percy Jackson», «Stranger
  /// Things». Es la primera pregunta que se hace cualquiera, antes que el
  /// título, y por eso es un campo propio y no una etiqueta más.
  final String? fandom;

  /// El código de barras del libro, cuando se sabe.
  ///
  /// Se guarda porque es la única forma de volver a preguntar por *esta*
  /// edición. Lo trae el escáner y lo trae la lista de Goodreads, y con él
  /// se puede ir a buscar la tapa que falta mucho después de haberlo
  /// cargado, sin volver a tenerlo en la mano.
  final String? isbn;

  /// La dirección de la tapa, cuando viene de Google Books.
  ///
  /// Open Library da un número y la dirección se arma con él. Google da la
  /// dirección entera y ya. Conviven porque cada catálogo entrega lo que
  /// entrega, y la app pregunta por [Api.tapaDe] sin tener que saber de
  /// dónde salió cada libro.
  String? tapaUrl;
  final String? editorial;
  final int? anio;

  Estado estado;

  /// Las cuatro puntuaciones, todas de 0 a 5 y todas opcionales.
  ///
  /// Van juntas porque miden cosas distintas del mismo libro: [puntaje]
  /// dice qué tan bueno es, [lagrimas] cuánto te hizo llorar, [romantico]
  /// cuánto amor hay y [picante] cuánto calienta.
  ///
  /// Que sean independientes es el punto: un libro puede ser flojo y
  /// hacerte llorar igual, o ser romántico sin nada de picante. Con una
  /// sola nota, todo eso se pierde.
  int puntaje; // estrellas · 0 = sin puntuar
  int lagrimas; // gotas
  int romantico; // corazones
  int picante; // chiles

  /// Cómo te dejó. Hasta [Animos.maximo].
  final List<String> animos;
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

  /// Lo que anotás para vos, y que nadie más va a leer.
  ///
  /// # Por qué es otro campo y no «la reseña, pero privada»
  ///
  /// Porque son dos cosas que se escriben distinto. Una reseña se escribe
  /// para alguien: se cuida el tono, se avisa de los spoilers, se piensa
  /// si conviene contar el final. Una nota se escribe para una misma —«la
  /// escena del tren me recordó a mi abuela», «releer el capítulo 12»— y
  /// eso no se escribe igual si existe la posibilidad de que se publique.
  ///
  /// Del lado del servidor están en tablas separadas por una razón más
  /// dura, que está escrita en `servidor/esquema.sql`: **Postgres protege
  /// filas, no columnas.** Si la nota fuera una columna de `lecturas`, el
  /// permiso que deja a otra persona ver tu estante dejaría ver también
  /// tus notas. Separada, la regla es una línea y no se puede equivocar.
  String? nota;

  /// Tus personajes favoritos.
  ///
  /// Son varios porque en un libro coral quedarse con uno solo es una
  /// tortura, y porque el día que haya comunidad la coincidencia va a
  /// ser más fina cuantos más haya: compartir un personaje favorito dice
  /// **cómo** leíste el libro, no solo qué leíste.
  final List<String> personajes;

  /// Las frases que subrayaste de este libro.
  final List<Frase> frases;

  /// De dónde salió esta ficha.
  final Origen origen;

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
    this.tapaUrl,
    this.isbn,
    this.enlace,
    this.fandom,
    this.editorial,
    this.anio,
    this.estado = Estado.pendiente,
    this.puntaje = 0,
    this.lagrimas = 0,
    this.romantico = 0,
    this.picante = 0,
    this.paginaActual = 0,
    this.paginas,
    this.empezado,
    this.terminado,
    this.resena,
    this.resenaConSpoilers = false,
    this.nota,
    this.origen = Origen.catalogo,
    Set<String>? estantes,
    List<Frase>? frases,
    List<String>? personajes,
    List<String>? animos,
  }) : estantes = estantes ?? <String>{},
       frases = frases ?? <Frase>[],
       personajes = personajes ?? <String>[],
       animos = animos ?? <String>[];

  bool get tieneResena => (resena ?? '').trim().isNotEmpty;
  bool get tieneNota => (nota ?? '').trim().isNotEmpty;

  /// Cuántos días te llevó. Contamos el primero y el último, así que
  /// empezar y terminar el mismo día da 1 y no 0.
  int? get diasDeLectura {
    if (empezado == null || terminado == null) return null;
    final d = terminado!.difference(empezado!).inDays + 1;
    return d < 1 ? 1 : d;
  }

  /// Clave para detectar que dos personas tienen el mismo libro,
  /// aunque lo hayan cargado desde ediciones distintas.
  /// Qué hace que dos fichas sean el mismo libro.
  ///
  /// Para un libro es el título más el apellido, y es lo mejor que se
  /// puede hacer: no hay nada mejor que comparar.
  ///
  /// Para un fanfic **sí lo hay**, y es su dirección. Ahí no comparamos
  /// títulos escritos a mano, porque el mismo fic cargado por cuatro mil
  /// personas tendría cuatro mil títulos distintos y una sola dirección.
  /// Ver [Fanfic.identidad].
  String get clave {
    final id = enlace == null ? null : Fanfic.identidad(enlace!);
    if (origen == Origen.fanfic && id != null) return 'fanfic|$id';

    return claveDeObra;
  }

  /// La clave de la obra, sin el prefijo de fanfic.
  ///
  /// Es la misma cuenta que [clave] para un libro, pero pública y con
  /// nombre propio porque hace falta en otro lugar: al sincronizar con
  /// la nube, la tabla `obras` se identifica por esto, y ahí siempre es
  /// la clave de la obra, nunca la del fanfic, aunque el libro fuera uno.
  String get claveDeObra => '${_normalizar(titulo)}|${_claveAutor(autor)}';

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
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
      'Á': 'a',
      'É': 'e',
      'Í': 'i',
      'Ó': 'o',
      'Ú': 'u',
      'Ñ': 'n',
    };
    var r = s.toLowerCase().trim();
    acentos.forEach((k, v) => r = r.replaceAll(k, v));
    return r
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
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

  /// Un libro como lo cuenta Google Books.
  ///
  /// # Qué trae distinto
  ///
  /// Google devuelve **la edición**, no la obra. Open Library, buscando lo
  /// mismo, devuelve el título original: pedís «la piedra filosofal» y te
  /// contesta «the Philosopher's Stone». Google contesta con el título de
  /// la edición que existe, en el idioma en que existe. Para una app que
  /// se lee en castellano, eso no es un detalle.
  ///
  /// # Las tapas vienen con dos vicios
  ///
  /// Llegan por `http`, y una página segura no muestra imágenes inseguras:
  /// se verían todas rotas. Y traen `edge=curl`, que le dibuja encima una
  /// esquina doblada de papel, simpática en 2010 y fuera de lugar acá.
  factory Libro.desdeGoogle(Map<String, dynamic> v) {
    final info = (v['volumeInfo'] as Map?)?.cast<String, dynamic>() ?? {};
    final autores = (info['authors'] as List?)?.cast<String>() ?? const [];

    return Libro(
      // Con prefijo para que nunca choque con una clave de Open Library.
      id: 'google:${v['id']}',
      titulo: (info['title'] as String?) ?? 'Sin título',
      autor: autores.isEmpty ? 'Autor desconocido' : autores.first,
      tapaUrl: _tapaDeGoogle(info),
      editorial: info['publisher'] as String?,
      anio: _anioDeGoogle(info['publishedDate'] as String?),
      paginas: info['pageCount'] as int?,
    );
  }

  static String? _tapaDeGoogle(Map<String, dynamic> info) {
    final imagenes = (info['imageLinks'] as Map?)?.cast<String, dynamic>();
    final url =
        (imagenes?['thumbnail'] ?? imagenes?['smallThumbnail']) as String?;
    if (url == null) return null;

    return url.replaceFirst('http://', 'https://').replaceAll('&edge=curl', '');
  }

  /// La fecha viene de tres formas: «2019», «2019-03» y «2019-03-15».
  /// De las tres nos sirve lo mismo.
  static int? _anioDeGoogle(String? fecha) {
    if (fecha == null || fecha.length < 4) return null;
    return int.tryParse(fecha.substring(0, 4));
  }

  Map<String, dynamic> aJson() => {
    'id': id,
    'titulo': titulo,
    'autor': autor,
    'tapaId': tapaId,
    'tapaUrl': tapaUrl,
    'isbn': isbn,
    'enlace': enlace,
    'fandom': fandom,
    'editorial': editorial,
    'anio': anio,
    'estado': estado.index,
    'puntaje': puntaje,
    'lagrimas': lagrimas,
    'romantico': romantico,
    'picante': picante,
    'animos': animos,
    'paginaActual': paginaActual,
    'paginas': paginas,
    'estantes': estantes.toList(),
    'empezado': empezado?.toIso8601String(),
    'terminado': terminado?.toIso8601String(),
    'resena': resena,
    'resenaConSpoilers': resenaConSpoilers,
    'nota': nota,
    'personajes': personajes,
    'frases': frases.map((f) => f.aJson()).toList(),
    'origen': origen.index,
  };

  static DateTime? _fecha(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  factory Libro.desdeJson(Map<String, dynamic> j) => Libro(
    id: j['id'] as String,
    titulo: j['titulo'] as String,
    autor: j['autor'] as String,
    tapaId: j['tapaId'] as int?,
    tapaUrl: j['tapaUrl'] as String?,
    isbn: j['isbn'] as String?,
    enlace: j['enlace'] as String?,
    fandom: j['fandom'] as String?,
    editorial: j['editorial'] as String?,
    anio: j['anio'] as int?,
    // 'estante' es el nombre viejo: lo leemos para no perder datos
    // de quien ya venía usando la demo.
    estado: Estado.values[(j['estado'] ?? j['estante'] ?? 2) as int],
    puntaje: (j['puntaje'] as int?) ?? 0,
    lagrimas: (j['lagrimas'] as int?) ?? 0,
    romantico: (j['romantico'] as int?) ?? 0,
    picante: (j['picante'] as int?) ?? 0,
    animos: ((j['animos'] as List?)?.cast<String>()) ?? const [],
    paginaActual: (j['paginaActual'] as int?) ?? 0,
    paginas: j['paginas'] as int?,
    estantes: ((j['estantes'] as List?) ?? const [])
        .map((e) => e as String)
        .toSet(),
    empezado: _fecha(j['empezado']),
    terminado: _fecha(j['terminado']),
    resena: j['resena'] as String?,
    nota: j['nota'] as String?,
    resenaConSpoilers: (j['resenaConSpoilers'] as bool?) ?? false,
    // 'personaje' en singular es el nombre viejo, de cuando era uno
    // solo: lo leemos para no perderle el dato a nadie.
    personajes:
        ((j['personajes'] as List?)?.cast<String>()) ??
        [if (j['personaje'] != null) j['personaje'] as String],
    frases: ((j['frases'] as List?) ?? const [])
        .map((f) => Frase.desdeJson(f as Map<String, dynamic>))
        .toList(),
    origen: Origen.values[(j['origen'] as int?) ?? 0],
  );
}

/// La biblioteca de quien usa la app. Se guarda en el teléfono.
class Biblioteca extends ChangeNotifier {
  /// El enganche para sincronizar con la nube.
  ///
  /// Biblioteca no sabe que existe un servidor, y es a propósito: sigue
  /// siendo probable sin cuenta ni internet, como siempre fue. Quien
  /// sincroniza —ver `nube.dart`— se registra acá, y por defecto no hacen
  /// nada.
  ///
  /// Va con el libro puntual que cambió y no con la biblioteca entera:
  /// subir todo de nuevo cada vez que se toca una estrella sería cientos
  /// de pedidos por un solo toque.
  void Function(Libro libro)? alGuardarUnLibro;

  /// Igual, para cuando un libro se saca de la biblioteca. Va con la
  /// clave y no con el libro porque para entonces ya no está en la lista.
  void Function(String clave)? alQuitarUnLibro;

  static const _claveLibros = 'colibri.biblioteca.v1';
  static const _claveEstantes = 'colibri.estantes.v1';
  static const _claveConTexto = 'colibri.conTexto.v1';
  static const _clavePropuestas = 'colibri.animosPropuestos.v1';

  final List<Libro> _libros = [];

  /// Los nombres de estantes, en el orden en que se crearon.
  /// Viven acá y no solo dentro de los libros para que un estante
  /// recién creado, todavía vacío, no desaparezca.
  final List<String> _estantes = [];

  /// Todo lo que leíste: libros y fanfics juntos.
  ///
  /// Casi nunca es lo que se quiere mostrar —las dos cosas viven en
  /// secciones distintas— pero sí es lo que hay que mirar para contar,
  /// para buscar y para saber si algo ya está.
  List<Libro> get todos => List.unmodifiable(_libros);

  /// Los libros, sin los fanfics.
  List<Libro> get libros =>
      _libros.where((l) => l.origen != Origen.fanfic).toList();

  /// Los fanfics, que tienen su propia sección.
  List<Libro> get fanfics =>
      _libros.where((l) => l.origen == Origen.fanfic).toList();

  List<String> get estantes => List.unmodifiable(_estantes);

  /// Los libros en un estado. **Sin fanfics**: esos tienen su sección, y
  /// mostrarlos en los dos lados sería contar dos veces lo mismo.
  List<Libro> enEstado(Estado e) => libros.where((l) => l.estado == e).toList();

  List<Libro> fanficsEnEstado(Estado e) =>
      fanfics.where((l) => l.estado == e).toList();

  List<Libro> enEstante(String nombre) =>
      _libros.where((l) => l.estantes.contains(nombre)).toList();

  Libro? get leyendoAhora {
    final l = enEstado(Estado.leyendo);
    return l.isEmpty ? null : l.first;
  }

  Libro? get ficLeyendoAhora {
    final l = fanficsEnEstado(Estado.leyendo);
    return l.isEmpty ? null : l.first;
  }

  bool tiene(Libro libro) => _libros.any((l) => l.clave == libro.clave);

  /// Libros de tu biblioteca que se parecen a este título.
  ///
  /// Se usa para avisar antes de cargar un duplicado. Sugiere, nunca
  /// bloquea: a veces son ediciones distintas y la persona tiene razón.
  List<Libro> parecidos(String titulo) {
    final buscado = Libro._normalizar(titulo);
    if (buscado.length < 3) return const [];

    return _libros.where((l) {
      final suyo = Libro._normalizar(l.titulo);
      return suyo.contains(buscado) || buscado.contains(suyo);
    }).toList();
  }

  /// Busca en lo que ya tenés, no en internet.
  ///
  /// Mira el título, la autoría y los nombres de tus estantes, así
  /// escribir «fantasia» te trae todo lo que pusiste ahí. Sin acentos ni
  /// mayúsculas: nadie se acuerda de cómo se escribía.
  ///
  /// No filtra por solapa a propósito. Si estás en «Leyendo» y buscás un
  /// libro que tenés en pendientes, lo que querés es encontrarlo, no que
  /// la app te diga que no lo tenés.
  ///
  /// Y **sí incluye los fanfics**, aunque vivan en otra sección. Que la
  /// app te diga «no lo tenés» cuando lo tenés es el peor resultado
  /// posible de una búsqueda, y peor que mezclar.
  List<Libro> buscarEnMiBiblioteca(String texto) {
    final aguja = Libro._normalizar(texto);
    if (aguja.length < 2) return const [];

    return _libros
        .where(
          (l) =>
              Libro._normalizar(l.titulo).contains(aguja) ||
              Libro._normalizar(l.autor).contains(aguja) ||
              l.estantes.any((e) => Libro._normalizar(e).contains(aguja)),
        )
        .toList();
  }

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
    alGuardarUnLibro?.call(libro);
  }

  /// Sumar muchos libros de una, guardando una sola vez.
  ///
  /// # Por qué no alcanza con llamar a [agregar] en un bucle
  ///
  /// Cada `agregar` escribe **la biblioteca entera** en el disco del
  /// teléfono. Con doscientos libros eso son doscientas escrituras que
  /// crecen a medida que avanzan, y la última escribe los doscientos.
  /// Importar quedaba trabado varios segundos con la pantalla congelada.
  ///
  /// Devuelve cuántos entraron. Los que ya estaban se saltean, sin pisar
  /// nada: si ya tenías *Cometierra* con tu reseña, lo que trae Goodreads
  /// no puede reemplazarla.
  Future<int> agregarVarios(List<Libro> nuevos) async {
    final agregados = <Libro>[];
    for (final libro in nuevos) {
      if (tiene(libro)) continue;
      _libros.insert(0, libro);
      agregados.add(libro);
    }
    if (agregados.isNotEmpty) await _guardar();
    for (final libro in agregados) {
      alGuardarUnLibro?.call(libro);
    }
    return agregados.length;
  }

  Future<void> quitar(Libro libro) async {
    _libros.removeWhere((l) => l.clave == libro.clave);
    await _guardar();
    alQuitarUnLibro?.call(libro.clave);
  }

  /// Para cuando se cambia algo de un libro que ya está guardado.
  ///
  /// [cambiados] es opcional para no romper a nadie que ya llamaba a esto
  /// sin argumentos, pero sin él la nube nunca se entera de qué cambió:
  /// quien edite un campo de un libro debería pasarlo.
  Future<void> actualizar([List<Libro>? cambiados]) async {
    await _guardar();
    for (final libro in cambiados ?? const <Libro>[]) {
      alGuardarUnLibro?.call(libro);
    }
  }

  /// Cambia el estado y, de paso, anota las fechas si estaban vacías.
  ///
  /// Es el tipo de ayuda que se agradece sin notarla: si marcaste
  /// "leyendo" hoy, empezaste hoy. Nunca pisa una fecha ya puesta, y
  /// siempre se puede corregir a mano.
  ///
  /// El parámetro [hoy] existe para que los tests no dependan del
  /// día en que se corran.
  Future<void> cambiarEstado(Libro libro, Estado nuevo, {DateTime? hoy}) async {
    // Tocar el estado que ya estaba puesto lo deshace y vuelve a
    // pendiente. Es la salida para el toque sin querer: sin esto, marcar
    // "leído" por error deja una fecha de fin inventada y un "lo leíste
    // en un día" que no pasó, y no hay forma de arreglarlo.
    if (libro.estado == nuevo && nuevo != Estado.pendiente) {
      libro.estado = Estado.pendiente;
      // Se van solo las fechas que había puesto la app sola. Si la
      // persona las eligió a mano, son suyas y se quedan.
      if (nuevo == Estado.leido) libro.terminado = null;
      if (nuevo == Estado.leyendo) libro.empezado = null;
      await _guardar();
      alGuardarUnLibro?.call(libro);
      return;
    }

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
    alGuardarUnLibro?.call(libro);
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
    final tocados = _libros.where((l) => l.estantes.contains(nombre)).toList();
    _estantes.remove(nombre);
    for (final l in tocados) {
      l.estantes.remove(nombre);
    }
    await _guardar();
    for (final l in tocados) {
      alGuardarUnLibro?.call(l);
    }
  }

  Future<void> renombrarEstante(String viejo, String nuevo) async {
    final limpio = nuevo.trim();
    if (limpio.isEmpty || limpio == viejo) return;
    final i = _estantes.indexOf(viejo);
    if (i == -1) return;
    _estantes[i] = limpio;
    final tocados = <Libro>[];
    for (final l in _libros) {
      if (l.estantes.remove(viejo)) {
        l.estantes.add(limpio);
        tocados.add(l);
      }
    }
    await _guardar();
    for (final l in tocados) {
      alGuardarUnLibro?.call(l);
    }
  }

  Future<void> alternarEstante(Libro libro, String nombre) async {
    if (!libro.estantes.remove(nombre)) libro.estantes.add(nombre);
    await _guardar();
    alGuardarUnLibro?.call(libro);
  }

  // ---------- Etiquetas que pide la gente ----------

  /// Las etiquetas de ánimo que las lectoras pidieron y no están.
  ///
  /// No se publican: quedan guardadas para leerlas. Cuando una misma
  /// propuesta aparezca muchas veces, se suma a [Animos.todas]. Así las
  /// palabras terminan siendo de la comunidad, pero entran de a una y
  /// cuando ya hay quien las use.
  ///
  /// Hoy viven en el teléfono de cada una; con servidor van a llegar
  /// todas juntas a un solo lugar.
  final List<String> _propuestas = [];

  List<String> get animosPropuestos => List.unmodifiable(_propuestas);

  Future<void> proponerAnimo(String texto) async {
    final limpio = texto.trim().toLowerCase();
    if (limpio.isEmpty || limpio.length > 40) return;
    if (Animos.todas.any((a) => a.toLowerCase() == limpio)) return;
    _propuestas.add(limpio);
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

    _propuestas
      ..clear()
      ..addAll(prefs.getStringList(_clavePropuestas) ?? const []);

    final crudoLibros = prefs.getString(_claveLibros);
    if (crudoLibros != null) {
      try {
        final lista = jsonDecode(crudoLibros) as List;
        _libros
          ..clear()
          ..addAll(
            lista.map((j) => Libro.desdeJson(j as Map<String, dynamic>)),
          );
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
    await prefs.setStringList(_clavePropuestas, _propuestas);
  }
}

/// Una sola instancia para toda la app. Alcanza para una demo.
final biblioteca = Biblioteca();

/// Dónde estabas la última vez.
///
/// # El problema
///
/// En la web, recargar la página arranca la app de cero: si estabas
/// mirando un libro, volvés a la biblioteca y perdés el lugar. Y no pasa
/// solo al recargar: cuando el teléfono se queda sin memoria y cierra la
/// app en segundo plano, al volver hace lo mismo.
///
/// # Por qué no lo resolvemos con direcciones
///
/// Lo prolijo sería que cada pantalla tenga su URL —`/libro/rayuela`— y
/// que el navegador se encargue. Eso además haría andar los botones de
/// atrás y adelante del navegador.
///
/// Pero es un cambio grande y hoy no hace falta: **guardar dónde estabas
/// alcanza para que recargar no duela.** Cuando la app tenga que
/// compartir enlaces a un libro, ahí sí van a hacer falta direcciones de
/// verdad, y este archivo se tira.
class Sesion extends ChangeNotifier {
  static const _clave = 'colibri.sesion.v3';

  /// Los formatos anteriores. Se leen una vez, corriendo lo que haya que
  /// correr, para no mandar a nadie a una pantalla que no era la que había
  /// dejado abierta.
  ///
  /// - **v1**: la biblioteca no tenía la solapa «Todos», así que las
  ///   solapas se corrieron un lugar.
  /// - **v2**: no existía la sección «Fanfics», que entró segunda, así que
  ///   las secciones de la barra de abajo se corrieron un lugar.
  ///
  /// Si esto pasa una tercera vez, conviene dejar de guardar números y
  /// guardar nombres: un número solo significa algo si la lista no cambia
  /// nunca, y esta lista ya cambió dos veces.
  static const _v2 = 'colibri.sesion.v2';
  static const _v1 = 'colibri.sesion.v1';

  /// Qué sección de la barra de abajo: biblioteca, fanfics, frases o
  /// comunidad.
  int seccion = 0;

  /// Qué solapa dentro de la biblioteca: todos, leyendo, leídos,
  /// pendientes, estantes.
  int solapa = 0;

  /// Qué libro estabas mirando, o null si estabas en una lista.
  String? libro;

  /// Cómo tenés ordenado el estante.
  ///
  /// Se guarda **por nombre** y no por número, siguiendo el consejo que
  /// dejó escrito el comentario de arriba después de que las solapas se
  /// corrieran dos veces: un número solo significa algo si la lista no
  /// cambia nunca, y el día que se agregue un orden más, el número
  /// guardado apuntaría a otra cosa.
  Orden orden = Orden.cargados;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();

    // Se vuelve a los valores de fábrica antes de leer.
    //
    // Sin esto, `cargar()` con el almacenamiento vacío dejaba los campos
    // como estaban en memoria: no establecía el estado, lo pisaba a veces.
    // En la app no se notaba porque arrancar el proceso ya los deja de
    // fábrica; se notó en las pruebas, donde una prueba se llevaba el
    // orden que había elegido la anterior. Un método que se llama
    // «cargar» tiene que dejar el mismo estado siempre que se lo llame
    // con el mismo almacenamiento.
    seccion = 0;
    solapa = 0;
    libro = null;
    orden = Orden.cargados;

    final crudo = prefs.getString(_clave);
    if (crudo != null) {
      _leer(crudo);
      return;
    }

    // Nunca se guardó en el formato nuevo: puede haber uno anterior.
    final v2 = prefs.getString(_v2);
    if (v2 != null) {
      _leer(v2);
      // «Fanfics» entró segunda en la barra de abajo: Frases y Comunidad
      // se corrieron un lugar.
      if (seccion >= 1) seccion = seccion + 1;
      return;
    }

    final v1 = prefs.getString(_v1);
    if (v1 == null) return;

    _leer(v1);
    // Los dos corrimientos, en orden: primero la solapa «Todos», después
    // la sección «Fanfics».
    solapa = solapa + 1;
    if (seccion >= 1) seccion = seccion + 1;
  }

  void _leer(String crudo) {
    try {
      final j = jsonDecode(crudo) as Map<String, dynamic>;
      seccion = (j['seccion'] as int?) ?? 0;
      solapa = (j['solapa'] as int?) ?? 0;
      libro = j['libro'] as String?;
      orden = Orden.values.firstWhere(
        (o) => o.name == j['orden'],
        // Un nombre que la app ya no conoce vuelve al de fábrica, que es
        // mejor que caerse al arrancar.
        orElse: () => Orden.cargados,
      );
    } catch (_) {
      // Formato roto: arrancamos en la biblioteca y listo.
    }
  }

  Future<void> anotar({
    int? seccion,
    int? solapa,
    String? libro,
    Orden? orden,
    bool cerrarLibro = false,
  }) async {
    if (seccion != null) this.seccion = seccion;
    if (solapa != null) this.solapa = solapa;
    if (orden != null) this.orden = orden;
    if (cerrarLibro) {
      this.libro = null;
    } else if (libro != null) {
      this.libro = libro;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode({
        'seccion': this.seccion,
        'solapa': this.solapa,
        'libro': this.libro,
        'orden': this.orden.name,
      }),
    );
  }
}

final sesion = Sesion();

/// "12 mar 2026". Sin paquetes de fechas: para tres usos alcanza y sobra,
/// y evita arrastrar una dependencia entera por doce palabras.
String fechaCorta(DateTime d) {
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${d.day} ${meses[d.month - 1]} ${d.year}';
}
