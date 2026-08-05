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

  /// Ancho grande a propósito: el carrusel es una lista horizontal y
  /// solo construye lo que entra en pantalla. Con un ancho de teléfono,
  /// contar tarjetas mide el ancho de la ventana y no cuántas hay.
  Future<void> abrir(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(2600, 2400));
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

  testWidgets('reparte cinco, ni todo el mazo ni una sola carta', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('DESCUBRIR'), findsOneWidget);
    expect(find.byType(Tapa), findsNWidgets(5));
  });

  testWidgets('cada tarjeta lleva su título y sus estrellas', (tester) async {
    await abrir(tester);

    // Una fila de tapas sin nombre obliga a abrir cada una para saber
    // qué es. Con el título debajo se puede decidir mirando.
    //
    // Se cuentan las que están dentro del carrusel: las reseñas de
    // muestra, más abajo, también llevan estrellas.
    expect(
      find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Estrellas),
      ),
      findsNWidgets(5),
    );

    // Y el título de cada una, que es el otro dato que se pidió.
    for (final tapa in tester.widgetList<Tapa>(find.byType(Tapa))) {
      expect(find.text(tapa.libro.titulo), findsWidgets);
    }
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

  testWidgets('mostrame otros suma cinco más, no los reemplaza', (
    tester,
  ) async {
    // Es un carrusel, no una tanda que se pisa: lo que ya miraste sigue
    // ahí si querés volver.
    await abrir(tester);
    expect(find.byType(Tapa), findsNWidgets(5));

    await tester.tap(find.text('Mostrame otros cinco'));
    await tester.pumpAndSettle();

    expect(find.byType(Tapa), findsNWidgets(10));
  });

  testWidgets('no repite un libro que ya está en el carrusel', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Mostrame otros cinco'));
    await tester.pumpAndSettle();

    final tapas = tester.widgetList<Tapa>(find.byType(Tapa));
    final claves = tapas.map((t) => t.libro.clave).toList();

    expect(claves.toSet(), hasLength(claves.length));
  });

  testWidgets('se corta en veinte y ahí desaparece el botón', (tester) async {
    // Veinte es donde deja de ser un descubrimiento y pasa a ser una
    // lista: si mirando veinte no encontraste nada, lo que falta no son
    // más tarjetas.
    await abrir(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Mostrame otros cinco'));
      await tester.pumpAndSettle();
    }

    expect(find.byType(Tapa), findsNWidgets(20));
    expect(find.text('Mostrame otros cinco'), findsNothing);
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
