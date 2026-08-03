import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/fondo.dart';
import 'package:colibri/tema.dart';

void main() {
  testWidgets('la pantalla que se abre trae su propio fondo', (tester) async {
    // El bug: para que se viera el librero, las pantallas quedaron
    // transparentes. Durante la animación Flutter dibuja las dos a la
    // vez, y se veían superpuestas. Cada pantalla que se abre tiene que
    // ser opaca por su cuenta.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final llave = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: llave,
        theme: construirTema().copyWith(
          pageTransitionsTheme: transicionesConFondo,
        ),
        builder: (context, hijo) => Fondo(hijo: hijo ?? const SizedBox()),
        home: const Scaffold(body: Center(child: Text('biblioteca'))),
      ),
    );
    await tester.pumpAndSettle();

    // Dos: el de la base y el que trae la propia pantalla inicial.
    expect(find.byType(Fondo), findsNWidgets(2));

    llave.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: Center(child: Text('ficha'))),
      ),
    );
    // A mitad de la animación, que es cuando se veía el problema.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byType(Fondo),
      findsNWidgets(3),
      reason:
          'la base, la pantalla que se va y la que llega: cada una '
          'con el suyo, y por eso la de arriba tapa a la de abajo',
    );

    await tester.pumpAndSettle();
    expect(find.text('ficha'), findsOneWidget);
  });

  testWidgets('las pantallas son transparentes, y por eso hace falta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: construirTema(), home: const Scaffold()),
    );

    final tema = Theme.of(tester.element(find.byType(Scaffold)));
    expect(
      tema.scaffoldBackgroundColor,
      Colors.transparent,
      reason: 'si un día deja de serlo, el librero desaparece',
    );
  });
}
