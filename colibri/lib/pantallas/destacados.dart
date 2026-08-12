import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../mazo.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'ficha.dart';

/// Descubrir: libros al azar para mirar antes de escribir nada.
///
/// # El problema que resuelve
///
/// Explorar sin cuenta arrancaba en una caja de texto vacía: para ver un
/// libro había que saber primero cuál buscar. Eso es al revés de cómo se
/// descubre algo para leer, que es mirando y no tipeando.
///
/// # Por qué "al azar" y no "recomendados"
///
/// La palabra importa. "Recomendado" dice que la app sabe algo de tus
/// gustos, y no sabe nada: no hay cuenta todavía, y aunque la hubiera, no
/// existe ningún motor que mire qué leyó cada una para sugerirle algo a
/// otra. Llamar "recomendado" a un sorteo sería la clase de mentira que
/// se nota apenas alguien recibe dos veces la misma sugerencia sin haber
/// hecho nada que la explique.
///
/// Lo que sí hay es un mazo curado —de acá abajo— del que se reparten
/// unos pocos cada vez, así que se ve distinto en cada visita sin
/// fingir saber nada de quien mira.
///
/// # Por qué son libros reales y no inventados
///
/// Las tapas y los datos salen de Open Library, igual que cualquier
/// búsqueda. Lo único curado es la lista de qué preguntarle; la respuesta
/// es la real. El mazo mezcla narrativa latinoamericana —los diez con los
/// que se midió que el catálogo encuentra bien buscando por título— con
/// las sagas que ya cubren las insignias: son las dos comunidades que la
/// propia app dice que existen acá.
///
/// # Las reseñas de muestra
///
/// Son las mismas tres que ya se usan en la ficha de cualquier libro
/// mientras no haya servidor de comunidad de verdad, con la misma
/// etiqueta. Se repiten acá a propósito y no se inventan otras: que
/// parecieran distintas sugeriría que hay más contenido real del que hay.
class BibliotecaDestacada extends StatefulWidget {
  /// Solo el carrusel, sin las reseñas de muestra.
  ///
  /// # Por qué existe este modo
  ///
  /// El bloque entero mide **1099 píxeles**: el rótulo, el texto, el
  /// carrusel, el botón, y después las reseñas de muestra. Medido en un
  /// iPhone 15 Pro —852 px de alto— puesto arriba del estante, el primer
  /// libro propio caía en y=1286: había que bajar una pantalla y media
  /// para ver algo tuyo.
  ///
  /// En la pantalla de explorar el bloque completo está bien, porque ahí
  /// no hay nada tuyo que tapar y las reseñas de muestra explican a dónde
  /// va la app. Arriba de tu biblioteca, no: ahí va solo el carrusel.
  final bool compacta;

  const BibliotecaDestacada({super.key, this.compacta = false});

  @override
  State<BibliotecaDestacada> createState() => _BibliotecaDestacadaState();
}

class _BibliotecaDestacadaState extends State<BibliotecaDestacada> {
  /// Uno por título, no una lista entera: así un libro que ya se buscó
  /// alguna vez no se vuelve a pedir, se haya mostrado esta vez o no.
  static const _cache = 'colibri.descubrir.cache.v1';

  /// Cuántos por tanda, y cuántas tandas como mucho.
  ///
  /// Cinco entran en una fila que se desliza sin que haya que buscar
  /// nada, y veinte es donde deja de ser un descubrimiento y pasa a ser
  /// una lista: si mirando veinte no encontraste nada, lo que falta no
  /// son más tarjetas.
  static const _porTanda = 5;
  static const _tope = 20;

  /// Las categorías, elegidas midiendo y no a ojo.
  ///
  /// Probé dieciocho y las amplias no sirven: «Poesía» devuelve *Robinson
  /// Crusoe*, «Manga» devuelve *La letra escarlata*. Ese endpoint ordena
  /// por peso del catálogo y lo más pesado son los libros de hace cien
  /// años. Las que quedaron son las específicas —justo las que había
  /// descartado por tener catálogos chicos— porque son las que devuelven
  /// los libros que alguien está leyendo hoy. Ver [Api.porCategoria].
  static const _categorias = <(String, String)>[
    ('Romantasy', 'romantasy'),
    ('Enemies to lovers', 'enemies_to_lovers'),
    ('Dark romance', 'dark_romance'),
    ('Fantasía épica', 'epic_fantasy'),
    ('Realismo mágico', 'magic_realism'),
    ('Latinoamericana', 'spanish_american_literature'),
    ('Argentina', 'literatura_argentina'),
    ('Fanfiction', 'fan_fiction'),
  ];

  final _random = Random();

  /// Los que ya se repartieron, en orden: el carrusel los muestra todos
  /// y cada tanda nueva se suma al final.
  final List<Libro> _libros = [];
  final Set<String> _yaRepartidos = {};

  /// La categoría elegida, o null para el mazo al azar.
  String? _categoria;

  bool _cargando = true;

  /// En el mazo hay tope porque es finito; en una categoría, el tope lo
  /// pone el catálogo.
  bool get _hayMas =>
      _categoria == null &&
      _libros.length < _tope &&
      _yaRepartidos.length < mazoDeDescubrir.length;

  @override
  void initState() {
    super.initState();
    _repartir();
  }

  /// Reparte [_porTanda] libros del mazo. **Sin red.**
  ///
  /// Antes, cada libro del mazo era una búsqueda a Open Library. Salían en
  /// paralelo, pero la más lenta manda: medido, entre 2 y 10 segundos antes
  /// de ver la primera tapa, y otras cinco búsquedas en cada «mostrame
  /// otros cinco». Y la respuesta era siempre la misma, porque los títulos
  /// del mazo son fijos.
  ///
  /// Ahora se resuelven al compilar, con `herramientas/mazo.py`, y esto no
  /// pide nada: lo único que baja son las imágenes de las tapas. Por eso es
  /// sincrónico —no hay ningún await— y aparece de una.
  void _repartir() {
    final disponibles = <int>[
      for (var i = 0; i < mazoDeDescubrir.length; i++)
        if (!_yaRepartidos.contains(mazoDeDescubrir[i].$1)) i,
    ]..shuffle(_random);

    final tanda = disponibles.take(_porTanda);
    setState(() {
      for (final i in tanda) {
        _yaRepartidos.add(mazoDeDescubrir[i].$1);
        _libros.add(_libroDe(mazoDeDescubrir[i]));
      }
      _cargando = false;
    });
  }

  /// Cambia de categoría, o vuelve al mazo si [etiqueta] es null.
  ///
  /// # Lo horneado primero, el catálogo después
  ///
  /// Tocar una ficha pedía la lista a Open Library y había que esperar:
  /// medido, unos 3 segundos, hasta 10 en la más lenta. Ahora las ocho
  /// categorías vienen resueltas en la app —ver `herramientas/mazo.py`—
  /// así que la fila aparece al instante, sin red.
  ///
  /// Y **igual se pregunta**, de fondo, sin hacer esperar a nadie. Lo que
  /// llegue nuevo se suma al final. Lo horneado es el piso, no el techo:
  /// el catálogo crece y una app compilada en agosto no tiene por qué
  /// mostrar para siempre lo de agosto.
  ///
  /// # Por qué se suma y no se reemplaza
  ///
  /// Porque reemplazar reordena la fila mientras alguien la está mirando,
  /// y una tapa que se mueve sola debajo del dedo es peor que una tapa de
  /// menos. Sumando, lo que ya se veía se queda donde estaba.
  ///
  /// # Lo que ya se había repartido se descarta
  ///
  /// A propósito: el mazo y una categoría son dos listas distintas, y
  /// mezclar «Romantasy» con el sorteo dejaría una fila donde no se
  /// entiende qué se está mirando.
  Future<void> _elegirCategoria(String? etiqueta) async {
    if (etiqueta == _categoria) return;

    final horneados = etiqueta == null
        ? const <(String, String, String?, int?, int?, int?)>[]
        : (categoriasDeDescubrir[etiqueta] ?? const []);

    setState(() {
      _categoria = etiqueta;
      _libros.clear();
      _yaRepartidos.clear();
      for (final l in horneados) {
        _libros.add(_libroDe(l));
        _yaRepartidos.add(l.$1);
      }
      // Solo se muestra la rueda si no hay nada horneado que mostrar.
      _cargando = etiqueta != null && horneados.isEmpty;
    });

    if (etiqueta == null) {
      _repartir(); // el mazo, instantáneo
      return;
    }

    // De acá para abajo ya no hay nadie esperando: la fila está en
    // pantalla. Primero lo guardado de la semana, y si no hay, el
    // catálogo.
    final frescos =
        await _leerCategoria(etiqueta) ?? await Api.porCategoria(etiqueta);

    // Si mientras tanto se tocó otra ficha, esta respuesta ya no sirve:
    // pisarla sería mostrar libros de la categoría anterior.
    if (!mounted || _categoria != etiqueta) return;

    if (frescos.isEmpty) {
      setState(() => _cargando = false);
      return;
    }

    await _guardarCategoria(etiqueta, frescos);
    if (!mounted || _categoria != etiqueta) return;

    setState(() {
      for (final libro in frescos) {
        if (_yaRepartidos.add(libro.titulo)) _libros.add(libro);
      }
      _cargando = false;
    });
  }

  /// Una entrada horneada, como [Libro].
  Libro _libroDe((String, String, String?, int?, int?, int?) l) {
    final (titulo, autor, clave, tapa, anio, paginas) = l;
    return Libro(
      id: clave ?? titulo,
      titulo: titulo,
      autor: autor,
      tapaId: tapa,
      anio: anio,
      paginas: paginas,
    );
  }

  // ---------- Lo que se guarda de las categorías ----------
  //
  // Una categoría sí necesita red —el mazo no— y ese pedido tarda unos
  // tres segundos. Las categorías no cambian de un día para el otro, así
  // que se guardan una semana y volver a tocarlas es instantáneo.

  static const _duran = Duration(days: 7);

  Future<List<Libro>?> _leerCategoria(String etiqueta) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString('$_cache.$etiqueta');
      if (crudo == null) return null;

      final g = jsonDecode(crudo) as Map<String, dynamic>;
      final cuando = DateTime.tryParse((g['cuando'] as String?) ?? '');
      if (cuando == null || DateTime.now().difference(cuando) > _duran) {
        return null;
      }
      return [
        for (final l in (g['libros'] as List))
          Libro.desdeJson((l as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return null;
    }
  }

  String _nombreDe(String etiqueta) => _categorias
      .firstWhere((c) => c.$2 == etiqueta, orElse: () => (etiqueta, etiqueta))
      .$1;

  void _abrir(Libro libro) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PantallaFicha(libro)));
  }

  Future<void> _guardarCategoria(String etiqueta, List<Libro> libros) async {
    if (libros.isEmpty) return; // no vale la pena recordar un vacío
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cache.$etiqueta',
        jsonEncode({
          'cuando': DateTime.now().toIso8601String(),
          'libros': [for (final l in libros) l.aJson()],
        }),
      );
    } catch (_) {
      // Si no se pudo guardar, la próxima vez se pide de nuevo.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Rotulo('Descubrir'),
        const SizedBox(height: 2),
        Text(
          _categoria != null
              // Nombra la categoría en vez de decir «al azar», que sería
              // falso: acá los libros salen de una etiqueta del catálogo.
              ? 'Lo que el catálogo tiene etiquetado como '
                    '${_nombreDe(_categoria!).toLowerCase()}.'
              : widget.compacta
              ? 'Al azar, para cuando no sepas qué leer.'
              : 'Al azar, de un mazo curado. Todavía no sabemos qué te gusta '
                    'a vos: eso empieza cuando armes tu perfil.',
          style: Tipo.meta,
        ),
        const SizedBox(height: 12),

        // Las categorías, antes del carrusel: primero se elige qué mirar.
        _Categorias(
          categorias: _categorias,
          activa: _categoria,
          alElegir: _elegirCategoria,
        ),
        const SizedBox(height: 14),

        _Carrusel(libros: _libros, cargando: _cargando, alTocar: _abrir),

        // Una categoría puede venir vacía: son etiquetas de Open Library y
        // el catálogo cambia. Decirlo es mejor que dejar una fila en blanco
        // que parece que algo se rompió.
        if (!_cargando && _libros.isEmpty && _categoria != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'El catálogo no tiene nada en esta categoría ahora mismo. '
              'Probá otra.',
              style: Tipo.meta,
            ),
          ),

        if (_hayMas) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _cargando ? null : _repartir,
              style: TextButton.styleFrom(
                foregroundColor: Paleta.lila,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                _cargando ? 'Buscando…' : 'Mostrame otros cinco',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ],

        if (!widget.compacta) ...[
          const SizedBox(height: 28),
          const Rotulo('Reseñas de muestra'),
          const SizedBox(height: 6),
          Text(
            'Todavía no hay comunidad de verdad: esto es cómo se van a ver '
            'las reseñas cuando la haya.',
            style: Tipo.meta,
          ),
          const SizedBox(height: 12),
          const _ReseniasDeMuestra(),
        ],
      ],
    );
  }
}

/// La fila de categorías, que se desliza.
///
/// # Por qué una fila que se desliza y no un menú
///
/// Un menú esconde las opciones detrás de un toque, y acá las opciones
/// **son** el contenido: leer «Romantasy», «Enemies to lovers», «Dark
/// romance» ya es parte de descubrir algo. Con ocho categorías en una fila
/// se ven cuatro y se adivina que hay más, que es justo lo que hace que
/// alguien arrastre.
///
/// «Al azar» va primera y es la que está puesta al entrar: es la única que
/// no necesita internet, porque el mazo viene horneado en la app.
class _Categorias extends StatelessWidget {
  final List<(String, String)> categorias;
  final String? activa;
  final ValueChanged<String?> alElegir;

  const _Categorias({
    required this.categorias,
    required this.activa,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        // Sin esto, la primera ficha arranca pegada al borde de la
        // pantalla y parece cortada.
        padding: EdgeInsets.zero,
        children: [
          _Ficha(
            'Al azar',
            puesta: activa == null,
            alTocar: () => alElegir(null),
          ),
          for (final (nombre, etiqueta) in categorias)
            _Ficha(
              nombre,
              puesta: activa == etiqueta,
              alTocar: () => alElegir(etiqueta),
            ),
        ],
      ),
    );
  }
}

class _Ficha extends StatelessWidget {
  final String texto;
  final bool puesta;
  final VoidCallback alTocar;

  const _Ficha(this.texto, {required this.puesta, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: puesta ? Paleta.lila : null,
            border: Border.all(color: puesta ? Paleta.lila : Paleta.linea),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12.5,
              color: puesta ? Paleta.noche : Paleta.luz,
              fontWeight: puesta ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// La fila que se desliza, con la tapa, el título y las estrellas.
///
/// Horizontal y no una grilla: una grilla de veinte crece hacia abajo y
/// empuja las reseñas fuera de la pantalla. Deslizando al costado, las
/// veinte entran sin mover nada de lo que está debajo.
class _Carrusel extends StatelessWidget {
  final List<Libro> libros;
  final bool cargando;
  final ValueChanged<Libro> alTocar;

  const _Carrusel({
    required this.libros,
    required this.cargando,
    required this.alTocar,
  });

  /// Alto fijo, calculado y no adivinado: la tapa mide 1,5 veces su
  /// ancho, y debajo van dos renglones de título y una fila de estrellas.
  /// Sin un alto fijo, una lista horizontal no sabe cuánto ocupar.
  static const _ancho = 104.0;
  static const _alto = _ancho * 1.5 + 62;

  @override
  Widget build(BuildContext context) {
    if (libros.isEmpty && cargando) {
      return const SizedBox(
        height: _alto,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Paleta.lila),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: _alto,
      child: ListView.separated(
        // Una llave para poder apuntarle desde las pruebas: ahora hay dos
        // listas horizontales en la pantalla —las categorías y ésta— y
        // «la primera» ya no dice cuál es.
        key: const Key('carrusel'),
        scrollDirection: Axis.horizontal,
        // +1 cuando está buscando más: la rueda va al final de la fila,
        // donde van a aparecer los que vienen, y no encima de los que ya
        // se están mirando.
        itemCount: libros.length + (cargando ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          if (i >= libros.length) {
            return const SizedBox(
              width: _ancho,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Paleta.lila),
                  ),
                ),
              ),
            );
          }
          return _Tarjeta(libros[i], alTocar: () => alTocar(libros[i]));
        },
      ),
    );
  }
}

/// Una tarjeta: tapa, título debajo y estrellas.
class _Tarjeta extends StatelessWidget {
  final Libro libro;
  final VoidCallback alTocar;

  const _Tarjeta(this.libro, {required this.alTocar});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      child: SizedBox(
        width: _Carrusel._ancho,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tapa(libro, ancho: _Carrusel._ancho),
            const SizedBox(height: 8),
            Text(
              libro.titulo,
              style: Tipo.meta.copyWith(color: Paleta.luz, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Las estrellas de la comunidad, todavía de muestra. Sin
            // puntaje real no se inventa un número por libro: se muestra
            // la misma marca en todos, que es lo que ya hace la ficha
            // con sus reseñas de ejemplo.
            Estrellas(4, tamano: 11),
          ],
        ),
      ),
    );
  }
}

/// Las mismas tres reseñas que ya aparecen en la ficha de cualquier
/// libro. Ver el porqué en el comentario de arriba de [BibliotecaDestacada].
class _ReseniasDeMuestra extends StatelessWidget {
  const _ReseniasDeMuestra();

  static const _textos = [
    (
      'Empieza como una novela de terror y termina siendo sobre un padre y '
          'un hijo. Aguantá las primeras cien páginas, que después no la '
          'soltás.',
      'Caro Vidal',
      5,
    ),
    (
      'La leí en un viaje de tres horas y me quedé sin viaje. De las que se '
          'terminan de un tirón y después no podés empezar otra en varios '
          'días.',
      'Juli Peralta',
      5,
    ),
    (
      'No es un libro para todo el mundo, pero si es para vos, lo vas a '
          'saber en la primera página.',
      'Mara Giménez',
      4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (texto, quien, estrellas) in _textos)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Paleta.nocheAlta,
                border: Border.all(color: Paleta.linea),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"$texto"', style: Tipo.lectura.copyWith(fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '$quien  ',
                        style: Tipo.meta.copyWith(fontSize: 11.5),
                      ),
                      Estrellas(estrellas, tamano: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
