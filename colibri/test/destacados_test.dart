import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/pantallas/destacados.dart';
import 'package:colibri/pantallas/ficha.dart';
import 'package:colibri/widgets.dart';

/// Descubrir: libros al azar, en Explorar.
///
/// Al ser al azar, no se puede esperar un título fijo en pantalla: eso es
/// justo lo que hay que probar de otra forma. Se prueba la cantidad, que
/// "Mostrame otros" cambie la mano, y que cualquiera se pueda abrir.
///
/// flutter test corta toda petición HTTP real, así que los libros
/// aparecen con la tapa dibujada y no la de Open Library. No importa para
/// lo que se prueba acá: los títulos siguen siendo los del mazo.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> abrir(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BibliotecaDestacada())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('carga y termina sin romper nada', (tester) async {
    await abrir(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reparte ocho, ni todo el mazo ni una sola carta', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('DESCUBRIR'), findsOneWidget);
    expect(find.byType(Tapa), findsNWidgets(8));
  });

  testWidgets('dice con claridad que es al azar y no un saber sobre vos', (
    tester,
  ) async {
    // La palabra que no puede aparecer es "recomendado": eso diría que
    // la app sabe algo de tus gustos, y no sabe nada todavía.
    await abrir(tester);

    expect(find.textContaining('Al azar'), findsOneWidget);
    expect(find.textContaining('recomendad'), findsNothing);
  });

  testWidgets('mostrame otros cambia la mano', (tester) async {
    await abrir(tester);

    final titulosDeAntes = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toSet();

    await tester.tap(find.text('Mostrame otros'));
    await tester.pumpAndSettle();

    final titulosDeAhora = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toSet();

    // No exige que cambien todos: con un mazo de treinta, alcanza con
    // que no sea exactamente la misma mano.
    expect(titulosDeAntes, isNot(equals(titulosDeAhora)));
  });

  testWidgets('las reseñas de muestra están y dicen que lo son', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('RESEÑAS DE MUESTRA'), findsOneWidget);
    expect(
      find.textContaining('Todavía no hay comunidad de verdad'),
      findsOneWidget,
    );
    expect(find.textContaining('Caro Vidal'), findsOneWidget);
  });

  testWidgets('tocar cualquiera abre su ficha', (tester) async {
    await abrir(tester);

    await tester.tap(find.byType(Tapa).first);
    await tester.pumpAndSettle();

    expect(find.byType(PantallaFicha), findsOneWidget);
  });

  testWidgets('un libro ya visto no se vuelve a pedir', (tester) async {
    // No se puede observar la red desde acá, pero sí lo que queda
    // guardado: después de una mano, tiene que haber algo en la libreta.
    await abrir(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('colibri.descubrir.cache.v1'), isNotNull);
  });
}
