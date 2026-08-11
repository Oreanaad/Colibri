import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/cuenta.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/biblioteca.dart';
import 'package:colibri/pantallas/destacados.dart';
import 'package:colibri/tema.dart';
import 'package:colibri/widgets.dart';

/// Cómo se acomodan las tapas según el ancho.
///
/// # El bug que esto atrapa
///
/// Antes se le pedía a la grilla "ninguna tapa más ancha que 118" y se la
/// dejaba decidir cuántas columnas poner. El resultado, medido:
///
///     pantalla de 360 px  ->  tapas de 103
///     pantalla de 375 px  ->  tapas de  78   <- más grande, más chicas
///     pantalla de 412 px  ->  tapas de 117
///     pantalla de 430 px  ->  tapas de  90   <- otra vez
///
/// En un iPhone 13 mini las tapas quedaban más chicas que en un teléfono
/// más angosto. Ahora se fijan las columnas y la tapa solo puede crecer.
void main() {
  group('la regla, como función pura', () {
    test('los teléfonos van todos en tres columnas', () {
      // De 320 a 430 de pantalla, el ancho útil va de 288 a 390.
      for (final util in <double>[288, 328, 343, 358, 372, 390]) {
        expect(
          Medidas.columnasParaAncho(util),
          3,
          reason: 'con $util de ancho útil',
        );
      }
    });

    test('recién en tablet suma columnas', () {
      expect(Medidas.columnasParaAncho(420), 4);
      expect(Medidas.columnasParaAncho(540), 5);
    });

    test('nunca devuelve menos de tres, ni con un ancho absurdo', () {
      // Con dos columnas en un teléfono chico las tapas quedarían
      // enormes y habría que desplazar el doble.
      expect(Medidas.columnasParaAncho(0), 3);
      expect(Medidas.columnasParaAncho(100), 3);
    });
  });

  group('Descubrir arriba del estante, sin taparlo', () {
    // El bug que esto atrapa: Descubrir vivía solo en la pantalla de
    // explorar, así que se veía únicamente **antes** de tener perfil. Al
    // subirlo a la biblioteca, el bloque entero medía 1099 px —el
    // carrusel más las reseñas de muestra más el bloque de Goodreads— y
    // en un iPhone 15 Pro, de 852 px de alto, el primer libro propio
    // caía en y=1286: una pantalla y media hacia abajo.
    //
    // Arriba del estante va solo el carrusel.

    testWidgets('el estante se ve sin desplazar nada', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await biblioteca.cargar();
      for (final l in [...biblioteca.todos]) {
        await biblioteca.quitar(l);
      }
      await cuenta.crear(usuario: 'lectora', nombre: 'L');
      for (var i = 0; i < 9; i++) {
        await biblioteca.agregar(
          Libro(
            id: '$i',
            titulo: 'Libro $i',
            autor: 'Alguien',
            estado: Estado.pendiente,
          ),
        );
      }

      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PantallaBiblioteca())),
      );
      await tester.pumpAndSettle();

      // Que Descubrir no se coma la pantalla.
      final descubrir = tester.getRect(find.byType(BibliotecaDestacada));
      expect(
        descubrir.height,
        lessThan(450),
        reason: 'el bloque completo mide 1099 px; arriba va el modo compacto',
      );

      // Y que el estante caiga dentro de la primera pantalla, no solo
      // dentro del árbol de widgets.
      expect(find.text('PENDIENTES · 9'), findsOneWidget);
      expect(tester.getRect(find.text('PENDIENTES · 9')).top, lessThan(852));
    });

    testWidgets('en explorar sí va el bloque entero', (tester) async {
      // Ahí no hay nada tuyo que tapar, y las reseñas de muestra son las
      // que explican a dónde va la app.
      await tester.binding.setSurfaceSize(const Size(2600, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BibliotecaDestacada())),
      );
      await tester.pumpAndSettle();

      expect(find.text('RESEÑAS DE MUESTRA'), findsOneWidget);
    });

    testWidgets('en la biblioteca no van las reseñas de muestra', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(2600, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BibliotecaDestacada(compacta: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DESCUBRIR'), findsOneWidget);
      expect(find.text('RESEÑAS DE MUESTRA'), findsNothing);
    });
  });

  group('el nombre y las estrellas debajo de cada tapa', () {
    Future<void> conEstosLibros(WidgetTester tester, List<int> puntajes) async {
      SharedPreferences.setMockInitialValues({});
      await biblioteca.cargar();
      for (final l in [...biblioteca.todos]) {
        await biblioteca.quitar(l);
      }
      await cuenta.crear(usuario: 'lectora', nombre: 'L');
      for (var i = 0; i < puntajes.length; i++) {
        await biblioteca.agregar(
          Libro(
            id: '$i',
            titulo: 'Titulo numero $i',
            autor: 'Alguien',
            puntaje: puntajes[i],
          ),
        );
      }

      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GrillaLibros(biblioteca.todos, alTocar: (_) {})),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('el título va debajo, no solo dentro de la tapa', (
      tester,
    ) async {
      // Una grilla de tapas sin nombre obliga a abrir cada una para saber
      // qué es. Ya estaba así en Descubrir; en los estantes faltaba.
      await conEstosLibros(tester, [0, 0, 0]);

      // Dos veces cada uno: en la tapa dibujada y como nombre debajo.
      expect(find.text('Titulo numero 0'), findsNWidgets(2));
    });

    testWidgets('las estrellas solo en los que puntuaste', (tester) async {
      // Cinco estrellas apagadas en cada libro sin puntaje se leen como
      // un cero, y no es cero: es que todavía no dijiste nada.
      await conEstosLibros(tester, [5, 0, 3, 0]);

      expect(find.byType(Estrellas), findsNWidgets(2));
    });

    testWidgets('la celda le da lugar al renglón de abajo', (tester) async {
      // Con la proporción de la tapa sola —2/3— el título y las estrellas
      // no entraban y el renglón se cortaba con las rayas de error.
      await conEstosLibros(tester, [5, 4, 3]);

      expect(tester.takeException(), isNull);
    });
  });

  test('ninguna grilla quedó con la regla vieja', () {
    // Esto no mira la pantalla, mira el código, y es a propósito.
    //
    // Hay tres grillas de tapas —la biblioteca, elegir edición, elegir
    // tus libros— y al arreglar el tamaño cambié dos y me quedé con que
    // había cambiado las tres. La de elegir edición, que es justo la
    // pantalla donde uno se pasa el rato mirando tapas para encontrar la
    // suya, siguió con la regla vieja. Ninguna prueba de las que había
    // podía notarlo, porque esa pantalla pide libros por internet y en
    // las pruebas no hay internet: la grilla se dibuja vacía.
    //
    // Mientras no se pueda mirar esa pantalla de verdad, al menos que no
    // se pueda dejar suelta.
    final grillas = <String>[];
    for (final archivo in Directory('lib').listSync(recursive: true)) {
      if (archivo is! File || !archivo.path.endsWith('.dart')) continue;
      if (archivo.readAsStringSync().contains(
        'SliverGridDelegateWithMaxCrossAxisExtent',
      )) {
        grillas.add(archivo.path);
      }
    }

    expect(
      grillas,
      isEmpty,
      reason:
          'estas grillas deciden el ancho de la tapa y dejan que las '
          'columnas salgan de ahí, que es lo que hacía que las tapas se '
          'achicaran al agrandarse la pantalla. Usar '
          'SliverGridDelegateWithFixedCrossAxisCount con '
          'Medidas.columnasParaAncho',
    );
  });

  group('la geometría de verdad', () {
    Future<double> tapaEn(WidgetTester tester, double ancho) async {
      SharedPreferences.setMockInitialValues({});
      await biblioteca.cargar();
      for (final l in [...biblioteca.todos]) {
        await biblioteca.quitar(l);
      }
      await cuenta.crear(usuario: 'lectora', nombre: 'L');
      for (var i = 0; i < 8; i++) {
        await biblioteca.agregar(
          Libro(id: '$i', titulo: 'Libro $i', autor: 'Alguien'),
        );
      }

      await tester.binding.setSurfaceSize(Size(ancho, 1000));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: ancho, child: const PantallaBiblioteca()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return tester.getRect(find.byType(Tapa).first).width;
    }

    testWidgets('la tapa nunca se achica al crecer el teléfono', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Los anchos de los teléfonos que usa la gente.
      double? anterior;
      for (final ancho in <double>[320, 360, 375, 390, 412, 430]) {
        final tapa = await tapaEn(tester, ancho);
        if (anterior != null) {
          expect(
            tapa,
            greaterThanOrEqualTo(anterior - 0.5),
            reason: 'a $ancho px la tapa se achicó respecto de la anterior',
          );
        }
        anterior = tapa;
      }
    });

    testWidgets('en el mini la tapa pasa de los 100 px', (tester) async {
      // 375 era el peor caso: 78 px. Es el ancho del iPhone 13 mini y del
      // SE nuevo, o sea muchos teléfonos de verdad.
      addTearDown(() => tester.binding.setSurfaceSize(null));

      expect(await tapaEn(tester, 375), greaterThan(100));
    });

    testWidgets('en una pantalla enorme no se estiran sin límite', (
      tester,
    ) async {
      // El techo de ancho de la app las mantiene del mismo tamaño: una
      // tapa de 300 px en un monitor se vería como un cartel.
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final tapa = await tapaEn(tester, 1400);
      expect(tapa, lessThan(140));
    });
  });
}
