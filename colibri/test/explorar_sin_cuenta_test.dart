import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/cuenta.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/biblioteca.dart';
import 'package:colibri/pantallas/buscar.dart';
import 'package:colibri/pantallas/exigir_cuenta.dart';
import 'package:colibri/pantallas/fanfics.dart';
import 'package:colibri/pantallas/ficha.dart';
import 'package:colibri/pantallas/todas_las_frases.dart';
import 'package:colibri/widgets.dart';

/// Explorar sin cuenta.
///
/// La regla, en una frase: se puede buscar y mirar libros sin perfil,
/// pero agregar, escribir una reseña o ver tu propia biblioteca pide
/// iniciar sesión. Acá se prueba esa frontera, no cada pantalla de cero.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
    await cuenta.salir(); // por si una prueba anterior dejó perfil puesto
  });

  Future<void> abrir(
    WidgetTester tester,
    Widget pantalla, {
    Size? tamano,
  }) async {
    await tester.binding.setSurfaceSize(tamano ?? const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: pantalla)));
    await tester.pumpAndSettle();
  }

  group('exigirCuenta, la función', () {
    testWidgets('sin perfil, no deja pasar hasta crear uno', (tester) async {
      var pasoDespues = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  if (!await exigirCuenta(context, motivo: 'probar')) return;
                  pasoDespues = true;
                },
                child: const Text('probar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('probar'));
      await tester.pumpAndSettle();

      expect(pasoDespues, isFalse);
      expect(find.text('Hace falta tu perfil'), findsOneWidget);
    });

    testWidgets('con perfil, no muestra nada y deja pasar de una', (
      tester,
    ) async {
      await cuenta.crear(usuario: 'lectora', nombre: 'Lectora');
      var pasoDespues = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  if (!await exigirCuenta(context, motivo: 'probar')) return;
                  pasoDespues = true;
                },
                child: const Text('probar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('probar'));
      await tester.pumpAndSettle();

      expect(pasoDespues, isTrue);
      expect(find.text('Hace falta tu perfil'), findsNothing);
    });

    testWidgets('crear el perfil ahí mismo deja pasar', (tester) async {
      // Superficie más alta: el formulario completo —foto, @usuario,
      // nombre, presentación— no entra en la ventana chica por defecto
      // de las pruebas, y sin eso el botón de guardar queda fuera y ni
      // se dibuja.
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var pasoDespues = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  if (!await exigirCuenta(context, motivo: 'probar')) return;
                  pasoDespues = true;
                },
                child: const Text('probar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('probar'));
      await tester.pumpAndSettle();

      // Todavía en la hoja: acá no hay ningún campo, solo los dos
      // botones. El @usuario vive recién en la pantalla que sigue.
      await tester.tap(find.text('Crear mi perfil'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'lectora');
      await tester.pump();
      await tester.tap(find.byType(BotonLleno));
      await tester.pumpAndSettle();

      expect(cuenta.hayPerfil, isTrue);
      expect(pasoDespues, isTrue);
      expect(find.text('Hace falta tu perfil'), findsNothing);
    });
  });

  group('la solapa Biblioteca', () {
    testWidgets('sin perfil muestra explorar, no tu estante', (tester) async {
      // Un título que no esté entre los destacados de Explorar: si no,
      // esta prueba no sabría distinguir "se filtró tu libro" de "está
      // ahí porque también es uno de los que se muestran para mirar".
      final l = Libro(id: '1', titulo: 'Trenzar', autor: 'Alice Walker');
      await biblioteca.agregar(l);

      await abrir(tester, const PantallaBiblioteca());

      // Ni un rastro del libro que ya está guardado en este teléfono.
      expect(find.text('Explorar'), findsOneWidget);
      expect(find.textContaining('Trenzar'), findsNothing);
      expect(find.textContaining('hace falta tu perfil'), findsOneWidget);
    });

    testWidgets('con perfil muestra tu estante', (tester) async {
      await cuenta.crear(usuario: 'lectora', nombre: 'Lectora');
      final l = Libro(id: '1', titulo: 'Cometierra', autor: 'Dolores Reyes');
      await biblioteca.agregar(l);

      await abrir(tester, const PantallaBiblioteca());

      expect(find.text('Explorar'), findsNothing);
      // Más de uno a propósito: el título va dentro de la tapa dibujada y
      // además debajo de ella, como nombre del libro en el estante.
      expect(find.textContaining('Cometierra'), findsWidgets);
    });

    testWidgets('armar el perfil desde ahí vuelve al estante solo', (
      tester,
    ) async {
      // No hace falta ningún botón de "listo, ahora sí": la solapa
      // escucha a cuenta y se redibuja apenas hay perfil.
      await abrir(tester, const PantallaBiblioteca());
      expect(find.text('Explorar'), findsOneWidget);

      await cuenta.crear(usuario: 'lectora', nombre: 'Lectora');
      await tester.pumpAndSettle();

      expect(find.text('Explorar'), findsNothing);
    });
  });

  group('la solapa Fanfics y la de Frases', () {
    testWidgets('sin perfil, ninguna de las dos muestra su contenido', (
      tester,
    ) async {
      await abrir(tester, const PantallaFanfics());
      expect(find.text('Tus fanfics necesitan tu perfil'), findsOneWidget);

      await abrir(tester, const PantallaTodasLasFrases());
      expect(find.text('Tus frases necesitan tu perfil'), findsOneWidget);
    });
  });

  group('Ficha, para un libro que todavía no es tuyo', () {
    testWidgets('agregar pide perfil antes de guardar nada', (tester) async {
      final l = Libro(id: '1', titulo: 'Cometierra', autor: 'Dolores Reyes');

      await abrir(tester, PantallaFicha(l));
      await tester.tap(find.text('Agregar a mi biblioteca'));
      await tester.pumpAndSettle();

      expect(find.text('Hace falta tu perfil'), findsOneWidget);
      expect(biblioteca.tiene(l), isFalse);
    });

    testWidgets('un libro guardado de antes no muestra tu reseña sin perfil', (
      tester,
    ) async {
      // El caso incómodo: alguien ya tenía libros en este teléfono de
      // antes de que existiera el modo explorar. Sin perfil, siguen sin
      // poder verse por adentro.
      final l = Libro(
        id: '1',
        titulo: 'Cometierra',
        autor: 'Dolores Reyes',
        resena: 'algo que escribí',
      );
      await biblioteca.agregar(l);

      await abrir(tester, PantallaFicha(l));

      expect(find.text('Agregar a mi biblioteca'), findsOneWidget);
      expect(find.textContaining('algo que escribí'), findsNothing);
    });
  });

  group('buscar.dart, los lanzadores de "agregar"', () {
    testWidgets('escanear pide perfil antes de abrir la cámara', (
      tester,
    ) async {
      await abrir(tester, const PantallaBuscar());

      await tester.tap(find.byTooltip('Escanear el código de barras'));
      await tester.pumpAndSettle();

      expect(find.text('Hace falta tu perfil'), findsOneWidget);
    });

    testWidgets('cargarlo a mano pide perfil antes de abrir el formulario', (
      tester,
    ) async {
      await abrir(tester, const PantallaBuscar());
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cargarlo yo'));
      await tester.pumpAndSettle();

      expect(find.text('Hace falta tu perfil'), findsOneWidget);
    });

    testWidgets('traer de Goodreads pide perfil antes de importar', (
      tester,
    ) async {
      await abrir(tester, const PantallaBuscar());

      await tester.tap(find.text('Traerla'));
      await tester.pumpAndSettle();

      expect(find.text('Hace falta tu perfil'), findsOneWidget);
    });
  });
}
