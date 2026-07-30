import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

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
  String get nombre =>
      this == Formato.cuadrado ? 'Cuadrado' : 'Historia';
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
      if (bytes == null) throw Exception('no se pudo dibujar');

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: _nombreArchivo,
            ),
          ],
          fileNameOverrides: [_nombreArchivo],
          text: '«${widget.frase.texto}»\n\n'
              '${widget.libro.titulo} — ${widget.libro.autor}',
        ),
      );
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, 'No se pudo compartir. Probá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Paleta.noche,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: const Text('Compartir',
            style: TextStyle(color: Paleta.luz, fontSize: 17)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Paleta.lila),
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

  /// El texto se achica solo cuando la frase es larga, para que nunca
  /// quede cortada ni se desborde.
  double get _tamano {
    final n = frase.texto.length;
    final base = formato == Formato.historia ? 1.15 : 1.0;
    if (n < 90) return 26 * base;
    if (n < 180) return 22 * base;
    if (n < 320) return 18 * base;
    if (n < 500) return 15 * base;
    return 13 * base;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final ancho = medidas.maxWidth;
        final alto = medidas.maxHeight;
        final margen = formato == Formato.historia ? 40.0 : 32.0;
        final margenAlto = formato == Formato.historia ? 52.0 : 30.0;

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
          // ClipRect recorta lo que sangra por los bordes: sin esto, la
          // marca de agua se dibujaría fuera de la placa.
          child: ClipRect(
            child: Stack(
              children: [
                // La marca de agua va primero de todo, para que quede
                // detrás del texto y no le pelee la lectura.
                Positioned(
                  left: -ancho * 0.05,
                  bottom: -alto * 0.03,
                  child: MarcaDeAgua(tamano: ancho * 0.30, sobreClaro: _claro),
                ),

                if (fondo == Fondo.lomo)
                  // Una franja dorada al costado, como el canto de un libro.
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 6,
                    child: Container(color: Paleta.oro),
                  ),

                Padding(
                  padding: EdgeInsets.fromLTRB(
                      margen, margenAlto, margen, margenAlto),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '“',
                        style: TextStyle(
                          fontSize: _tamano * 2.2,
                          height: 0.8,
                          color: Paleta.oro,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      SizedBox(height: _tamano * 0.3),
                      Flexible(
                        child: Text(
                          frase.texto,
                          style: TextStyle(
                            fontSize: _tamano,
                            height: 1.45,
                            color: _texto,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      SizedBox(height: _tamano * 1.2),

                      // Una línea dorada corta, y debajo la ficha del libro.
                      Container(width: 34, height: 2, color: Paleta.oro),
                      SizedBox(height: _tamano * 0.7),
                      Text(
                        libro.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _tamano * 0.62,
                          height: 1.25,
                          color: _texto,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: _tamano * 0.16),
                      Text(
                        libro.autor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _tamano * 0.55,
                          color: Paleta.oro,
                        ),
                      ),
                    ],
                  ),
                ),

                // La firma legible, abajo a la derecha. La marca de agua
                // se ve; esta se lee, que no es lo mismo.
                Positioned(
                  right: margen,
                  bottom: margenAlto,
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: _tamano * 0.5,
                        color: _suave,
                        letterSpacing: 0.3,
                      ),
                      children: [
                        const TextSpan(text: 'co'),
                        TextSpan(
                          text: 'libr',
                          style: TextStyle(
                            color: Paleta.oro.withValues(alpha: 0.8),
                          ),
                        ),
                        const TextSpan(text: 'í'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// El logotipo enorme y casi transparente que queda de fondo en la placa.
///
/// Sirve para que la imagen se siga reconociendo como de Colibrí aunque
/// alguien recorte el pie antes de subirla, que es lo que suele pasar.
/// Va bajísimo de opacidad a propósito: una marca de agua que compite con
/// el texto hace que la gente no comparta la placa.
///
/// El secreto de la marca se mantiene incluso acá: las cuatro letras del
/// medio van en dorado, un poco más visibles que el resto.
class MarcaDeAgua extends StatelessWidget {
  final double tamano;
  final bool sobreClaro;

  const MarcaDeAgua({
    super.key,
    required this.tamano,
    required this.sobreClaro,
  });

  @override
  Widget build(BuildContext context) {
    // Sobre papel claro hace falta menos opacidad: el contraste de un
    // gris oscuro sobre blanco pesa más que el de un blanco sobre noche.
    final base = sobreClaro
        ? const Color(0xFF241B40).withValues(alpha: 0.055)
        : Paleta.luz.withValues(alpha: 0.075);
    final destello = Paleta.oro.withValues(alpha: sobreClaro ? 0.11 : 0.14);

    return IgnorePointer(
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: tamano,
            height: 1,
            letterSpacing: tamano * 0.01,
            fontWeight: FontWeight.w400,
            color: base,
          ),
          children: [
            const TextSpan(text: 'co'),
            TextSpan(text: 'libr', style: TextStyle(color: destello)),
            const TextSpan(text: 'í'),
          ],
        ),
      ),
    );
  }
}
