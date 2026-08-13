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

/// La placa en sí.
///
/// Es un widget aparte porque es lo único que se fotografía: todo lo que
/// quede adentro sale en la imagen, y todo lo que quede afuera, no.
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
        // Todo se mide contra el ancho de la placa y no en píxeles fijos:
        // la misma placa se dibuja chica en la vista previa y al triple al
        // fotografiarla, y con medidas fijas se rompería en una de las dos.
        final u = medidas.maxWidth / 100;

        // El cuadrado tiene la mitad del alto y no entra lo mismo.
        //
        // Medido: con el diseño de «Historia» tal cual, el cuadrado se
        // desbordaba 69 píxeles por abajo. Se puede achicar todo hasta que
        // entre —y queda ilegible— o se puede sacar lo que sobra. Sale lo
        // que menos se extraña: los chips de ánimo, que son el adorno, y la
        // tapa va más chica. Las cuatro escalas y la reseña se quedan,
        // porque son la placa.
        final apretado = medidas.maxHeight < medidas.maxWidth * 1.3;

        return Container(
          color: fondo.fondo,
          padding: EdgeInsets.all(u * (apretado ? 4.5 : 6)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MI RESEÑA',
                style: TextStyle(
                  fontSize: u * 3.4,
                  letterSpacing: u * 0.55,
                  fontWeight: FontWeight.w600,
                  color: fondo.tenue,
                ),
              ),
              SizedBox(height: u * (apretado ? 2.5 : 4)),

              // La tapa y los datos, lado a lado.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tapa(libro, ancho: u * (apretado ? 18 : 26)),
                  SizedBox(width: u * 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          libro.titulo,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: u * 5.2,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: fondo.texto,
                          ),
                        ),
                        SizedBox(height: u * 1.4),
                        Text(
                          libro.autor,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: u * 3.6,
                            color: fondo.tenue,
                          ),
                        ),
                        SizedBox(height: u * 3),
                        _Escalas(libro: libro, u: u, tenue: fondo.tenue),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: u * (apretado ? 2.5 : 4)),
              _Datos(libro: libro, u: u, fondo: fondo),

              // La reseña, que es lo que ocupa todo lo que sobre.
              if (libro.tieneResena) ...[
                SizedBox(height: u * (apretado ? 2.5 : 4)),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(u * (apretado ? 3 : 4.5)),
                    decoration: BoxDecoration(
                      color: fondo.tarjeta,
                      borderRadius: BorderRadius.circular(u * 3),
                      border: Border.all(color: fondo.linea),
                    ),
                    child: _ResenaQueEntra(
                      texto: libro.resena!,
                      color: fondo.texto,
                      maximo: u * 4.4,
                      minimo: u * 2.2,
                    ),
                  ),
                ),
              ] else
                const Spacer(),

              if (libro.animos.isNotEmpty && !apretado) ...[
                SizedBox(height: u * 3.5),
                _Animos(animos: libro.animos, u: u, fondo: fondo),
              ],

              SizedBox(height: u * 3.5),
              // Flexible en los dos: es el cuarto renglón de esta sesión
              // que se desbordaba por poner texto en un Row sin él. Acá
              // eran 14 píxeles, y en una imagen que se comparte un
              // desborde son las rayas amarillas y negras para siempre.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Colibrí',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: u * 3.2,
                        color: Paleta.lila,
                        fontWeight: FontWeight.w600,
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
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Las cuatro escalas, y **solo las que puntuaste**.
///
/// Una fila de cinco estrellas vacías se lee como un cero, y no es cero:
/// es que todavía no dijiste nada. Lo mismo con las gotas y las llamitas.
class _Escalas extends StatelessWidget {
  final Libro libro;
  final double u;
  final Color tenue;

  const _Escalas({required this.libro, required this.u, required this.tenue});

  @override
  Widget build(BuildContext context) {
    final puestas = <(Escala, int)>[
      if (libro.puntaje > 0) (Escala.estrellas, libro.puntaje),
      if (libro.lagrimas > 0) (Escala.lagrimas, libro.lagrimas),
      if (libro.romantico > 0) (Escala.corazones, libro.romantico),
      if (libro.picante > 0) (Escala.chiles, libro.picante),
    ];

    if (puestas.isEmpty) {
      return Text(
        'sin puntuar',
        style: TextStyle(fontSize: u * 3, color: tenue),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (escala, valor) in puestas)
          Padding(
            padding: EdgeInsets.only(bottom: u * 1.1),
            child: Puntuacion(escala, valor, tamano: u * 4),
          ),
      ],
    );
  }
}

/// Las fechas y las páginas, en una fila de datos.
class _Datos extends StatelessWidget {
  final Libro libro;
  final double u;
  final FondoDeResena fondo;

  const _Datos({required this.libro, required this.u, required this.fondo});

  @override
  Widget build(BuildContext context) {
    final datos = <(String, String)>[
      if (libro.empezado != null) ('Empecé', fechaCorta(libro.empezado!)),
      if (libro.terminado != null) ('Terminé', fechaCorta(libro.terminado!)),
      if (libro.diasDeLectura != null)
        ('Me llevó', '${libro.diasDeLectura} días'),
      if (libro.paginas != null) ('Páginas', '${libro.paginas}'),
    ];

    if (datos.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: u * 3, horizontal: u * 3.5),
      decoration: BoxDecoration(
        border: Border.all(color: fondo.linea),
        borderRadius: BorderRadius.circular(u * 2.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final (rotulo, valor) in datos)
            Flexible(
              child: Column(
                children: [
                  Text(
                    rotulo.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: u * 2.4,
                      letterSpacing: u * 0.2,
                      color: fondo.tenue,
                    ),
                  ),
                  SizedBox(height: u * 0.9),
                  Text(
                    valor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: u * 3.2,
                      fontWeight: FontWeight.w600,
                      color: fondo.texto,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Cómo te dejó, en chips.
class _Animos extends StatelessWidget {
  final List<String> animos;
  final double u;
  final FondoDeResena fondo;

  const _Animos({required this.animos, required this.u, required this.fondo});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: u * 1.8,
    runSpacing: u * 1.6,
    children: [
      for (final a in animos)
        Container(
          padding: EdgeInsets.symmetric(horizontal: u * 2.6, vertical: u * 1.2),
          decoration: BoxDecoration(
            border: Border.all(color: fondo.linea),
            borderRadius: BorderRadius.circular(u * 4),
          ),
          child: Text(
            a,
            style: TextStyle(fontSize: u * 2.9, color: fondo.texto),
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
