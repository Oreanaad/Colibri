import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../archivo/guardar_imagen.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// Los fondos de la placa. Tres y no diez: si hay demasiados, la gente
/// pierde tiempo eligiendo en vez de compartir.
enum Fondo { noche, papel, lomo }

extension on Fondo {
  String get nombre => switch (this) {
    Fondo.noche => 'Noche',
    Fondo.papel => 'Papel',
    Fondo.lomo => 'Lomo',
  };
}

/// Los dos formatos que usa la gente de verdad.
enum Formato { cuadrado, historia }

extension on Formato {
  String get nombre => this == Formato.cuadrado ? 'Cuadrado' : 'Historia';
  double get proporcion => this == Formato.cuadrado ? 1.0 : 9 / 16;
}

/// Convierte una frase en una imagen para redes.
///
/// Lo que se comparte es la frase que la lectora eligió más el título y
/// la autoría, que es exactamente lo que corresponde citar. Nunca sale
/// nada del archivo original.
class PantallaCompartir extends StatefulWidget {
  final Libro libro;
  final Frase frase;

  const PantallaCompartir(this.libro, this.frase, {super.key});

  @override
  State<PantallaCompartir> createState() => _PantallaCompartirState();
}

class _PantallaCompartirState extends State<PantallaCompartir> {
  /// La llave que le da acceso al widget dibujado para poder fotografiarlo.
  final _placa = GlobalKey();

  Fondo _fondo = Fondo.noche;
  Formato _formato = Formato.cuadrado;
  bool _trabajando = false;

  /// Saca una "foto" del widget tal como está en pantalla.
  ///
  /// pixelRatio 3 es lo que hace que la imagen salga nítida: se dibuja al
  /// triple del tamaño que ocupa en el teléfono. Sin eso, la placa se ve
  /// borrosa apenas alguien la abre en grande.
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
    return 'colibri-${t.length > 40 ? t.substring(0, 40) : t}.png';
  }

  Future<void> _compartir() async {
    setState(() => _trabajando = true);
    try {
      final bytes = await _dibujar();
      if (bytes == null) throw Exception('no se pudo dibujar la placa');

      await guardarImagen(
        bytes,
        nombre: _nombreArchivo,
        texto:
            '«${widget.frase.texto}»\n\n'
            '${widget.libro.titulo} — ${widget.libro.autor}',
      );

      if (mounted && kIsWeb) {
        mostrarAviso(context, 'Imagen guardada en Descargas');
      }
    } catch (e) {
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
          'Compartir',
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
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    // Sin techo, en un monitor la placa se dibuja enorme
                    // y la vista previa deja de parecerse a lo que sale.
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                      maxHeight: 600,
                    ),
                    child: AspectRatio(
                      aspectRatio: _formato.proporcion,
                      // RepaintBoundary es lo que permite fotografiar este
                      // pedazo de pantalla y nada más.
                      child: RepaintBoundary(
                        key: _placa,
                        child: Placa(
                          libro: widget.libro,
                          frase: widget.frase,
                          fondo: _fondo,
                          formato: _formato,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Columna(
                ancho: 420,
                hijo: Column(
                  children: [
                    _Opciones<Fondo>(
                      valores: Fondo.values,
                      activo: _fondo,
                      nombre: (f) => f.nombre,
                      alElegir: (f) => setState(() => _fondo = f),
                    ),
                    const SizedBox(height: 8),
                    _Opciones<Formato>(
                      valores: Formato.values,
                      activo: _formato,
                      nombre: (f) => f.nombre,
                      alElegir: (f) => setState(() => _formato = f),
                    ),
                    const SizedBox(height: 16),
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
  Widget build(BuildContext context) {
    return Row(
      children: valores.map((v) {
        final es = v == activo;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => alElegir(v),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: es ? Paleta.lila : Paleta.linea),
                  color: es ? const Color(0x22B9A6E6) : null,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  nombre(v),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: es ? Paleta.lila : Paleta.bruma,
                    fontWeight: es ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// La placa en sí. Es un widget aparte porque es lo único que se
/// fotografía: todo lo que quede adentro sale en la imagen, y todo lo
/// que quede afuera, no.
class Placa extends StatelessWidget {
  final Libro libro;
  final Frase frase;
  final Fondo fondo;
  final Formato formato;

  const Placa({
    super.key,
    required this.libro,
    required this.frase,
    required this.fondo,
    required this.formato,
  });

  bool get _claro => fondo == Fondo.papel;

  Color get _texto => _claro ? const Color(0xFF241B40) : Paleta.luz;
  Color get _suave => _claro ? const Color(0xFF766D8E) : Paleta.bruma;

  /// El fondo "Lomo" saca su color del título del libro, igual que las
  /// tapas generadas: dos libros distintos nunca dan la misma placa,
  /// pero el mismo libro siempre da la misma.
  Color get _colorLomo {
    final semilla = libro.titulo.hashCode.abs();
    final matiz = (250.0 + (semilla % 40) - 20) % 360;
    return HSLColor.fromAHSL(1, matiz, 0.38, 0.17).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        // Todo se mide contra el ancho de la placa, no contra píxeles
        // fijos: así la imagen se ve igual sea cual sea el tamaño en el
        // que se dibuje, y al exportarla al triple sigue proporcionada.
        final base = medidas.maxWidth * 0.056;
        final margen =
            medidas.maxWidth * (formato == Formato.historia ? 0.10 : 0.08);

        return Container(
          decoration: BoxDecoration(
            color: switch (fondo) {
              Fondo.noche => Paleta.noche,
              Fondo.papel => const Color(0xFFF2EFF6),
              Fondo.lomo => _colorLomo,
            },
            gradient: fondo == Fondo.noche
                ? const RadialGradient(
                    center: Alignment(-0.5, -0.6),
                    radius: 1.3,
                    colors: [Color(0x33E9B44C), Paleta.noche],
                  )
                : null,
          ),
          child: Stack(
            children: [
              if (fondo == Fondo.lomo)
                // Una franja dorada al costado, como el canto de un libro.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: medidas.maxWidth * 0.016,
                  child: Container(color: Paleta.oro),
                ),

              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: margen,
                  vertical: margen * (formato == Formato.historia ? 1.3 : 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“',
                      style: TextStyle(
                        fontSize: base * 2.1,
                        height: 0.9,
                        color: Paleta.oro,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(height: base * 0.35),

                    // La frase se queda con todo el espacio que sobra, y
                    // adentro se achica lo necesario para entrar entera.
                    Expanded(
                      child: _FraseQueEntra(
                        texto: frase.texto,
                        color: _texto,
                        maximo: base * 1.25,
                        minimo: base * 0.42,
                      ),
                    ),

                    SizedBox(height: base * 0.8),
                    Container(width: base * 1.6, height: 2, color: Paleta.oro),
                    SizedBox(height: base * 0.7),

                    Text(
                      libro.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: base * 0.66,
                        height: 1.25,
                        color: _texto,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: base * 0.16),
                    Text(
                      libro.autor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: base * 0.58,
                        color: Paleta.oro,
                      ),
                    ),

                    // La marca va acá, pegada a la ficha del libro, y no
                    // en una esquina.
                    //
                    // Una esquina se recorta sin perder nada. Esto no:
                    // para sacarla hay que recortar también el título y la
                    // autoría, que es justo lo que quien comparte quiere
                    // conservar. Es el único lugar de la placa que no se
                    // puede cortar sin romper la cita.
                    SizedBox(height: base * 0.3),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: base * 0.46,
                          color: _suave,
                          letterSpacing: 0.3,
                        ),
                        children: [
                          const TextSpan(text: 'co'),
                          TextSpan(
                            text: 'libr',
                            style: TextStyle(
                              color: Paleta.oro.withValues(alpha: 0.85),
                            ),
                          ),
                          const TextSpan(text: 'í'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// La frase, dibujada al tamaño más grande con el que entra completa.
///
/// Antes el tamaño salía de una tabla por largo de texto —menos de 90
/// caracteres, tal número; menos de 180, tal otro— y eso adivina mal: una
/// frase con palabras largas ocupa mucho más que otra del mismo largo, y
/// terminaba cortada.
///
/// Acá se mide de verdad. Se prueba un tamaño, se calcula cuánto alto
/// ocuparía, y se ajusta. Como probar de a uno sería lento, se parte el
/// rango a la mitad cada vez: doce pasos alcanzan para acertar al décimo
/// de punto. Se llama búsqueda binaria y es el mismo truco de adivinar un
/// número preguntando "¿más o menos?".
class _FraseQueEntra extends StatelessWidget {
  final String texto;
  final Color color;
  final double maximo;
  final double minimo;

  const _FraseQueEntra({
    required this.texto,
    required this.color,
    required this.maximo,
    required this.minimo,
  });

  static const _estilo = TextStyle(height: 1.45, fontStyle: FontStyle.italic);

  double _mayorQueEntra(double ancho, double alto) {
    double alturaCon(double tamano) {
      final medidor = TextPainter(
        text: TextSpan(
          text: texto,
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final tamano = _mayorQueEntra(medidas.maxWidth, medidas.maxHeight);
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            texto,
            style: _estilo.copyWith(fontSize: tamano, color: color),
          ),
        );
      },
    );
  }
}
