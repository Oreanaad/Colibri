import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/biblioteca.dart';
import 'package:colibri/pantallas/fanfics.dart';

/// La sección propia de los fanfics.
///
/// Lo que hay que garantizar es que estén separados de verdad: si un fic
/// apareciera también en la biblioteca, verías «40 leídos» en un lado y
/// «12 leídos» en otro y ningún número sería el de tu año.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
    await sesion.cargar();
  });

  Future<Libro> unFic(String titulo, String obra, {Estado? estado}) async {
    final fic = Libro(
      id: obra,
      titulo: titulo,
      autor: 'alguien',
      enlace: 'https://archiveofourown.org/works/$obra',
      origen: Origen.fanfic,
    );
    await biblioteca.agregar(fic);
    if (estado != null) await biblioteca.cambiarEstado(fic, estado);
    return fic;
  }

  Future<Libro> unLibro(String titulo, {Estado? estado}) async {
    final libro = Libro(id: titulo, titulo: titulo, autor: 'Alguien');
    await biblioteca.agregar(libro);
    if (estado != null) await biblioteca.cambiarEstado(libro, estado);
    return libro;
  }

  Future<void> abrir(WidgetTester tester, Widget pantalla) async {
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Envuelta en un Scaffold: la biblioteca no trae el suyo, y sin
    // alturas acotadas su columna no llega a dibujar nada.
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: pantalla)));
    await tester.pumpAndSettle();
  }

  group('están separados', () {
    test('los libros no incluyen fanfics y viceversa', () async {
      await unLibro('Cometierra');
      await unFic('Todo lo que somos', '111');

      expect(biblioteca.libros.map((l) => l.titulo), ['Cometierra']);
      expect(biblioteca.fanfics.map((l) => l.titulo), ['Todo lo que somos']);
      expect(biblioteca.todos, hasLength(2));
    });

    test('las cuentas por estado no se pisan', () async {
      // Este es el motivo entero de separarlos: que cada número signifique
      // una sola cosa.
      await unLibro('Cometierra', estado: Estado.leido);
      await unFic('Un fic', '111', estado: Estado.leido);
      await unFic('Otro fic', '222', estado: Estado.leido);

      expect(biblioteca.enEstado(Estado.leido), hasLength(1));
      expect(biblioteca.fanficsEnEstado(Estado.leido), hasLength(2));
    });

    test('«leyendo ahora» de la biblioteca no es un fic', () async {
      await unFic('Un fic', '111', estado: Estado.leyendo);

      expect(biblioteca.leyendoAhora, isNull);
      expect(biblioteca.ficLeyendoAhora, isNotNull);
    });

    test('pero la búsqueda sí los encuentra', () async {
      // La única excepción, y a propósito: que la app diga «no lo tenés»
      // cuando lo tenés es peor que mezclar.
      await unFic('Todo lo que somos', '111');

      expect(
        biblioteca.buscarEnMiBiblioteca('todo lo que').single.titulo,
        'Todo lo que somos',
      );
    });
  });

  group('la sección', () {
    testWidgets('vacía explica qué va y por qué se pide el enlace', (
      tester,
    ) async {
      await abrir(tester, const PantallaFanfics());

      expect(find.text('Acá van los fanfics.'), findsOneWidget);
      expect(find.text('Agregar un fanfic'), findsOneWidget);
      expect(
        find.textContaining('un número que puso el sitio'),
        findsOneWidget,
      );
    });

    testWidgets('muestra los fanfics agrupados por estado', (tester) async {
      await unFic('Un fic', '111', estado: Estado.leyendo);
      await unFic('Otro fic', '222');

      await abrir(tester, const PantallaFanfics());

      expect(find.text('LEYENDO · 1'), findsOneWidget);
      expect(find.text('PENDIENTES · 1'), findsOneWidget);
    });

    testWidgets('no muestra los libros', (tester) async {
      await unLibro('Cometierra');
      await unFic('Un fic', '111');

      await abrir(tester, const PantallaFanfics());

      expect(find.textContaining('Cometierra'), findsNothing);
    });

    testWidgets('siempre hay una forma de agregar otro', (tester) async {
      await unFic('Un fic', '111');
      await abrir(tester, const PantallaFanfics());

      expect(find.text('Agregar otro'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });

  group('la biblioteca', () {
    testWidgets('no muestra fanfics en ninguna solapa', (tester) async {
      await unLibro('Cometierra', estado: Estado.leido);
      await unFic('Un fic', '111', estado: Estado.leido);

      await abrir(tester, const PantallaBiblioteca());

      expect(find.text('LEÍDOS · 1'), findsOneWidget);
      expect(find.textContaining('Un fic'), findsNothing);
    });

    testWidgets('ya no ofrece cargar fanfics desde ahí', (tester) async {
      // Ese era el punto: que se agreguen de un solo lugar. Si el botón
      // siguiera acá, alguien cargaría un fic como libro —sin enlace— y
      // se perdería la garantía contra los repetidos.
      await abrir(tester, const PantallaBiblioteca());

      expect(find.textContaining('fanfic'), findsNothing);
    });
  });
}
