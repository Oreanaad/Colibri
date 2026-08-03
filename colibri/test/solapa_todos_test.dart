import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/biblioteca.dart';

/// La solapa «Todos».
///
/// Es tu estante entero en un solo lugar, y es la que se abre al entrar.
/// Va en secciones y no todo mezclado: una grilla con ciento veinte libros
/// seguidos se ve linda y no dice nada, porque no hay forma de saber cuál
/// estás leyendo y cuál esperás hace dos años.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
    await sesion.cargar();
  });

  Future<void> conLibros(List<(String, Estado)> libros) async {
    for (final (i, entrada) in libros.indexed) {
      final l = Libro(id: '$i', titulo: entrada.$1, autor: 'Alguien');
      await biblioteca.agregar(l);
      if (entrada.$2 != Estado.pendiente) {
        await biblioteca.cambiarEstado(l, entrada.$2);
      }
    }
  }

  Future<void> abrir(WidgetTester tester, {Size? tamano}) async {
    if (tamano != null) {
      await tester.binding.setSurfaceSize(tamano);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PantallaBiblioteca())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('se abre en Todos', (tester) async {
    await conLibros([('Cometierra', Estado.pendiente)]);
    await abrir(tester);

    expect(find.text('Todos'), findsOneWidget);
  });

  testWidgets('están las cinco solapas', (tester) async {
    await abrir(tester);

    // Los rótulos de sección van en mayúsculas, así que se buscan las
    // solapas por su texto tal cual.
    for (final nombre in [
      'Todos',
      'Leyendo',
      'Leídos',
      'Pendientes',
      'Estantes',
    ]) {
      expect(find.text(nombre), findsWidgets, reason: 'falta «$nombre»');
    }
  });

  testWidgets('muestra los tres estados a la vez, con su cuenta', (
    tester,
  ) async {
    await conLibros([
      ('Cometierra', Estado.leyendo),
      ('Las malas', Estado.pendiente),
      ('Catedrales', Estado.pendiente),
      ('Pedro Páramo', Estado.leido),
    ]);
    // Alta a propósito: las listas solo arman lo que se ve, así que en una
    // pantalla corta la última sección no existiría todavía y el test
    // estaría midiendo el alto de la ventana, no la solapa.
    await abrir(tester, tamano: const Size(800, 2400));

    // Esto es lo que la solapa promete: ver todo sin cambiar de pestaña.
    expect(find.text('LEYENDO · 1'), findsOneWidget);
    expect(find.text('PENDIENTES · 2'), findsOneWidget);
    expect(find.text('LEÍDOS · 1'), findsOneWidget);
  });

  testWidgets('las secciones vacías no dejan títulos huérfanos', (
    tester,
  ) async {
    await conLibros([('Cometierra', Estado.pendiente)]);
    await abrir(tester);

    expect(find.text('PENDIENTES · 1'), findsOneWidget);
    expect(find.textContaining('LEÍDOS ·'), findsNothing);
    expect(find.textContaining('LEYENDO ·'), findsNothing);
  });

  testWidgets('sin ningún libro no se ve una pantalla rota', (tester) async {
    await abrir(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('las cinco solapas entran en un teléfono angosto', (
    tester,
  ) async {
    // En 320 puntos le tocan 64 a cada una y «Pendientes» mide más. El
    // texto se achica solo en vez de cortarse: una solapa que dice
    // «Pendien…» es una solapa que no se entiende.
    await abrir(tester, tamano: const Size(320, 800));

    expect(tester.takeException(), isNull);
    expect(find.text('Pendientes'), findsOneWidget);
  });
}
