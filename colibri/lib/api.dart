import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'google.dart';
import 'isbn.dart';
import 'modelos.dart';

/// Las ediciones de una obra, separadas por lo que el catálogo sabe.
///
/// [confirmadas] son las que dicen estar en el idioma que pediste.
/// [sinIdioma] son las que **no dicen nada**: el catálogo nunca lo anotó.
/// No se descartan, porque muchas veces la edición que alguien tiene en la
/// mano está ahí, y no se adivina, porque equivocarse de idioma sería peor
/// que admitir que no se sabe.
///
/// Cuando no se filtra por idioma, todas caen en [confirmadas].
typedef Ediciones = ({List<Libro> confirmadas, List<Libro> sinIdioma});

/// Una edición con los idiomas que Open Library le anotó.
///
/// Los idiomas van al lado del libro y no adentro porque un libro no tiene
/// idioma: lo tiene su edición. Agregarle un campo al modelo entero por
/// algo que solo usa la pantalla de elegir edición sería ensuciarlo.
typedef Edicion = ({Libro libro, List<String> idiomas});

/// Open Library: abierta, gratis y sin clave.
/// Es floja en ediciones latinoamericanas, y esta demo sirve justamente
/// para medir cuánto le falta con los libros que lee tu comunidad.
class Api {
  static const _campos =
      'key,title,author_name,cover_i,first_publish_year,publisher,'
      'number_of_pages_median,edition_count';

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

  /// Cuántos resultados de Open Library alcanzan para no molestar a Google.
  ///
  /// Google entra **solo cuando Open Library queda corto**, y no siempre,
  /// por una razón concreta: los dos devuelven el mismo libro con títulos
  /// distintos —Open Library el de la obra original, Google el de la
  /// edición traducida— y mezclarlos siempre llenaría la lista de pares
  /// que parecen repetidos. Eso ya lo probamos y era un desastre.
  ///
  /// De paso, la clave gratis de Google trae mil consultas por día. Usarla
  /// solo cuando hace falta es la diferencia entre que alcance y que no.
  static const _suficientes = 5;

  static Future<List<Libro>> buscar(String consulta) async {
    if (consulta.trim().length < 3) return [];

    final uri = Uri.https('openlibrary.org', '/search.json', {
      'q': consulta.trim(),
      // Pedimos de más porque después se agrupan los repetidos: si
      // pidiéramos veinte, podrían quedar cuatro.
      'limit': '60',
      'fields': _campos,
    });

    final respuesta = await http
        .get(uri, headers: _cabeceras)
        .timeout(const Duration(seconds: 15));

    if (respuesta.statusCode != 200) return [];

    final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
    final docs = (datos['docs'] as List?) ?? const [];
    final abiertos = sinRepetidos(docs.cast<Map<String, dynamic>>());

    if (abiertos.length >= _suficientes) return abiertos;

    return unir(abiertos, await Google.buscar(consulta));
  }

  /// Los libros de una categoría.
  ///
  /// # Cómo se eligieron las categorías
  ///
  /// Midiendo, y el resultado contradijo lo que yo esperaba. Probé
  /// dieciocho categorías amplias —«Fantasía», «Romance», «Poesía»— y las
  /// tres devuelven dominio público: *Robinson Crusoe* aparece en Poesía,
  /// *La letra escarlata* en Manga, *Alicia en el país de las maravillas*
  /// en Ciencia ficción. Ese endpoint ordena por peso del catálogo, y lo
  /// más pesado son los libros de hace cien años. `published_in` no lo
  /// arregla: probado, devuelve exactamente lo mismo y más lento.
  ///
  /// Las que sirven son las **específicas**, justo las que yo había
  /// descartado por tener catálogos chicos: `romantasy` tiene 127 obras y
  /// las diez primeras son *Once Upon a Broken Heart*, *The Serpent & the
  /// Wings of Night*, todas de 2020 en adelante. `literatura_argentina`
  /// tiene 50 y arranca con *El hacedor* y *Plan de evasión*. El tamaño
  /// del catálogo no medía nada; lo que medía era si los libros son los
  /// que alguien está leyendo hoy.
  ///
  /// Google Books tampoco sirvió acá: `subject:` contesta en 0,7 s pero
  /// con `langRestrict=es` devolvió **cero** libros en español.
  ///
  /// # Y de paso es una sola consulta
  ///
  /// Devuelve hasta veinte libros con su número de tapa en un pedido de
  /// unos 3 segundos. La búsqueda por título, en cambio, es un pedido por
  /// libro.
  static Future<List<Libro>> porCategoria(String etiqueta) async {
    final uri = Uri.https('openlibrary.org', '/subjects/$etiqueta.json', {
      'limit': '20',
    });

    try {
      final respuesta = await http
          .get(uri, headers: _cabeceras)
          .timeout(const Duration(seconds: 25));
      if (respuesta.statusCode != 200) return const [];

      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      return librosDeCategoria((datos['works'] as List?) ?? const []);
    } catch (_) {
      return const [];
    }
  }

  /// Las obras de una categoría, convertidas en libros.
  ///
  /// Aparte y pública porque es lo único de acá que se puede probar sin
  /// red: recibe la lista que devolvió Open Library y no toca internet.
  static List<Libro> librosDeCategoria(List<dynamic> obras) {
    final salida = <Libro>[];
    final vistos = <String>{};

    for (final cruda in obras) {
      if (cruda is! Map) continue;
      final o = cruda.cast<String, dynamic>();

      final titulo = o['title'] as String?;
      if (titulo == null || titulo.trim().isEmpty) continue;

      final autores = (o['authors'] as List?) ?? const [];
      final autor = autores.isEmpty
          ? 'Autor desconocido'
          : (((autores.first as Map)['name'] as String?) ??
                'Autor desconocido');

      final libro = Libro(
        id: (o['key'] as String?) ?? titulo,
        titulo: titulo,
        autor: autor,
        tapaId: o['cover_id'] as int?,
        anio: o['first_publish_year'] as int?,
      );

      // Sin repetidos: la misma obra puede venir dos veces con claves
      // distintas, y en una fila de cinco tapas eso se nota enseguida.
      if (vistos.add(libro.clave)) salida.add(libro);
    }

    return salida;
  }

  /// Junta dos catálogos sin repetir libros.
  ///
  /// El orden importa: primero lo que ya estaba. Quien busca casi siempre
  /// quiere el primer resultado, y mover de lugar lo que Open Library puso
  /// arriba para meter algo nuevo sería peor que no traer nada.
  static List<Libro> unir(
    List<Libro> primero,
    List<Libro> segundo, {
    int maximo = 15,
  }) {
    final vistos = <String>{};
    final juntos = <Libro>[];

    for (final libro in [...primero, ...segundo]) {
      if (juntos.length >= maximo) break;
      if (vistos.add(libro.clave)) juntos.add(libro);
    }
    return juntos;
  }

  /// Agrupa los resultados repetidos y se queda con el mejor de cada uno.
  ///
  /// # Por qué hace falta
  ///
  /// Open Library tiene la misma novela cargada como varias obras
  /// distintas: "Cazadores de sombras", "Cazadores De Sombras" y
  /// "Cazadores de sombras" con autor desconocido son tres fichas de un
  /// mismo libro. Buscar devolvía las tres y la pantalla se volvía un
  /// listado inservible.
  ///
  /// # Cómo agrupa
  ///
  /// Por título normalizado más el apellido de quien escribe. El apellido
  /// y no el nombre completo, porque una ficha dice "Cassandra Clare" y
  /// otra "Clare, Cassandra".
  ///
  /// Las fichas sin autor se pegan al grupo de ese título si hay uno solo
  /// con autor conocido: casi siempre son la misma obra mal cargada. Si
  /// hay dos autores distintos para el mismo título, se muestran los dos:
  /// **probablemente sean libros diferentes y perder uno es peor que
  /// mostrar dos.**
  static List<Libro> sinRepetidos(
    List<Map<String, dynamic>> docs, {
    int maximo = 15,
  }) {
    final grupos = <String, List<Map<String, dynamic>>>{};
    final sinAutor = <String, List<Map<String, dynamic>>>{};

    for (final d in docs) {
      final titulo = _normalizar((d['title'] as String?) ?? '');
      if (titulo.isEmpty) continue;

      final apellido = _apellido(d);
      if (apellido.isEmpty) {
        sinAutor.putIfAbsent(titulo, () => []).add(d);
      } else {
        grupos.putIfAbsent('$titulo|$apellido', () => []).add(d);
      }
    }

    // Las fichas sin autor se suman al único grupo de su título, si lo
    // hay. Si no lo hay, quedan como grupo propio: algo es algo.
    sinAutor.forEach((titulo, sueltas) {
      final candidatos = grupos.keys
          .where((k) => k.startsWith('$titulo|'))
          .toList();
      if (candidatos.length == 1) {
        grupos[candidatos.first]!.addAll(sueltas);
      } else if (candidatos.isEmpty) {
        grupos['$titulo|'] = sueltas;
      }
    });

    // Segunda pasada: los grupos flojos se comen.
    //
    // Cuando dos grupos comparten título pero tienen autores distintos,
    // casi siempre uno es la ficha buena y el otro tiene puesto al
    // traductor o al ilustrador en lugar de a quien escribió. Se nota en
    // el peso: la ficha buena junta decenas de ediciones y la otra tiene
    // una sola.
    //
    // Si un grupo pesa menos de la cuarta parte que el más grande de su
    // título, se absorbe. Si los dos pesan parecido se quedan los dos:
    // ahí sí es probable que sean libros diferentes.
    final porTitulo = <String, List<String>>{};
    for (final k in grupos.keys) {
      porTitulo.putIfAbsent(k.split('|').first, () => []).add(k);
    }

    porTitulo.forEach((_, claves) {
      if (claves.length < 2) return;

      int peso(String k) =>
          grupos[k]!.fold(0, (s, d) => s + ((d['edition_count'] as int?) ?? 1));

      final masFuerte = claves.reduce((a, b) => peso(b) > peso(a) ? b : a);
      for (final k in claves) {
        if (k == masFuerte) continue;
        if (peso(k) * 4 <= peso(masFuerte)) {
          grupos[masFuerte]!.addAll(grupos[k]!);
          grupos.remove(k);
        }
      }
    });

    // Se respeta el orden en que vinieron: Open Library los manda por
    // relevancia y esa parte la hace bien.
    final vistos = <String>{};
    final salida = <Libro>[];
    for (final d in docs) {
      final titulo = _normalizar((d['title'] as String?) ?? '');
      if (titulo.isEmpty) continue;

      for (final entrada in grupos.entries) {
        if (!entrada.value.contains(d)) continue;
        if (!vistos.add(entrada.key)) break;
        salida.add(Libro.desdeOpenLibrary(_mejorDe(entrada.value)));
        break;
      }
      // Un tope: una lista de cincuenta resultados no se lee, se
      // abandona. Si lo que buscabas no está en los primeros quince, el
      // problema es la búsqueda, no la cantidad.
      if (salida.length >= maximo) break;
    }
    return salida;
  }

  /// De un grupo de fichas del mismo libro, la más completa.
  ///
  /// Puntúa lo que sirve para reconocerlo: la tapa primero, porque una
  /// ficha sin tapa se ve rota; después el autor, la editorial y el año.
  /// La cantidad de ediciones desempata: la ficha que junta cincuenta
  /// ediciones es la que Open Library considera principal.
  static Map<String, dynamic> _mejorDe(List<Map<String, dynamic>> grupo) {
    int puntos(Map<String, dynamic> d) {
      var p = 0;
      if (d['cover_i'] != null) p += 40;
      if (_apellido(d).isNotEmpty) p += 20;
      if ((d['publisher'] as List?)?.isNotEmpty ?? false) p += 6;
      if (d['first_publish_year'] != null) p += 4;
      if (d['number_of_pages_median'] != null) p += 3;
      p += ((d['edition_count'] as int?) ?? 0).clamp(0, 20);
      return p;
    }

    return grupo.reduce((a, b) => puntos(b) > puntos(a) ? b : a);
  }

  static String _apellido(Map<String, dynamic> d) {
    final autores = (d['author_name'] as List?)?.cast<String>() ?? const [];
    if (autores.isEmpty) return '';
    final palabras = _normalizar(autores.first).split(' ')
      ..removeWhere((s) => s.isEmpty);
    if (palabras.isEmpty) return '';
    // "Cassandra Clare" y "Clare, Cassandra" tienen que dar lo mismo, y
    // ordenar las palabras alcanza sin tener que adivinar cuál es cuál.
    palabras.sort();
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
    };
    var r = s.toLowerCase().trim();
    acentos.forEach((k, v) => r = r.replaceAll(k, v));
    return r
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// El libro de un código de barras.
  ///
  /// # Por qué el buscador y no el registro de la edición
  ///
  /// Open Library tiene tres formas de preguntar por un ISBN:
  /// `/api/books`, `/isbn/x.json` y el buscador con `q=isbn:`. Probamos las
  /// tres con veintitrés códigos reales y **contestaron lo mismo siempre**,
  /// así que la pregunta no era cuál sabe más sino cuál contesta mejor.
  ///
  /// El buscador gana porque devuelve la autoría y la tapa en el mismo
  /// formato que la búsqueda por título, que la app ya sabe leer. Los otros
  /// dos devuelven la ficha cruda de la edición, con la autoría como una
  /// referencia que habría que ir a buscar en otra consulta.
  ///
  /// # Lo que hay que saber antes de usarlo
  ///
  /// Falla seguido, y no por un error nuestro. Medimos cuántas ediciones
  /// con ISBN tiene Open Library de cada libro: de los clásicos en
  /// castellano tiene unas cincuenta, pero de la narrativa latinoamericana
  /// de ahora tiene **una**, y de los éxitos traducidos del inglés, dos.
  /// Escanear *Pedro Páramo* casi siempre anda; escanear *Las malas* casi
  /// nunca. Por eso la pantalla que lo usa está armada para que no
  /// encontrar nada sea una salida más y no un callejón.
  static Future<Libro?> porIsbn(String isbn) async {
    // De diez a trece antes de preguntar: las fichas viejas están cargadas
    // de las dos formas y el de trece es el que más veces está.
    final codigo = Isbn.aTrece(isbn);
    if (codigo == null) return null;

    final uri = Uri.https('openlibrary.org', '/search.json', {
      'q': 'isbn:$codigo',
      'limit': '1',
      'fields': _campos,
    });

    try {
      final respuesta = await http
          .get(uri, headers: _cabeceras)
          .timeout(const Duration(seconds: 12));

      if (respuesta.statusCode != 200) return null;

      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      final docs = (datos['docs'] as List?) ?? const [];
      if (docs.isNotEmpty) {
        return Libro.desdeOpenLibrary(docs.first as Map<String, dynamic>);
      }

      // Acá es donde Google gana de verdad. Medimos que Open Library tiene
      // una sola edición con ISBN de la narrativa latinoamericana reciente
      // —y de algunos títulos, ninguna—, así que el escáner falla
      // justamente con los libros que lee esta comunidad.
      return Google.porIsbn(codigo);
    } catch (_) {
      // Sin internet o con la consulta caída: es lo mismo que no
      // encontrarlo, y la pantalla ya sabe qué hacer con eso.
      return null;
    }
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
  static Future<Ediciones> ediciones(
    Libro obra, {
    String? idioma,
    int maximo = 40,
  }) async {
    final obraId = await _obraEnOpenLibrary(obra);
    if (obraId == null) {
      return const (confirmadas: <Libro>[], sinIdioma: <Libro>[]);
    }

    final entradas = await _entradasDeEdiciones(obraId);
    if (entradas == null) {
      return const (confirmadas: <Libro>[], sinIdioma: <Libro>[]);
    }

    return porIdioma(edicionesDe(entradas, obra, obraId), idioma);
  }

  /// Todas las ediciones de una obra, sin filtrar por idioma.
  ///
  /// Es lo que usa la pantalla de elegir edición: pide una vez y después
  /// filtra en el teléfono con [porIdioma], en vez de volver a preguntarle
  /// a Open Library cada vez que alguien toca un idioma.
  static Future<List<Edicion>> todasLasEdiciones(Libro obra) async {
    final obraId = await _obraEnOpenLibrary(obra);
    if (obraId == null) return const [];

    final entradas = await _entradasDeEdiciones(obraId);
    if (entradas == null) return const [];

    return edicionesDe(entradas, obra, obraId);
  }

  /// El id de la obra con la forma `/works/OL123W`, buscándolo si hace falta.
  ///
  /// Un libro que vino de Google o que alguien cargó a mano no tiene obra
  /// en Open Library, así que primero hay que encontrarla por título y
  /// autoría. Sin esto, justo los libros del segundo catálogo —que son los
  /// que más se escanean— eran los únicos que no podían cambiar de edición.
  static Future<String?> _obraEnOpenLibrary(Libro obra) async {
    if (obra.id.startsWith('/works/')) return obra.id;

    final enOpenLibrary = await primero(obra.titulo, obra.autor);
    if (enOpenLibrary == null || !enOpenLibrary.id.startsWith('/works/')) {
      return null;
    }
    return enOpenLibrary.id;
  }

  /// Las ediciones crudas de una obra, pedidas una sola vez.
  ///
  /// # Por qué se guardan
  ///
  /// Este es el pedido más lento de toda la app, y no por nuestra culpa:
  /// medido contra Open Library, la mediana es de 12 segundos y la cola
  /// llega a 60, con 503 de vez en cuando. **Y no depende de cuánto se le
  /// pida**: `limit=24` tarda lo mismo que `limit=200` (11,9 s contra
  /// 13,0 s), así que pedir menos no arregla nada; el trabajo es del lado
  /// del servidor, no del transporte.
  ///
  /// Lo único que está en nuestra mano es que pase una sola vez. La lista
  /// de ediciones de un libro no cambia de un día para el otro, así que se
  /// guarda una semana. Volver a la misma pantalla pasa a ser instantáneo.
  static Future<List<Map<String, dynamic>>?> _entradasDeEdiciones(
    String obraId,
  ) async {
    final guardadas = await _leerEdicionesGuardadas(obraId);
    if (guardadas != null) return guardadas;

    final uri = Uri.https('openlibrary.org', '$obraId/editions.json', {
      'limit': '200',
    });

    try {
      final respuesta = await http
          .get(uri, headers: _cabeceras)
          // 20 segundos era poco: la cola de este endpoint pasa de 45. Con
          // 40 se atrapan casi todas las respuestas lentas en vez de
          // tirarlas justo antes de que lleguen.
          .timeout(const Duration(seconds: 40));
      if (respuesta.statusCode != 200) return null;

      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      final entradas = ((datos['entries'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();

      await _guardarEdiciones(obraId, entradas);
      return entradas;
    } catch (_) {
      return null;
    }
  }

  static const _claveEdiciones = 'colibri.ediciones.v1';
  static const _duranEdiciones = Duration(days: 7);

  static Future<List<Map<String, dynamic>>?> _leerEdicionesGuardadas(
    String obraId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString('$_claveEdiciones.$obraId');
      if (crudo == null) return null;

      final guardado = jsonDecode(crudo) as Map<String, dynamic>;
      final cuando = DateTime.tryParse((guardado['cuando'] as String?) ?? '');
      if (cuando == null ||
          DateTime.now().difference(cuando) > _duranEdiciones) {
        return null;
      }

      return (guardado['entries'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _guardarEdiciones(
    String obraId,
    List<Map<String, dynamic>> entradas,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_claveEdiciones.$obraId',
        jsonEncode({
          'cuando': DateTime.now().toIso8601String(),
          'entries': entradas,
        }),
      );
    } catch (_) {
      // Si no se pudo guardar, la próxima vez se pide de nuevo y listo.
    }
  }

  /// Cada entrada cruda, convertida en un libro con sus idiomas al lado.
  ///
  /// Los idiomas viajan aparte del [Libro] porque un libro no tiene idioma
  /// —tiene el de su edición— y agregarle un campo que solo usa esta
  /// pantalla sería ensuciar el modelo entero por una lista.
  static List<Edicion> edicionesDe(
    List<Map<String, dynamic>> entradas,
    Libro obra,
    String obraId,
  ) {
    final salida = <Edicion>[];

    for (final e in entradas) {
      final idiomas = ((e['languages'] as List?) ?? const [])
          .map((l) => ((l as Map)['key'] as String?) ?? '')
          .map((k) => k.split('/').last)
          .toList();

      final tapas = (e['covers'] as List?)?.whereType<int>().toList();
      final editoriales = (e['publishers'] as List?)?.cast<String>();

      salida.add((
        libro: Libro(
          id: (e['key'] as String?) ?? '$obraId-${salida.length}',
          titulo: (e['title'] as String?) ?? obra.titulo,
          autor: obra.autor,
          tapaId: (tapas == null || tapas.isEmpty) ? null : tapas.first,
          editorial: (editoriales == null || editoriales.isEmpty)
              ? null
              : editoriales.first,
          anio: _anio(e['publish_date'] as String?),
          paginas: e['number_of_pages'] as int?,
        ),
        idiomas: idiomas,
      ));
    }

    return salida;
  }

  /// Parte las ediciones en las de ese idioma y las que no lo dicen.
  ///
  /// # Por qué esto es una función y no otra consulta
  ///
  /// Antes, tocar un idioma volvía a pedirle las 200 ediciones a Open
  /// Library: otros 12 a 60 segundos, para filtrar datos que la pantalla
  /// ya tenía en la mano. Filtrar no necesita internet —es mirar una lista
  /// que ya está— y ahora tocar «Español» es instantáneo.
  ///
  /// # Las que no dicen el idioma
  ///
  /// Open Library muchas veces no lo anota. No es un caso raro: de las 200
  /// ediciones de Harry Potter, **78 no lo tienen**, y la primera de esa
  /// lista es «Harry Potter y la piedra filosofal» de Salamandra.
  /// Filtrando por español, esa quedaba afuera.
  ///
  /// No se adivina por el título: «Pedra Filosofal» es portugués y
  /// «kamień filozoficzny» es polaco, y equivocarse sería peor que no
  /// saber. Se devuelven aparte y la pantalla avisa que el catálogo no lo
  /// dice.
  static Ediciones porIdioma(List<Edicion> todas, String? idioma) {
    if (idioma == null) {
      return (
        confirmadas: [for (final e in todas) e.libro],
        sinIdioma: const <Libro>[],
      );
    }

    final confirmadas = <Libro>[];
    final sinIdioma = <Libro>[];

    for (final e in todas) {
      if (e.idiomas.isEmpty) {
        sinIdioma.add(e.libro);
      } else if (e.idiomas.contains(idioma)) {
        confirmadas.add(e.libro);
      }
    }

    // El orden y las repetidas los resuelve la pantalla, en paraMirar:
    // son decisiones de cómo se mira, no de qué hay.
    return (confirmadas: confirmadas, sinIdioma: sinIdioma);
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
  /// La tapa de un libro, venga del catálogo que venga.
  ///
  /// Google entrega la dirección entera y Open Library un número con el
  /// que hay que armarla. Todo lo que dibuja tapas pregunta por acá y no
  /// tiene que enterarse de la diferencia.
  static String? tapaDe(Libro libro, {String tamano = 'M'}) =>
      libro.tapaUrl ?? urlTapa(libro.tapaId, tamano: tamano);

  static String? urlTapa(int? tapaId, {String tamano = 'M'}) {
    if (tapaId == null) return null;
    return 'https://covers.openlibrary.org/b/id/$tapaId-$tamano.jpg?default=false';
  }
}
