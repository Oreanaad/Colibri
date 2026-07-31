import 'package:flutter/material.dart';

import 'tema.dart';

/// El fondo de la app: un librero dibujado en los márgenes.
///
/// # Qué problema resuelve
///
/// En una computadora el contenido va centrado y con un techo de ancho,
/// porque una línea de texto de treinta centímetros no se lee. Eso deja
/// mucho aire a los costados, y el aire vacío se ve pobre.
///
/// # Por qué lomos y no otra cosa
///
/// El estante estuvo en la identidad desde el primer día: la idea de que
/// entrar al perfil de alguien es pararse frente a su biblioteca. Poner
/// lomos ahí no es decorar por decorar, es la misma imagen de siempre.
///
/// # Las reglas que lo mantienen tranquilo
///
/// - Solo aparece si hay margen de sobra. En un teléfono no se dibuja
///   nada: no hay lugar y sería ruido encima del contenido.
/// - Los tonos son el mismo violeta del fondo, apenas más oscuro y
///   apenas más claro. Nunca un color nuevo.
/// - Se desvanece hacia el centro, así el borde del contenido no queda
///   marcado por una línea de lomos cortados.
/// - No se mueve al hacer scroll. Es el fondo de la habitación, no algo
///   que pase.
class Fondo extends StatelessWidget {
  final Widget hijo;
  const Fondo({super.key, required this.hijo});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Paleta.noche,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: const _Librero()),
            ),
          ),
          hijo,
        ],
      ),
    );
  }
}

class _Librero extends CustomPainter {
  const _Librero();

  /// Cuánto margen hace falta para que valga la pena dibujar.
  /// Menos que esto y quedan dos o tres lomos sueltos, que se ve peor
  /// que no tener nada.
  static const _margenMinimo = 120.0;

  /// Cuántas baldas tiene el mueble.
  static const _baldas = 3;

  /// Números repetibles a partir de un índice.
  ///
  /// A propósito no usamos azar de verdad: con azar, cada vez que la
  /// pantalla se redibuja los lomos cambiarían de ancho y de color, y el
  /// fondo titilaría. Así el mueble es siempre el mismo.
  static double _mezcla(int i, int sal) =>
      ((i * 9301 + sal * 49297 + 233) % 233280) / 233280;

  @override
  void paint(Canvas lienzo, Size medida) {
    final margen = (medida.width - Medidas.anchoComodo) / 2;
    if (margen < _margenMinimo) return; // teléfono: no hay lugar

    _lado(lienzo, medida, desde: 0, hasta: margen, izquierda: true);
    _lado(
      lienzo,
      medida,
      desde: medida.width - margen,
      hasta: medida.width,
      izquierda: false,
    );
  }

  void _lado(
    Canvas lienzo,
    Size medida, {
    required double desde,
    required double hasta,
    required bool izquierda,
  }) {
    final ancho = hasta - desde;
    final altoBalda = medida.height / _baldas;
    final sal = izquierda ? 7 : 31; // que los dos lados no sean iguales

    for (var balda = 0; balda < _baldas; balda++) {
      final piso = altoBalda * (balda + 1);

      // La tabla del estante.
      lienzo.drawRect(
        Rect.fromLTWH(desde, piso - 2, ancho, 2),
        Paint()..color = _violeta(0.20, 0.5),
      );

      var x = desde + 6;
      var i = balda * 100;

      while (x < hasta - 10) {
        final anchoLomo = 16 + _mezcla(i, sal) * 30;
        if (x + anchoLomo > hasta - 6) break;

        final altoLomo = altoBalda * (0.5 + _mezcla(i, sal + 3) * 0.42);
        final tono = _mezcla(i, sal + 11);

        // Uno de cada nueve lleva un dorado apenas insinuado, para que
        // el mueble no sea todo del mismo color.
        final dorado = _mezcla(i, sal + 17) > 0.89;

        final lomo = Rect.fromLTWH(x, piso - 2 - altoLomo, anchoLomo, altoLomo);

        lienzo.drawRect(
          lomo,
          Paint()
            ..color = dorado
                ? Paleta.oro.withValues(alpha: 0.055)
                : _violeta(0.085 + tono * 0.105, 1),
        );

        // La franja del título, que es lo que hace que se lea como un
        // lomo y no como una barra.
        if (anchoLomo > 22 && altoLomo > altoBalda * 0.6) {
          lienzo.drawRect(
            Rect.fromLTWH(
              x + anchoLomo * 0.22,
              piso - 2 - altoLomo * 0.78,
              anchoLomo * 0.56,
              1.5,
            ),
            Paint()..color = _violeta(0.26, 0.45),
          );
        }

        x += anchoLomo + 2 + _mezcla(i, sal + 23) * 3;
        i++;
      }
    }

    // Se desvanece hacia el contenido, para que no quede una línea de
    // lomos cortados justo al lado del texto.
    lienzo.drawRect(
      Rect.fromLTWH(desde, 0, ancho, medida.height),
      Paint()
        ..shader = LinearGradient(
          begin: izquierda ? Alignment.centerLeft : Alignment.centerRight,
          end: izquierda ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            Paleta.noche.withValues(alpha: 0),
            Paleta.noche.withValues(alpha: 0.55),
            Paleta.noche,
          ],
          stops: const [0, 0.62, 1],
        ).createShader(Rect.fromLTWH(desde, 0, ancho, medida.height)),
    );
  }

  /// Un violeta de la misma familia que el fondo, más oscuro o más claro
  /// según la luminosidad que se pida. Nunca un color nuevo.
  Color _violeta(double luz, double opacidad) =>
      HSLColor.fromAHSL(opacidad, 250, 0.40, luz).toColor();

  @override
  bool shouldRepaint(_Librero anterior) => false;
}
