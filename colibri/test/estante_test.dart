import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/estante.dart';
import 'package:colibri/widgets.dart';

/// La biblioteca como repisa: los libros de canto, con sus lomos.
///
/// # Qué información agrega, que la grilla tira
///
/// El grosor. En una grilla cada libro ocupa lo mismo; en una repisa, un
/// tomo de novecientas páginas se ve gordo al lado de una novela de ciento
/// veinte. Eso es un dato que la lectora ya cargó y que no se estaba
/// mostrando en ningún lado.
///
/// Por eso la primera prueba de este archivo es que el grosor dependa de
/// las páginas: si eso se rompe, la repisa queda linda y deja de decir algo.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Libro libro(String titulo, {int? paginas}) =>
      Libro(id: titulo, titulo: titulo, autor: 'Alguien', paginas: paginas);

  Future<void> dibujar(
    WidgetTester tester,
    List<Libro> libros, {
    bool luces = true,
    double ancho = 380,
  }) async {
    await tester.binding.setSurfaceSize(Size(ancho + 40, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: ancho,
            child: EstanteDeLomos(libros, alTocar: (_) {}, conLuces: luces),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('el grosor dice cuántas páginas tiene', () {
    testWidgets('un libro gordo se ve más ancho que uno flaco', (tester) async {
      await dibujar(tester, [
        libro('Cometierra', paginas: 180),
        libro('Quicksilver', paginas: 880),
      ]);

      final flaco = tester.getSize(find.byType(GestureDetector).first).width;
      final gordo = tester.getSize(find.byType(GestureDetector).last).width;

      expect(
        gordo,
        greaterThan(flaco),
        reason: 'es lo único que la repisa dice y la grilla no',
      );
    });

    testWidgets('sin páginas anotadas usa un grosor del montón', (
      tester,
    ) async {
      // Lo mismo que hace una persona cuando no sabe: pone algo intermedio,
      // no un libro de un milímetro.
      await dibujar(tester, [libro('Sin páginas')]);

      final ancho = tester.getSize(find.byType(GestureDetector).first).width;
      expect(ancho, greaterThan(18));
      expect(ancho, lessThan(40));
    });

    testWidgets('un libro absurdo no rompe la fila', (tester) async {
      // Una enciclopedia de diez mil páginas cargada a mano no puede
      // ocupar la repisa entera.
      await dibujar(tester, [libro('Enorme', paginas: 10000)]);

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(GestureDetector).first).width,
        lessThanOrEqualTo(44),
      );
    });
  });

  group('los libros se acomodan solos', () {
    testWidgets('cuando no entra el siguiente, empieza otra balda', (
      tester,
    ) async {
      // Veinte libros no entran en un renglón de teléfono.
      await dibujar(tester, [
        for (var i = 0; i < 20; i++) libro('Libro $i', paginas: 400),
      ]);

      expect(tester.takeException(), isNull);
      // Todos dibujados, repartidos en varias baldas.
      expect(find.byType(GestureDetector), findsNWidgets(20));
    });

    testWidgets('con la biblioteca vacía no dibuja nada', (tester) async {
      await dibujar(tester, const []);
      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  group('dar vuelta un libro', () {
    testWidgets('el primer toque lo da vuelta y muestra la tapa', (
      tester,
    ) async {
      await dibujar(tester, [libro('Fourth Wing', paginas: 530)]);

      expect(find.byType(Tapa), findsNothing);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(
        find.byType(Tapa),
        findsOneWidget,
        reason: 'girar el libro es para mirar la tapa sin salir de la repisa',
      );
    });

    testWidgets('el segundo toque abre la ficha', (tester) async {
      // Dos gestos y no uno: mirar la tapa no debería costar salir de la
      // repisa, y llegar a la ficha tiene que seguir siendo corto.
      Libro? abierto;
      await tester.binding.setSurfaceSize(const Size(420, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EstanteDeLomos([
              libro('Fourth Wing', paginas: 530),
            ], alTocar: (l) => abierto = l),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(abierto, isNull);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(abierto?.titulo, 'Fourth Wing');
    });

    testWidgets('solo uno dado vuelta a la vez', (tester) async {
      // Con muchos dados vuelta la repisa vuelve a ser una grilla
      // desordenada, que es de lo que se quería salir.
      await dibujar(tester, [
        libro('Uno', paginas: 300),
        libro('Dos', paginas: 300),
      ]);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pumpAndSettle();

      expect(find.byType(Tapa), findsOneWidget);
    });
  });

  group('las luces', () {
    testWidgets('se pueden apagar', (tester) async {
      await dibujar(tester, [libro('Uno', paginas: 300)], luces: true);
      final conLuces = tester.widgetList(find.byType(Container)).length;

      await dibujar(tester, [libro('Uno', paginas: 300)], luces: false);
      final sinLuces = tester.widgetList(find.byType(Container)).length;

      expect(
        sinLuces,
        lessThan(conLuces),
        reason: 'apagadas no se dibujan, no se dibujan grises',
      );
    });

    testWidgets('apagarlas no cambia los libros', (tester) async {
      await dibujar(tester, [
        libro('Uno', paginas: 300),
        libro('Dos', paginas: 700),
      ], luces: false);

      expect(find.byType(GestureDetector), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('lo que se recuerda', () {
    test('la vista y las luces sobreviven a cerrar la app', () async {
      SharedPreferences.setMockInitialValues({});
      await sesion.cargar();
      expect(sesion.comoRepisa, isFalse, reason: 'de fábrica, la grilla');
      expect(sesion.conLuces, isTrue, reason: 'de fábrica, prendidas');

      await sesion.anotar(comoRepisa: true, conLuces: false);
      await sesion.cargar();

      expect(sesion.comoRepisa, isTrue);
      expect(sesion.conLuces, isFalse);
    });
  });
}
