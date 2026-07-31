import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/resena.dart';
import 'package:colibri/tema.dart';

Future<void> _mostrar(WidgetTester tester, String? resena) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: construirTema(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ResenaPropia(
            Libro(
              id: '1',
              titulo: 'Cometierra',
              autor: 'Dolores Reyes',
              resena: resena,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('una reseña corta no muestra "Ver más"', (tester) async {
    await _mostrar(tester, 'Buenísimo, lo leí de un tirón.');

    expect(find.text('Ver más'), findsNothing,
        reason: 'un "ver más" que no muestra nada más molesta');
  });

  testWidgets('una reseña larga arranca cortada y se puede abrir',
      (tester) async {
    final larga = List.filled(40, 'Prueba de reseña.').join(' ');
    await _mostrar(tester, larga);

    // Arranca cortada.
    var texto = tester.widget<Text>(find.textContaining('Prueba de reseña'));
    expect(texto.maxLines, 6);
    expect(texto.overflow, TextOverflow.ellipsis);
    expect(find.text('Ver más'), findsOneWidget);

    // Se abre.
    await tester.tap(find.text('Ver más'));
    await tester.pumpAndSettle();

    texto = tester.widget<Text>(find.textContaining('Prueba de reseña'));
    expect(texto.maxLines, isNull, reason: 'abierta, sin tope');
    expect(find.text('Ver menos'), findsOneWidget);

    // Y se vuelve a cerrar.
    await tester.tap(find.text('Ver menos'));
    await tester.pumpAndSettle();
    expect(find.text('Ver más'), findsOneWidget);
  });

  testWidgets('cortada ocupa menos de la mitad que abierta', (tester) async {
    final larga = List.filled(40, 'Prueba de reseña.').join(' ');
    await _mostrar(tester, larga);

    final cortada = tester.getSize(find.byType(ResenaPropia)).height;

    await tester.tap(find.text('Ver más'));
    await tester.pumpAndSettle();
    final abierta = tester.getSize(find.byType(ResenaPropia)).height;

    expect(cortada, lessThan(abierta / 2),
        reason: 'ese era el punto: que no se coma la pantalla');
  });

  testWidgets('sin reseña, ofrece escribirla', (tester) async {
    await _mostrar(tester, null);

    expect(find.text('Escribir mi reseña'), findsOneWidget);
    expect(find.text('Ver más'), findsNothing);
  });
}
