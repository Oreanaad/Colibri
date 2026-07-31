import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/tema.dart';
import 'package:colibri/widgets.dart';

List<Libro> _libros(int n) => List.generate(
  n,
  (i) => Libro(id: '$i', titulo: 'Libro $i', autor: 'Alguien'),
);

/// Dibuja algo en una pantalla del ancho que se le pida.
Future<void> enPantallaDe(
  WidgetTester tester,
  double ancho,
  Widget hijo,
) async {
  tester.view.physicalSize = Size(ancho, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: construirTema(),
      // El mismo margen lateral que usan las pantallas de verdad: sin
      // él, el test mide una grilla que no existe en ningún lado.
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: hijo,
        ),
      ),
    ),
  );
}

/// Cuántas tapas entran en el primer renglón de la grilla.
int columnas(WidgetTester tester) {
  final tapas = find.byType(Tapa);
  final primera = tester.getTopLeft(tapas.at(0)).dy;
  var n = 0;
  for (var i = 0; i < tester.widgetList(tapas).length; i++) {
    if (tester.getTopLeft(tapas.at(i)).dy == primera) n++;
  }
  return n;
}

void main() {
  group('la grilla se adapta al ancho', () {
    testWidgets('en un teléfono entran tres', (tester) async {
      await enPantallaDe(
        tester,
        390, // un iPhone común
        GrillaLibros(_libros(12), alTocar: (_) {}),
      );
      expect(columnas(tester), 3);
    });

    testWidgets('en una computadora entran más, sin agrandar las tapas', (
      tester,
    ) async {
      await enPantallaDe(
        tester,
        390,
        GrillaLibros(_libros(12), alTocar: (_) {}),
      );
      final anchoEnTelefono = tester.getSize(find.byType(Tapa).first).width;

      await enPantallaDe(
        tester,
        1200,
        GrillaLibros(_libros(12), alTocar: (_) {}),
      );
      final anchoEnCompu = tester.getSize(find.byType(Tapa).first).width;

      expect(
        columnas(tester),
        greaterThan(4),
        reason: 'con más lugar, más columnas',
      );
      expect(
        (anchoEnCompu - anchoEnTelefono).abs(),
        lessThan(25),
        reason: 'la tapa mide casi lo mismo: crece la grilla, no el libro',
      );
    });
  });

  group('el contenido no se estira', () {
    testWidgets('en un monitor queda centrado y con techo', (tester) async {
      await enPantallaDe(
        tester,
        1400,
        Columna(hijo: Container(color: Paleta.nocheAlta, height: 200)),
      );

      final caja = tester.getSize(find.byType(Container).first);
      expect(
        caja.width,
        lessThanOrEqualTo(Medidas.anchoComodo),
        reason: 'una línea de texto de 1400 píxeles es ilegible',
      );

      // Y centrado: el aire de un lado igual al del otro.
      final izquierda = tester.getTopLeft(find.byType(Container).first).dx;
      final derecha =
          1400 - tester.getTopRight(find.byType(Container).first).dx;
      expect((izquierda - derecha).abs(), lessThan(2));
    });

    testWidgets('en un teléfono ocupa todo el ancho', (tester) async {
      await enPantallaDe(
        tester,
        390,
        Columna(hijo: Container(color: Paleta.nocheAlta, height: 200)),
      );

      expect(
        tester.getSize(find.byType(Container).first).width,
        390 - 40,
        reason: 'en pantalla chica se usa todo, menos el margen',
      );
    });
  });
}
