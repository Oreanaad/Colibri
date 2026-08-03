import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/widgets.dart';

/// Elegir dónde va cada libro, desde una lista de resultados.
///
/// Nació de cargar veinte libros de una sentada: todos caían en pendientes
/// y la única forma de moverlos era cazar un aviso que se iba solo. Con
/// veinte avisos haciendo cola, al tercero ya no sabés cuál era cuál.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
  });

  Libro cometierra() =>
      Libro(id: '1', titulo: 'Cometierra', autor: 'Dolores Reyes');

  /// Una pantalla mínima con un botón que abre la hoja.
  Future<void> abrir(WidgetTester tester, Libro libro) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => dondeVa(context, libro),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  group('un libro que todavía no tenés', () {
    testWidgets('la hoja dice qué libro es', (tester) async {
      await abrir(tester, cometierra());

      // En una lista de veinte resultados parecidos, «¿Dónde lo ponés?»
      // sin decir qué es «lo» obliga a cerrar la hoja para fijarse.
      expect(find.text('¿Dónde lo ponés?'), findsOneWidget);
      expect(find.text('Cometierra'), findsOneWidget);
    });

    testWidgets('ofrece los tres estantes y no ofrece sacarlo', (tester) async {
      await abrir(tester, cometierra());

      expect(find.text('Leyendo'), findsOneWidget);
      expect(find.text('Leídos'), findsOneWidget);
      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('Sacarlo de mi biblioteca'), findsNothing);
    });

    testWidgets('elegir «leyendo» lo suma ahí y anota la fecha', (
      tester,
    ) async {
      final libro = cometierra();
      await abrir(tester, libro);

      await tester.tap(find.text('Leyendo'));
      await tester.pumpAndSettle();

      expect(biblioteca.tiene(libro), isTrue);
      expect(libro.estado, Estado.leyendo);
      // Pasa por cambiarEstado y no nace con el estado puesto: por eso
      // queda anotado cuándo lo empezaste.
      expect(libro.empezado, isNotNull);
    });

    testWidgets('elegir «leídos» anota cuándo lo terminaste', (tester) async {
      final libro = cometierra();
      await abrir(tester, libro);

      await tester.tap(find.text('Leídos'));
      await tester.pumpAndSettle();

      expect(libro.estado, Estado.leido);
      expect(libro.terminado, isNotNull);
    });

    testWidgets('elegir «pendientes» lo suma sin inventar fechas', (
      tester,
    ) async {
      final libro = cometierra();
      await abrir(tester, libro);

      await tester.tap(find.text('Pendientes'));
      await tester.pumpAndSettle();

      expect(biblioteca.tiene(libro), isTrue);
      expect(libro.estado, Estado.pendiente);
      expect(libro.empezado, isNull);
      expect(libro.terminado, isNull);
    });

    testWidgets('cerrar la hoja sin elegir no agrega nada', (tester) async {
      final libro = cometierra();
      await abrir(tester, libro);

      // Tocar afuera de la hoja es como decir «me arrepentí».
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(biblioteca.tiene(libro), isFalse);
    });
  });

  group('un libro que ya tenés', () {
    testWidgets('la hoja cambia de pregunta y marca dónde está', (
      tester,
    ) async {
      final libro = cometierra();
      await biblioteca.agregar(libro);
      await biblioteca.cambiarEstado(libro, Estado.leyendo);

      await abrir(tester, libro);

      expect(find.text('Moverlo a'), findsOneWidget);
      expect(find.text('¿Dónde lo ponés?'), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('se puede mover de estante', (tester) async {
      final libro = cometierra();
      await biblioteca.agregar(libro);

      await abrir(tester, libro);
      await tester.tap(find.text('Leyendo'));
      await tester.pumpAndSettle();

      expect(libro.estado, Estado.leyendo);
      expect(biblioteca.todos, hasLength(1), reason: 'no se duplicó');
    });

    testWidgets('se puede sacar de la biblioteca', (tester) async {
      final libro = cometierra();
      await biblioteca.agregar(libro);

      await abrir(tester, libro);
      expect(find.text('Sacarlo de mi biblioteca'), findsOneWidget);

      await tester.tap(find.text('Sacarlo de mi biblioteca'));
      await tester.pumpAndSettle();

      expect(biblioteca.tiene(libro), isFalse);
    });

    testWidgets('elegir el estante en el que ya está no lo saca', (
      tester,
    ) async {
      // cambiarEstado tiene un deshacer: tocar dos veces el mismo estado
      // vuelve el libro a pendientes. Desde acá eso sería un accidente,
      // porque la hoja muestra dónde está y volver a tocarlo se lee como
      // «sí, ahí está bien».
      final libro = cometierra();
      await biblioteca.agregar(libro);
      await biblioteca.cambiarEstado(libro, Estado.leyendo);

      await abrir(tester, libro);
      await tester.tap(find.text('Leyendo'));
      await tester.pumpAndSettle();

      expect(libro.estado, Estado.leyendo);
    });
  });
}
