import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/pantallas/destacados.dart';
import 'package:colibri/pantallas/ficha.dart';

/// La biblioteca destacada, en Explorar.
///
/// flutter test corta toda petición HTTP real, así que estos libros
/// aparecen con la tapa dibujada y no la de Open Library. Lo que importa
/// probar acá es que la lista aparece igual, que las reseñas de muestra
/// están y dicen que lo son, y que se puede abrir un libro.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> abrir(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BibliotecaDestacada())),
    );
  }

  testWidgets('carga y termina sin romper nada', (tester) async {
    // Bajo flutter test, las diez consultas fallan al instante —sin red
    // real— así que la carga puede terminar antes de que llegue a
    // dibujarse ni un solo frame con la rueda puesta. Lo que importa
    // probar no es en qué momento exacto aparece la rueda, sino que todo
    // el ciclo —cargar, fallar afuera, mostrar el resultado— no rompe.
    await abrir(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('una vez cargada, muestra los libros y las reseñas', (
    tester,
  ) async {
    await abrir(tester);
    await tester.pumpAndSettle();

    expect(find.text('PARA EMPEZAR A MIRAR'), findsOneWidget);
    expect(find.textContaining('Cometierra'), findsOneWidget);
    expect(find.textContaining('Cien años de soledad'), findsOneWidget);
  });

  testWidgets('las reseñas dicen con claridad que son de muestra', (
    tester,
  ) async {
    // No es un detalle menor: es la primera pantalla que ve cualquiera,
    // sin haber usado la app antes. Que parezcan reales sin decirlo
    // sería mentir sobre cuánta comunidad hay hoy.
    await abrir(tester);
    await tester.pumpAndSettle();

    expect(find.text('RESEÑAS DE MUESTRA'), findsOneWidget);
    expect(
      find.textContaining('Todavía no hay comunidad de verdad'),
      findsOneWidget,
    );
    expect(find.textContaining('Caro Vidal'), findsOneWidget);
  });

  testWidgets('tocar un libro abre su ficha', (tester) async {
    await abrir(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Cometierra').first);
    await tester.pumpAndSettle();

    expect(find.byType(PantallaFicha), findsOneWidget);
  });

  testWidgets('la segunda vez sale de la libreta y no del catálogo', (
    tester,
  ) async {
    // Sin esto, cada vez que alguien abre Explorar se mandarían diez
    // consultas de nuevo, y en datos móviles eso se siente.
    await abrir(tester);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox()); // se descarta el widget
    await abrir(tester);
    await tester.pump(); // sin pumpAndSettle: si tuviera que salir a la
    // red otra vez, en este primer pump todavía estaría cargando

    expect(find.text('PARA EMPEZAR A MIRAR'), findsOneWidget);
  });
}
