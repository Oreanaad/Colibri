import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../archivo/guardar_imagen.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// La reseña de un libro, convertida en una imagen para compartir.
///
/// # De dónde sale esto
///
/// De las plantillas que circulan entre lectoras: una hoja con la tapa,
/// las fechas, las estrellas y el texto escrito a mano. La gente ya las
/// llena, las fotografía y las sube. Lo que hacen esas plantillas es
/// convertir «leí un libro» en algo que se puede mostrar.
///
/// # Qué tiene esta que no tienen ésas
///
/// Las cuatro escalas. Una plantilla de papel tiene estrellas y, si es de
/// las buenas, gotas y llamitas dibujadas. Colibrí ya guarda las cuatro
/// —puntaje, lágrimas, romance y picante— porque miden cosas distintas: un
/// libro puede ser flojo y hacerte llorar igual. Acá salen las cuatro, y
/// **solo las que puntuaste**: una fila de cinco estrellas vacías dice
/// «cero» y lo que pasa es que no dijiste nada.
///
/// # Lo que nunca sale
///
/// Tus notas privadas. No es que se filtren y se saquen: es que esta placa
/// nunca las mira. Ver `PantallaNota`.
///
/// Y de la reseña sale lo que escribiste, sin el aviso de spoilers, porque
/// una imagen que alguien comparte en sus historias no tiene dónde poner
/// una advertencia que se pueda tocar. Si tu reseña tiene spoilers, la
/// pantalla te lo dice antes de compartir.
enum FondoDeResena { noche, papel, oro }

extension on FondoDeResena {
  String get nombre => switch (this) {
    FondoDeResena.noche => 'Noche',
    FondoDeResena.papel => 'Papel',
    FondoDeResena.oro => 'Oro',
  };

  /// El fondo de la hoja.
  Color get fondo => switch (this) {
    FondoDeResena.noche => Paleta.noche,
    FondoDeResena.papel => const Color(0xFFF6F1EC),
    FondoDeResena.oro => const Color(0xFF1A1408),
  };

  /// La tarjeta de adentro, donde va el texto.
  Color get tarjeta => switch (this) {
    FondoDeResena.noche => Paleta.nocheAlta,
    FondoDeResena.papel => Colors.white,
    FondoDeResena.oro => const Color(0xFF241C0D),
  };

  Color get texto => switch (this) {
    FondoDeResena.papel => const Color(0xFF2A2333),
    _ => Paleta.luz,
  };

  Color get tenue => switch (this) {
    FondoDeResena.papel => const Color(0xFF8A8194),
    _ => Paleta.bruma,
  };

  /// El color con el que se marca lo importante: el rótulo, la autoría,
  /// tus estantes y la comilla. Uno solo por placa, para que marcar algo
  /// siga significando algo.
  Color get acento => switch (this) {
    FondoDeResena.papel => const Color(0xFF8A6D3B),
    _ => Paleta.oro,
  };

  /// El color de los lomos del librero del pie.
  Color get lomos => switch (this) {
    FondoDeResena.papel => const Color(0xFF6B5B4A),
    _ => Paleta.lila,
  };

  Color get linea => switch (this) {
    FondoDeResena.papel => const Color(0xFFE2DAD2),
    FondoDeResena.oro => const Color(0xFF4A3D1E),
    _ => Paleta.linea,
  };
}

/// Los dos formatos que usa la gente de verdad.
enum FormatoDeResena { historia, cuadrado }

extension on FormatoDeResena {
  String get nombre =>
      this == FormatoDeResena.historia ? 'Historia' : 'Cuadrado';
  double get proporcion => this == FormatoDeResena.historia ? 9 / 16 : 1.0;
}

class PantallaCompartirResena extends StatefulWidget {
  final Libro libro;
  const PantallaCompartirResena(this.libro, {super.key});

  @override
  State<PantallaCompartirResena> createState() =>
      _PantallaCompartirResenaState();
}

class _PantallaCompartirResenaState extends State<PantallaCompartirResena> {
  /// La llave que da acceso al widget dibujado para poder fotografiarlo.
  final _placa = GlobalKey();

  FondoDeResena _fondo = FondoDeResena.noche;
  FormatoDeResena _formato = FormatoDeResena.historia;
  bool _trabajando = false;

  /// Saca una «foto» del widget tal como está en pantalla.
  ///
  /// pixelRatio 3 es lo que hace que salga nítida: se dibuja al triple del
  /// tamaño que ocupa en el teléfono. Sin eso se ve borrosa apenas alguien
  /// la abre en grande.
  Future<Uint8List?> _dibujar() async {
    final limite =
        _placa.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (limite == null) return null;

    final imagen = await limite.toImage(pixelRatio: 3);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    return datos?.buffer.asUint8List();
  }

  String get _nombreArchivo {
    final t = widget.libro.titulo
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñ ]'), '')
        .replaceAll(' ', '-');
    return 'resena-${t.length > 40 ? t.substring(0, 40) : t}.png';
  }

  Future<void> _compartir() async {
    setState(() => _trabajando = true);
    try {
      final bytes = await _dibujar();
      if (bytes == null) throw Exception('no se pudo dibujar la placa');

      await guardarImagen(
        bytes,
        nombre: _nombreArchivo,
        texto: '${widget.libro.titulo} — ${widget.libro.autor}',
      );

      if (mounted && kIsWeb) {
        mostrarAviso(context, 'Imagen guardada en Descargas');
      }
    } catch (_) {
      if (mounted) {
        mostrarAviso(context, 'No se pudo guardar la imagen. Probá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: const Text(
          'Compartir mi reseña',
          style: TextStyle(color: Paleta.luz, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: ConstrainedBox(
                    // Sin techo, en un monitor la placa se dibuja enorme y
                    // la vista previa deja de parecerse a lo que sale.
                    constraints: const BoxConstraints(
                      maxWidth: 380,
                      maxHeight: 620,
                    ),
                    child: AspectRatio(
                      aspectRatio: _formato.proporcion,
                      child: RepaintBoundary(
                        key: _placa,
                        child: PlacaDeResena(
                          libro: widget.libro,
                          fondo: _fondo,
                          formato: _formato,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // El aviso de spoilers, si corresponde.
            //
            // Una imagen no tiene dónde poner una advertencia que se pueda
            // tocar: quien la ve en una historia la lee entera de una. Si
            // marcaste que tu reseña tiene spoilers, esto es lo único que
            // se puede hacer al respecto, y se hace antes y no después.
            if (widget.libro.resenaConSpoilers)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Columna(
                  ancho: 420,
                  hijo: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Paleta.oro,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Marcaste que tu reseña tiene spoilers. En una '
                          'imagen no hay forma de taparlos: quien la vea la '
                          'lee entera.',
                          style: Tipo.meta.copyWith(
                            fontSize: 11.5,
                            color: Paleta.oroTexto,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Columna(
                ancho: 420,
                hijo: Column(
                  children: [
                    _Opciones<FondoDeResena>(
                      valores: FondoDeResena.values,
                      activo: _fondo,
                      nombre: (f) => f.nombre,
                      alElegir: (f) => setState(() => _fondo = f),
                    ),
                    const SizedBox(height: 8),
                    _Opciones<FormatoDeResena>(
                      valores: FormatoDeResena.values,
                      activo: _formato,
                      nombre: (f) => f.nombre,
                      alElegir: (f) => setState(() => _formato = f),
                    ),
                    const SizedBox(height: 14),
                    _trabajando
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Paleta.lila,
                                ),
                              ),
                            ),
                          )
                        : BotonLleno(
                            kIsWeb ? 'Descargar la imagen' : 'Compartir',
                            alTocar: _compartir,
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El librero de fondo de la placa.
///
/// # Por qué está acá y no se reusa el de la app
///
/// El de `fondo.dart` dibuja lomos **en los márgenes** de una pantalla
/// ancha, y se apaga en un teléfono porque no hay margen. Una placa no
/// tiene márgenes: es una hoja. Así que la misma idea, dibujada distinto —
/// una fila de lomos al pie, como el estante sobre el que se apoya todo lo
/// demás.
///
/// Mismas reglas que el de la app, y por las mismas razones: un solo
/// violeta con distinta luz en cada lomo —el color en esta placa es de la
/// tapa y de las escalas, no del adorno— y números repetibles en vez de
/// azar, para que la misma reseña dé siempre la misma imagen.
class _Librero extends CustomPainter {
  final Color color;
  const _Librero(this.color);

  static double _mezcla(int i, int sal) =>
      ((i * 9301 + sal * 49297 + 233) % 233280) / 233280;

  @override
  void paint(Canvas lienzo, Size medida) {
    final piso = medida.height;
    var x = 0.0;
    var i = 0;

    while (x < medida.width) {
      final ancho = medida.height * (0.16 + _mezcla(i, 7) * 0.22);
      final alto = medida.height * (0.42 + _mezcla(i, 13) * 0.58);
      final tono = _mezcla(i, 23);

      lienzo.drawRect(
        Rect.fromLTWH(x, piso - alto, ancho, alto),
        Paint()..color = color.withValues(alpha: 0.14 + tono * 0.16),
      );

      // La franja del título: es lo que hace que se lea como un lomo y no
      // como una barra de color.
      if (ancho > medida.height * 0.2 && alto > medida.height * 0.6) {
        lienzo.drawRect(
          Rect.fromLTWH(
            x + ancho * 0.24,
            piso - alto * 0.74,
            ancho * 0.52,
            medida.height * 0.02,
          ),
          Paint()..color = color.withValues(alpha: 0.22),
        );
      }

      x += ancho + medida.height * 0.05;
      i++;
    }
  }

  @override
  bool shouldRepaint(_Librero viejo) => viejo.color != color;
}

/// La placa en sí.
///
/// Es un widget aparte porque es lo único que se fotografía: todo lo que
/// quede adentro sale en la imagen, y todo lo que quede afuera, no.
///
/// # Cómo está ordenada, y por qué
///
/// De arriba abajo va de lo que identifica al libro a lo que dijiste vos:
/// la tapa y la autoría primero, después las escalas, después tu reseña, y
/// al final cómo lo guardaste. Es el mismo orden en que alguien mira una
/// plantilla de papel, y el mismo en que decide si le interesa.
///
/// **Las escalas van con su nombre al lado.** En la placa anterior eran
/// cuatro filas de dibujitos sueltos, y ahí una gota azul no dice
/// «lágrimas»: hay que saberlo de antes. Con el nombre escrito, la imagen
/// se entiende también para alguien que nunca vio Colibrí, que es
/// exactamente la persona que la va a ver en las historias de otra.
class PlacaDeResena extends StatelessWidget {
  final Libro libro;
  final FondoDeResena fondo;
  final FormatoDeResena formato;

  const PlacaDeResena({
    super.key,
    required this.libro,
    this.fondo = FondoDeResena.noche,
    this.formato = FormatoDeResena.historia,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        // Todo se mide contra el ancho y no en píxeles fijos: la misma
        // placa se dibuja chica en la vista previa y al triple al
        // fotografiarla, y con medidas fijas se rompería en una de las dos.
        final u = medidas.maxWidth / 100;

        // El cuadrado tiene la mitad del alto y no entra lo mismo. Medido:
        // con el diseño de «Historia» tal cual, se desbordaba. Se achica lo
        // que se puede y se saca lo que menos se extraña.
        final apretado = medidas.maxHeight < medidas.maxWidth * 1.3;

        return Stack(
          children: [
            Positioned.fill(child: Container(color: fondo.fondo)),

            // El librero, apoyado en el borde de abajo.
            //
            // Va **debajo del pie y no detrás**: la primera versión lo
            // dibujaba alto y la firma «Colibrí» quedaba encima de los
            // lomos, ilegible. Un fondo que tapa lo que hay que leer no es
            // un fondo, es ruido. Ahora es una franja al pie y el texto
            // termina arriba de ella.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: u * 9,
              child: CustomPaint(painter: _Librero(fondo.lomos)),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                u * (apretado ? 4.5 : 6),
                u * (apretado ? 4.5 : 6),
                u * (apretado ? 4.5 : 6),
                // El alto de la franja de lomos más aire: así el pie
                // termina arriba del librero y no encima.
                u * (apretado ? 11 : 12.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Encabezado(
                    u: u,
                    fondo: fondo,
                    texto: libro.tieneResena ? 'MI RESEÑA' : 'LO QUE LEÍ',
                  ),
                  SizedBox(height: u * (apretado ? 2.5 : 4.5)),

                  _LibroYDatos(
                    libro: libro,
                    u: u,
                    fondo: fondo,
                    apretado: apretado,
                  ),

                  if (libro.tieneResena) ...[
                    SizedBox(height: u * (apretado ? 3 : 4)),
                    Expanded(
                      child: _LaResena(
                        texto: libro.resena!,
                        u: u,
                        fondo: fondo,
                        apretado: apretado,
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: u * (apretado ? 3 : 4)),
                    Expanded(
                      child: _SinResena(libro: libro, u: u, fondo: fondo),
                    ),
                  ],

                  // Las escalas, abajo y sin recuadro.
                  //
                  // Estaban en una tarjeta propia arriba, y eran tres
                  // recuadros seguidos —escalas, reseña, y la tapa que ya
                  // es un rectángulo— que hacían ver la placa como un
                  // formulario. Sueltas y en fila se leen como un pie de
                  // ficha, que es lo que son: el resumen de lo que
                  // puntuaste.
                  SizedBox(height: u * (apretado ? 3 : 4)),
                  _Escalas(
                    libro: libro,
                    u: u,
                    fondo: fondo,
                    apretado: apretado,
                  ),

                  if (!apretado)
                    _ComoLoGuarde(libro: libro, u: u, fondo: fondo),

                  SizedBox(height: u * (apretado ? 2 : 3.5)),
                  _Pie(u: u, fondo: fondo),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// El rótulo de arriba, con su línea de oro.
class _Encabezado extends StatelessWidget {
  final double u;
  final FondoDeResena fondo;
  final String texto;
  const _Encabezado({
    required this.u,
    required this.fondo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        texto,
        style: TextStyle(
          fontSize: u * 3.2,
          letterSpacing: u * 0.6,
          fontWeight: FontWeight.w600,
          color: fondo.acento,
        ),
      ),
      SizedBox(width: u * 3),
      // Una línea fina que corre hasta el borde. Es lo único decorativo de
      // la placa, y alcanza: le da un arriba a la hoja sin competir con la
      // tapa, que es lo que tiene que mirarse primero.
      Expanded(
        child: Container(height: u * 0.18, color: fondo.acento),
      ),
    ],
  );
}

/// La tapa, el título, la autoría y los datos del ejemplar.
class _LibroYDatos extends StatelessWidget {
  final Libro libro;
  final double u;
  final FondoDeResena fondo;
  final bool apretado;

  const _LibroYDatos({
    required this.libro,
    required this.u,
    required this.fondo,
    required this.apretado,
  });

  @override
  Widget build(BuildContext context) {
    // Año y páginas en un solo renglón, con un punto medio entre ellos.
    // Separados serían dos renglones para dos números.
    final ficha = <String>[
      if (libro.anio != null) '${libro.anio}',
      if (libro.paginas != null) '${libro.paginas} páginas',
    ].join('  ·  ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tapa(libro, ancho: u * (apretado ? 20 : 27)),
        SizedBox(width: u * 4.5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                libro.titulo,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: u * (apretado ? 4.6 : 5.6),
                  height: 1.12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -u * 0.03,
                  color: fondo.texto,
                ),
              ),
              SizedBox(height: u * 1.6),

              // La autoría en el color de acento: es el otro nombre propio
              // de la placa y merece no perderse en el gris de los datos.
              Text(
                libro.autor,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: u * 3.6,
                  height: 1.2,
                  color: fondo.acento,
                ),
              ),

              if (ficha.isNotEmpty) ...[
                SizedBox(height: u * 1.6),
                Text(
                  ficha,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: u * 3, color: fondo.tenue),
                ),
              ],

              // Las fechas se van en el cuadrado, junto con los chips: en
              // la mitad del alto no entra todo, y entre achicar la letra
              // hasta que no se lea y sacar lo menos mirado, se saca. El
              // ejemplar y el veredicto se quedan siempre.
              if (!apretado &&
                  (libro.empezado != null || libro.terminado != null)) ...[
                SizedBox(height: u * 2.2),
                _Fechas(libro: libro, u: u, fondo: fondo),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Cuándo lo empezaste y cuándo lo terminaste, con la flecha en el medio.
///
/// Con flecha y no con dos rótulos: «24 dic → 25 mar» se lee de un vistazo
/// y ocupa un renglón, donde «EMPECÉ / TERMINÉ» ocupaba cuatro.
class _Fechas extends StatelessWidget {
  final Libro libro;
  final double u;
  final FondoDeResena fondo;

  const _Fechas({required this.libro, required this.u, required this.fondo});

  @override
  Widget build(BuildContext context) {
    final dias = libro.diasDeLectura;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: u * 2.8,
              color: fondo.tenue,
            ),
            SizedBox(width: u * 1.6),
            Flexible(
              child: Text(
                [
                  if (libro.empezado != null) fechaCorta(libro.empezado!),
                  if (libro.terminado != null) fechaCorta(libro.terminado!),
                ].join('  →  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: u * 2.9, color: fondo.texto),
              ),
            ),
          ],
        ),
        if (dias != null) ...[
          SizedBox(height: u * 1),
          Text(
            dias == 1 ? 'lo leí en un día' : 'me llevó $dias días',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: u * 2.8, color: fondo.tenue),
          ),
        ],
      ],
    );
  }
}

/// Las cuatro escalas, **con su nombre al lado**.
///
/// # Por qué el nombre y no solo el dibujo
///
/// Porque una gota azul no dice «lágrimas» si no lo sabés de antes, y quien
/// va a ver esta imagen es justamente alguien que nunca abrió Colibrí. En
/// la app el dibujo solo alcanza, porque al lado está la pregunta escrita;
/// acá la imagen viaja sola.
///
/// # Y solo las que puntuaste
///
/// Una fila de cinco estrellas vacías se lee como un cero, y no es cero: es
/// que no dijiste nada. Es la misma regla que en la grilla del estante.
class _Escalas extends StatelessWidget {
  final Libro libro;
  final double u;
  final FondoDeResena fondo;
  final bool apretado;

  const _Escalas({
    required this.libro,
    required this.u,
    required this.fondo,
    required this.apretado,
  });

  @override
  Widget build(BuildContext context) {
    final puestas = <(Escala, int)>[
      if (libro.puntaje > 0) (Escala.estrellas, libro.puntaje),
      if (libro.lagrimas > 0) (Escala.lagrimas, libro.lagrimas),
      if (libro.romantico > 0) (Escala.corazones, libro.romantico),
      if (libro.picante > 0) (Escala.chiles, libro.picante),
    ];

    if (puestas.isEmpty) return const SizedBox.shrink();

    // En fila y repartidas, con el nombre debajo de cada una. Así se leen
    // de un vistazo y sin un recuadro que las encierre: son el pie de la
    // ficha, no otra sección.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (escala, valor) in puestas)
          Expanded(
            child: Column(
              children: [
                Puntuacion(escala, valor, tamano: u * (apretado ? 3.2 : 3.8)),
                SizedBox(height: u * 1.2),
                Text(
                  escala.nombre.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: u * 2.3,
                    letterSpacing: u * 0.12,
                    color: fondo.tenue,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// La reseña, en su tarjeta, con la comilla de oro.
class _LaResena extends StatelessWidget {
  final String texto;
  final double u;
  final FondoDeResena fondo;
  final bool apretado;

  const _LaResena({
    required this.texto,
    required this.u,
    required this.fondo,
    required this.apretado,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      u * (apretado ? 3.5 : 4.5),
      u * (apretado ? 2.5 : 3.5),
      u * (apretado ? 3.5 : 4.5),
      u * (apretado ? 3 : 4),
    ),
    decoration: BoxDecoration(
      color: fondo.tarjeta,
      borderRadius: BorderRadius.circular(u * 2.6),
      border: Border.all(color: fondo.linea),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La comilla como marca de que lo que sigue es una voz, no un dato.
        // Grande y tenue: se ve sin leerse.
        Text(
          '“',
          style: TextStyle(
            fontSize: u * 8,
            height: 0.9,
            fontWeight: FontWeight.w600,
            color: fondo.acento,
          ),
        ),
        Expanded(
          child: _ResenaQueEntra(
            texto: texto,
            color: fondo.texto,
            maximo: u * (apretado ? 3.6 : 4.2),
            minimo: u * 2.2,
          ),
        ),
      ],
    ),
  );
}

/// Lo que va donde iría la reseña, cuando no hay.
///
/// No es un cartel de «falta algo»: es el estado de un libro que puntuaste
/// y no comentaste, que es un estado normal y frecuente. Se muestra lo más
/// grande que hay para mostrar —el veredicto en palabras— y si no hay ni
/// eso, el título del libro respirando.
class _SinResena extends StatelessWidget {
  final Libro libro;
  final double u;
  final FondoDeResena fondo;

  const _SinResena({required this.libro, required this.u, required this.fondo});

  /// El puntaje dicho en palabras.
  ///
  /// Cinco estrellas dibujadas ya están más arriba; repetirlas en número
  /// no agrega nada. Lo que agrega es decir qué significan, que es lo que
  /// alguien pondría de puño y letra en una plantilla de papel.
  String? get _veredicto => switch (libro.puntaje) {
    5 => 'De los que no se prestan',
    4 => 'Muy bueno',
    3 => 'Me gustó',
    2 => 'Ni fu ni fa',
    1 => 'No era para mí',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final v = _veredicto;

    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: u * 5, vertical: u * 4),
      decoration: BoxDecoration(
        color: fondo.tarjeta,
        borderRadius: BorderRadius.circular(u * 2.6),
        border: Border.all(color: fondo.linea),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (v != null)
            Text(
              v,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: u * 5.4,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: fondo.texto,
              ),
            )
          else
            Text(
              libro.titulo,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: u * 4.6,
                height: 1.25,
                color: fondo.tenue,
              ),
            ),
        ],
      ),
    );
  }
}

/// Los estantes donde lo guardaste y cómo te dejó.
///
/// Los dos contestan lo mismo —qué clase de libro fue para vos— así que van
/// juntos, pero se distinguen: los estantes son tuyos y llevan borde; los
/// ánimos son de una lista común y van rellenos.
class _ComoLoGuarde extends StatelessWidget {
  final Libro libro;
  final double u;
  final FondoDeResena fondo;

  const _ComoLoGuarde({
    required this.libro,
    required this.u,
    required this.fondo,
  });

  @override
  Widget build(BuildContext context) {
    final estantes = libro.estantes.toList();
    if (estantes.isEmpty && libro.animos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: u * 3.5),
      child: Wrap(
        spacing: u * 1.8,
        runSpacing: u * 1.6,
        children: [
          for (final e in estantes)
            _Chip(texto: e, u: u, fondo: fondo, propio: true),
          for (final a in libro.animos)
            _Chip(texto: a, u: u, fondo: fondo, propio: false),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final double u;
  final FondoDeResena fondo;

  /// Un estante tuyo, con borde; o un ánimo de la lista común, relleno.
  final bool propio;

  const _Chip({
    required this.texto,
    required this.u,
    required this.fondo,
    required this.propio,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: u * 2.6, vertical: u * 1.2),
    decoration: BoxDecoration(
      color: propio ? null : fondo.tarjeta,
      border: Border.all(color: propio ? fondo.acento : fondo.linea),
      borderRadius: BorderRadius.circular(u * 4),
    ),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: u * 2.9,
        color: propio ? fondo.acento : fondo.texto,
        fontWeight: propio ? FontWeight.w500 : FontWeight.w400,
      ),
    ),
  );
}

class _Pie extends StatelessWidget {
  final double u;
  final FondoDeResena fondo;
  const _Pie({required this.u, required this.fondo});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Flexible en los dos: es mi punto ciego de toda esta sesión, y en
      // una imagen que se comparte un desborde son las rayas amarillas y
      // negras para siempre.
      Flexible(
        child: Text(
          'Colibrí',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: u * 3.2,
            fontWeight: FontWeight.w600,
            color: Paleta.lila,
          ),
        ),
      ),
      SizedBox(width: u * 2),
      Flexible(
        child: Text(
          'mi biblioteca de lectora',
          maxLines: 1,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: u * 2.8, color: fondo.tenue),
        ),
      ),
    ],
  );
}

/// La reseña, dibujada al tamaño más grande con el que entra completa.
///
/// Es el mismo truco que ya usa la placa de una frase: se mide de verdad
/// cuánto ocuparía el texto a cada tamaño y se parte el rango a la mitad
/// hasta acertar. Una tabla por largo de texto adivina mal —una reseña con
/// palabras largas ocupa mucho más que otra del mismo largo— y el resultado
/// era texto cortado.
///
/// Y si ni al mínimo entra, se recorta con puntos suspensivos: una reseña
/// de tres mil caracteres no cabe en una imagen a ningún tamaño legible, y
/// achicarla hasta que entre es la otra forma de no poder leerla.
class _ResenaQueEntra extends StatelessWidget {
  final String texto;
  final Color color;
  final double maximo;
  final double minimo;

  const _ResenaQueEntra({
    required this.texto,
    required this.color,
    required this.maximo,
    required this.minimo,
  });

  static const _estilo = TextStyle(height: 1.45);

  double _mayorQueEntra(String t, double ancho, double alto) {
    double alturaCon(double tamano) {
      final medidor = TextPainter(
        text: TextSpan(
          text: t,
          style: _estilo.copyWith(fontSize: tamano),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: ancho);
      return medidor.height;
    }

    if (alturaCon(maximo) <= alto) return maximo;

    var chico = minimo;
    var grande = maximo;
    for (var i = 0; i < 12; i++) {
      final medio = (chico + grande) / 2;
      if (alturaCon(medio) <= alto) {
        chico = medio;
      } else {
        grande = medio;
      }
    }
    return chico;
  }

  /// Cuántos caracteres entran al tamaño mínimo, si el texto no entra ni
  /// achicado del todo.
  String _recortado(double ancho, double alto) {
    final medidor = TextPainter(
      text: TextSpan(
        text: texto,
        style: _estilo.copyWith(fontSize: minimo),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: ancho);

    if (medidor.height <= alto) return texto;

    // Dónde cae el último carácter que todavía se ve.
    final posicion = medidor.getPositionForOffset(Offset(ancho, alto));
    final corte = posicion.offset.clamp(0, texto.length);
    if (corte <= 1) return texto;

    // Se corta en la última palabra entera, que es donde alguien esperaría
    // que corte, y no en la mitad de una.
    final hasta = texto.substring(0, corte);
    final espacio = hasta.lastIndexOf(' ');
    return '${(espacio > 40 ? hasta.substring(0, espacio) : hasta).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final t = _recortado(medidas.maxWidth, medidas.maxHeight);
        final tamano = _mayorQueEntra(t, medidas.maxWidth, medidas.maxHeight);

        return Text(
          t,
          style: _estilo.copyWith(fontSize: tamano, color: color),
        );
      },
    );
  }
}

/// Selector de opciones en fila. Sirve para fondos y para formatos.
class _Opciones<T> extends StatelessWidget {
  final List<T> valores;
  final T activo;
  final String Function(T) nombre;
  final ValueChanged<T> alElegir;

  const _Opciones({
    required this.valores,
    required this.activo,
    required this.nombre,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final v in valores)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => alElegir(v),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: v == activo ? Paleta.lila : null,
                  border: Border.all(
                    color: v == activo ? Paleta.lila : Paleta.linea,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  nombre(v),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: v == activo ? Paleta.noche : Paleta.luz,
                    fontWeight: v == activo ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
