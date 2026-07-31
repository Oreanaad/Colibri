import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/fondo.dart';
import 'package:colibri/tema.dart';

Future<void> _enPantallaDe(WidgetTester tester, double ancho) async {
  tester.view.physicalSize = Size(ancho, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: construirTema(),
      home: const Fondo(
        hijo: Scaffold(body: Center(child: Text('contenido'))),
      ),
    ),
  );
}

void main() {
  testWidgets('el librero se dibuja sin romperse a cualquier ancho',
      (tester) async {
    for (final ancho in [320.0, 390.0, 620.0, 900.0, 1400.0, 2400.0]) {
      await _enPantallaDe(tester, ancho);
      expect(tester.takeException(), isNull, reason: 'a $ancho px');
      expect(find.text('contenido'), findsOneWidget,
          reason: 'el fondo nunca tapa lo que importa');
    }
  });

  testWidgets('no se redibuja al azar: el mueble es siempre el mismo',
      (tester) async {
    // Con azar de verdad, cada redibujado cambiaría los lomos y el fondo
    // titilaría. Por eso los números salen de una fórmula repetible.
    await _enPantallaDe(tester, 1400);
    final pintor = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(Fondo),
            matching: find.byType(CustomPaint),
          ).first,
        )
        .painter!;

    expect(pintor.shouldRepaint(pintor), isFalse);
  });

  testWidgets('el contenido queda encima del fondo', (tester) async {
    await _enPantallaDe(tester, 1400);

    // El fondo es el primero del Stack y el contenido el último: si
    // alguna vez se invierte, el texto queda tapado.
    final pila = tester.widget<Stack>(
      find.descendant(of: find.byType(Fondo), matching: find.byType(Stack)).first,
    );
    expect(pila.children.length, 2);
    expect(pila.children.first, isA<Positioned>());
  });
}
