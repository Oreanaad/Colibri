import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/cargar_fanfic.dart';
import 'package:colibri/widgets.dart';

/// La pantalla de cargar un fanfic.
///
/// Lo que se prueba acá es que la seguridad contra los repetidos **se vea**:
/// que avise apenas pegás el enlace y no después de llenar cinco campos.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
  });

  Future<void> abrir(WidgetTester tester) async {
    // Alta a propósito: las listas solo arman lo que se ve, y con el
    // cartel de «ya lo tenés» el botón de guardar queda abajo del borde.
    // Sin esto el test diría que el botón no existe, cuando lo que pasa
    // es que la ventana de prueba es corta.
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: PantallaCargarFanfic()));
    await tester.pumpAndSettle();
  }

  Finder campoDelEnlace() => find.byType(TextField).first;

  testWidgets('explica para qué sirve el enlace antes de escribir nada', (
    tester,
  ) async {
    await abrir(tester);

    expect(
      find.textContaining('Es lo que hace que sea ese y no otro'),
      findsOneWidget,
    );
  });

  testWidgets('no deja guardar sin enlace', (tester) async {
    await abrir(tester);

    expect(tester.widget<BotonLleno>(find.byType(BotonLleno)).alTocar, isNull);
  });

  testWidgets('avisa si eso no es una dirección', (tester) async {
    await abrir(tester);
    await tester.enterText(campoDelEnlace(), 'Todo lo que somos');
    await tester.pump();

    expect(find.textContaining('no parece una dirección'), findsOneWidget);
  });

  testWidgets('reconoce el sitio apenas pegás el enlace', (tester) async {
    await abrir(tester);
    await tester.enterText(
      campoDelEnlace(),
      'https://archiveofourown.org/works/1234567',
    );
    await tester.pump();

    expect(find.textContaining('Archive of Our Own'), findsOneWidget);
    expect(find.textContaining('No lo tenías'), findsOneWidget);
  });

  testWidgets('avisa que ya lo tenés, aunque el título fuera otro', (
    tester,
  ) async {
    // El caso entero de la función: alguien carga un fic que ya está,
    // escribiendo el título de otra manera. La app lo sabe por el enlace,
    // en el momento y sin internet.
    await biblioteca.agregar(
      Libro(
        id: 'x',
        titulo: 'Todo lo que somos',
        autor: 'alguien',
        enlace: 'https://archiveofourown.org/works/1234567',
        origen: Origen.fanfic,
      ),
    );

    await abrir(tester);
    await tester.enterText(
      campoDelEnlace(),
      'http://www.archiveofourown.org/works/1234567/chapters/98765',
    );
    await tester.pump();

    expect(find.textContaining('ya está en tu biblioteca'), findsOneWidget);
    expect(find.textContaining('Todo lo que somos'), findsWidgets);

    // Y no deja guardarlo de nuevo.
    expect(tester.widget<BotonLleno>(find.byType(BotonLleno)).alTocar, isNull);
  });

  testWidgets('con enlace y título se puede guardar', (tester) async {
    await abrir(tester);
    await tester.enterText(
      campoDelEnlace(),
      'archiveofourown.org/works/1234567',
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'Todo lo que somos');
    await tester.pump();

    expect(
      tester.widget<BotonLleno>(find.byType(BotonLleno)).alTocar,
      isNotNull,
    );
  });

  testWidgets('sin título no alcanza', (tester) async {
    await abrir(tester);
    await tester.enterText(
      campoDelEnlace(),
      'archiveofourown.org/works/1234567',
    );
    await tester.pump();

    expect(tester.widget<BotonLleno>(find.byType(BotonLleno)).alTocar, isNull);
  });
}
