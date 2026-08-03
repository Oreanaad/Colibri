import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/escanear.dart';

/// La fila de un libro recién escaneado.
///
/// Existe por una captura de pantalla: «no veo el +». Estaba mirando el
/// escáner, y el más solo estaba en la búsqueda. La lección no fue el
/// botón que faltaba, fue que **no había forma de contestar sin adivinar**,
/// porque esa fila no se podía dibujar sin una cámara.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
  });

  Libro percy() => Libro(
    id: '1',
    titulo: 'Percy Jackson y la vara de Hermes y otras historias de semidioses',
    autor: 'Rick Riordan',
  );

  Future<void> dibujar(
    WidgetTester tester,
    Libro libro, {
    bool yaEstaba = false,
    double ancho = 390,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: ancho,
              child: FilaEscaneada(
                libro: libro,
                yaEstaba: yaEstaba,
                alDeshacer: () {},
                alElegirEdicion: () {},
                alCambiarEstante: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('muestra en qué estante quedó, y se puede tocar', (tester) async {
    await dibujar(tester, percy());

    expect(find.text('Pendientes'), findsOneWidget);
    await tester.tap(find.text('Pendientes'));
    await tester.pumpAndSettle();
  });

  testWidgets('el estante dice la verdad si el libro está en otro', (
    tester,
  ) async {
    final libro = percy();
    await biblioteca.agregar(libro);
    await biblioteca.cambiarEstado(libro, Estado.leyendo);

    await dibujar(tester, libro, yaEstaba: true);

    expect(find.text('Leyendo'), findsOneWidget);
    expect(find.text('Pendientes'), findsNothing);
  });

  testWidgets('ofrece elegir la edición', (tester) async {
    // El código de barras identifica una edición concreta, pero los
    // catálogos contestan con la obra: escaneás tu edición en castellano y
    // sale la tapa en inglés.
    await dibujar(tester, percy());

    expect(find.text('¿No es tu tapa?'), findsOneWidget);
  });

  testWidgets('un libro que ya tenías no se puede deshacer', (tester) async {
    // Sacar de la biblioteca un libro que ya era tuyo no es «deshacer el
    // escaneo», es borrar algo que estaba antes.
    await dibujar(tester, percy(), yaEstaba: true);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await dibujar(tester, percy());
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('entra en una pantalla angosta sin desbordarse', (tester) async {
    // Un título de dos renglones, un estante y el enlace de la edición
    // compitiendo por el mismo ancho. Si se desborda, lo que sobra queda
    // fuera de la pantalla: exactamente cómo se ve un botón que no está.
    await dibujar(tester, percy(), ancho: 320);

    expect(tester.takeException(), isNull);
    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.text('¿No es tu tapa?'), findsOneWidget);
  });

  testWidgets('antes de escanear, el trato está dicho completo', (
    tester,
  ) async {
    // Es lo único que se lee en esta pantalla: después ya estás mirando la
    // cámara. Si algo tiene que estar dicho, tiene que estar dicho acá.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ComoSeUsaElEscaner())),
    );

    // Qué hacer.
    expect(find.textContaining('código de barras'), findsOneWidget);
    // Dónde van a ir a parar.
    expect(find.textContaining('se suma solo a Pendientes'), findsOneWidget);
    // Y que eso se cambia después, que es lo que faltaba decir.
    expect(find.textContaining('tocá el estante'), findsOneWidget);
    expect(find.textContaining('Cuando quieras'), findsOneWidget);
    // Y la advertencia honesta de que varios no van a aparecer.
    expect(find.textContaining('pocas ediciones de acá'), findsOneWidget);
  });
}
