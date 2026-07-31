import 'package:flutter/material.dart';

/// Un chile, dibujado a mano.
///
/// No existe en los íconos que trae Flutter, y era el único que servía:
/// una llama dice «intenso» y un corazón dice «romántico», pero el chile
/// dice exactamente lo que la comunidad quiere decir, con la palabra que
/// ya usa.
///
/// Se dibuja con curvas en vez de traer una imagen para que se vea nítido
/// a cualquier tamaño y tome el color que se le pida, igual que los demás
/// íconos de la app.
class Chile extends StatelessWidget {
  final double tamano;
  final Color color;

  /// Relleno cuando cuenta, contorno cuando está apagado. Es la misma
  /// diferencia que hay entre una estrella llena y una vacía.
  final bool lleno;

  const Chile({
    super.key,
    required this.tamano,
    required this.color,
    this.lleno = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: CustomPaint(
        painter: _DibujoDeChile(color: color, lleno: lleno),
      ),
    );
  }
}

class _DibujoDeChile extends CustomPainter {
  final Color color;
  final bool lleno;

  const _DibujoDeChile({required this.color, required this.lleno});

  /// El dibujo está pensado en una caja de 24×24 y después se escala,
  /// así los números son legibles y no dependen del tamaño final.
  static const _base = 24.0;

  @override
  void paint(Canvas lienzo, Size medida) {
    final escala = medida.width / _base;
    lienzo.scale(escala);

    // El cuerpo: ancho arriba a la derecha, afinándose hasta la punta
    // curvada de abajo a la izquierda.
    final cuerpo = Path()
      ..moveTo(15.2, 7.2)
      ..cubicTo(19.2, 9.2, 19.6, 15.0, 14.2, 19.4)
      ..cubicTo(11.4, 21.6, 9.0, 21.2, 7.8, 20.0)
      ..cubicTo(10.2, 19.0, 12.0, 16.2, 12.3, 12.2)
      ..cubicTo(12.5, 9.2, 13.4, 7.6, 15.2, 7.2)
      ..close();

    // El cabito, que es lo que lo vuelve inconfundible.
    final tallo = Path()
      ..moveTo(15.2, 7.4)
      ..quadraticBezierTo(14.6, 3.8, 18.2, 3.0)
      ..quadraticBezierTo(16.6, 5.6, 15.9, 7.7)
      ..close();

    final pincel = Paint()
      ..color = color
      ..isAntiAlias = true;

    if (lleno) {
      pincel.style = PaintingStyle.fill;
    } else {
      pincel
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
    }

    lienzo.drawPath(cuerpo, pincel);
    lienzo.drawPath(tallo, pincel);
  }

  @override
  bool shouldRepaint(_DibujoDeChile anterior) =>
      anterior.color != color || anterior.lleno != lleno;
}
