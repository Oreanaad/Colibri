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
/// - Los lomos son todos morados, en siete tonos distintos. Probamos con
///   más colores y se veía más, pero el fondo empezaba a competir con las
///   tapas, que son lo único que tiene que tener color acá.
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

  /// Los colores de los lomos: **solo morado y dorado**, los dos de la
  /// marca, en varios tonos cada uno.
  ///
  /// Cada entrada es matiz, saturación y el rango de luz que le toca. El
  /// rango existe porque dos lomos del mismo tono con distinta luz ya se
  /// leen como dos libros, y eso da variedad sin sumar colores nuevos.
  ///
  /// Los colores de los lomos: **solo morados**.
  ///
  /// Probamos con una paleta de tela de encuadernación —índigo, ciruela,
  /// borravino, verde botella— y con morados y dorados intercalados. Las
  /// dos se veían más, y las dos estaban peor: el fondo empezaba a
  /// competir con las tapas de los libros, que son lo único que tiene que
  /// tener color en esta pantalla.
  ///
  /// Un mueble de un solo color con muchos tonos se lee igual de bien
  /// como estante y desaparece cuando no lo mirás, que es lo que tiene
  /// que hacer un fondo.
  ///
  /// Cada entrada es matiz, saturación y el rango de luz que le toca. El
  /// matiz se mueve poquito —de 232 a 268— porque dos morados apenas
  /// distintos ya se leen como dos libros distintos.
  static const _tonos = <(double, double, double, double)>[
    (250, 0.40, 0.085, 0.20), // el morado de la casa
    (238, 0.38, 0.085, 0.18), // morado azulado
    (264, 0.34, 0.090, 0.19), // morado rojizo
    (250, 0.44, 0.060, 0.11), // morado casi negro
    (245, 0.28, 0.140, 0.22), // morado claro, apagado
    (232, 0.42, 0.075, 0.15), // morado frío
    (268, 0.30, 0.110, 0.21), // morado tirando a ciruela
  ];

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
      var tonoAnterior = -1;

      while (x < hasta - 10) {
        final anchoLomo = 14 + _mezcla(i, sal) * 34;
        if (x + anchoLomo > hasta - 6) break;

        final altoLomo = altoBalda * (0.46 + _mezcla(i, sal + 3) * 0.46);

        // El tono se elige al azar repetible, pero si le tocó el mismo
        // que al lomo de al lado se corre uno. Sin esto aparecen manchas
        // de tres o cuatro del mismo color y deja de verse un estante.
        var cual =
            (_mezcla(i, sal + 11) * _tonos.length).floor() % _tonos.length;
        if (cual == tonoAnterior) cual = (cual + 1) % _tonos.length;
        tonoAnterior = cual;

        final (matiz, saturacion, luzMin, luzMax) = _tonos[cual];
        final luz = luzMin + _mezcla(i, sal + 29) * (luzMax - luzMin);

        lienzo.drawRect(
          Rect.fromLTWH(x, piso - 2 - altoLomo, anchoLomo, altoLomo),
          Paint()
            ..color = HSLColor.fromAHSL(1, matiz, saturacion, luz).toColor(),
        );

        // La franja del título, que es lo que hace que se lea como un
        // lomo y no como una barra. Va del mismo color pero más clara,
        // como el estampado dorado de una tapa dura.
        if (anchoLomo > 20 && altoLomo > altoBalda * 0.58) {
          lienzo.drawRect(
            Rect.fromLTWH(
              x + anchoLomo * 0.22,
              piso - 2 - altoLomo * 0.78,
              anchoLomo * 0.56,
              1.5,
            ),
            Paint()
              ..color = HSLColor.fromAHSL(
                0.5,
                matiz,
                saturacion * 0.6,
                luz + 0.16,
              ).toColor(),
          );
        }

        x += anchoLomo + 2 + _mezcla(i, sal + 23) * 4;
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

  /// El violeta de la casa, para las tablas del mueble.
  Color _violeta(double luz, double opacidad) =>
      HSLColor.fromAHSL(opacidad, 250, 0.40, luz).toColor();

  @override
  bool shouldRepaint(_Librero anterior) => false;
}
