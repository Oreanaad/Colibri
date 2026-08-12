import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/cuenta.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/nube.dart';
import 'package:colibri/pantallas/biblioteca.dart';
import 'package:colibri/pantallas/ficha.dart';
import 'package:colibri/pantallas/nota.dart';

/// Dos cosas que estaban pedidas desde hacía mucho.
///
/// # Las notas privadas
///
/// La tabla `notas` existía en el esquema desde el día que se armó, con su
/// propia regla de acceso, y la app no tenía dónde escribirlas. La razón de
/// que sea otra tabla y no una columna está escrita en
/// `servidor/esquema.sql`: **Postgres protege filas, no columnas**. Si la
/// nota fuera una columna de `lecturas`, el permiso que deja a otra persona
/// ver tu estante dejaría ver también tus notas.
///
/// Lo que se prueba acá es la mitad de esa promesa que vive en la app: que
/// la nota no se cuele en nada de lo que se comparte.
///
/// # El orden
///
/// El estante estaba siempre en orden de carga. Ordenar es una regla, así
/// que la regla se prueba sola —con listas escritas a mano, sin tocar el
/// disco— y aparte se prueba que la pantalla la use y la recuerde.
void main() {
  Libro libro(
    String titulo,
    String autor, {
    DateTime? terminado,
    Estado estado = Estado.leido,
  }) => Libro(
    id: titulo,
    titulo: titulo,
    autor: autor,
    terminado: terminado,
    estado: estado,
  );

  group('ordenar, como regla pura', () {
    final lista = [
      libro('Rayuela', 'Julio Cortázar', terminado: DateTime(2026, 3, 10)),
      libro('Cometierra', 'Dolores Reyes'),
      libro('Bestiario', 'Cortázar, Julio', terminado: DateTime(2026, 1, 5)),
      libro(
        'Las malas',
        'Camila Sosa Villada',
        terminado: DateTime(2026, 5, 1),
      ),
    ];

    test('por título, sin importar acentos ni mayúsculas', () {
      final r = ordenados(lista, Orden.titulo).map((l) => l.titulo);
      expect(r, ['Bestiario', 'Cometierra', 'Las malas', 'Rayuela']);
    });

    test('por autoría agrupa al mismo autor escrito de dos formas', () {
      // «Julio Cortázar» y «Cortázar, Julio» son la misma persona, y en un
      // estante sus libros van juntos. Es la misma cuenta que usa
      // claveDeObra para saber si dos fichas son el mismo libro.
      final r = ordenados(lista, Orden.autoria).map((l) => l.titulo).toList();

      final i = r.indexOf('Bestiario');
      final j = r.indexOf('Rayuela');
      expect(
        (i - j).abs(),
        1,
        reason: 'los dos de Cortázar tienen que quedar pegados: $r',
      );
    });

    test('del mismo autor, por título, para que no baile el orden', () {
      final r = ordenados(lista, Orden.autoria).map((l) => l.titulo).toList();
      expect(r.indexOf('Bestiario'), lessThan(r.indexOf('Rayuela')));
    });

    test('por cuándo lo leí, el más reciente primero', () {
      final r = ordenados(lista, Orden.terminados).map((l) => l.titulo);
      expect(r.take(3), ['Las malas', 'Rayuela', 'Bestiario']);
    });

    test('los que no terminaste van al final, no al principio', () {
      // Es el detalle que importa: un null suelto ordena primero, y
      // ordenar «por cuándo lo leí» te taparía los que sí leíste con una
      // pila de pendientes.
      final r = ordenados(lista, Orden.terminados);
      expect(r.last.titulo, 'Cometierra');
      expect(r.last.terminado, isNull);
    });

    test('«como los cargué» no toca nada', () {
      final r = ordenados(lista, Orden.cargados).map((l) => l.titulo);
      expect(r, lista.map((l) => l.titulo));
    });

    test('nunca modifica la lista que le pasan', () {
      final original = [...lista];
      ordenados(lista, Orden.titulo);
      ordenados(lista, Orden.autoria);

      expect(lista.map((l) => l.titulo), original.map((l) => l.titulo));
    });

    test('una lista vacía y una de uno no explotan', () {
      for (final o in Orden.values) {
        expect(ordenados(const [], o), isEmpty);
        expect(ordenados([lista.first], o), hasLength(1));
      }
    });
  });

  group('el orden, en la pantalla', () {
    Future<void> abrir(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await biblioteca.cargar();
      for (final l in [...biblioteca.todos]) {
        await biblioteca.quitar(l);
      }
      await cuenta.crear(usuario: 'lectora', nombre: 'L');
      await sesion.cargar();

      // Nueve, que es más que el mínimo desde el que aparece el control.
      for (final t in [
        'Zorro',
        'Alba',
        'Mar',
        'Bruma',
        'Noche',
        'Lila',
        'Oro',
        'Tapa',
        'Luz',
      ]) {
        await biblioteca.agregar(libro(t, 'Alguien', estado: Estado.pendiente));
      }

      await tester.binding.setSurfaceSize(const Size(500, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PantallaBiblioteca())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('arranca en «Recientes» y ofrece los cuatro', (tester) async {
      await abrir(tester);

      expect(find.text('Recientes'), findsOneWidget);

      await tester.tap(find.text('Recientes'));
      await tester.pumpAndSettle();

      for (final o in Orden.values) {
        expect(find.text(o.nombre), findsOneWidget);
      }
    });

    testWidgets('elegir por título reordena de verdad la grilla', (
      tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.text('Recientes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Por título'));
      await tester.pumpAndSettle();

      // La posición en pantalla, no el orden de una lista: es lo único que
      // prueba que la pantalla usa la regla.
      final alba = tester.getTopLeft(find.text('Alba').first);
      final zorro = tester.getTopLeft(find.text('Zorro').first);
      expect(
        alba.dy < zorro.dy || (alba.dy == zorro.dy && alba.dx < zorro.dx),
        isTrue,
        reason: 'Alba tiene que estar antes que Zorro',
      );
    });

    testWidgets('el orden elegido queda recordado', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Recientes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Por autoría'));
      await tester.pumpAndSettle();

      expect(sesion.orden, Orden.autoria);

      // Y sobrevive a volver a cargar la sesión, que es lo que pasa al
      // abrir la app de nuevo.
      await sesion.cargar();
      expect(sesion.orden, Orden.autoria);
    });

    testWidgets('se guarda por nombre, no por número', (tester) async {
      // El comentario de Sesion lo dejó escrito después de que las solapas
      // se corrieran dos veces: un número solo significa algo si la lista
      // no cambia nunca.
      await abrir(tester);
      await tester.tap(find.text('Recientes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Por título'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('colibri.sesion.v3'),
        contains('"orden":"titulo"'),
      );
    });

    testWidgets('un orden que la app ya no conoce vuelve al de fábrica', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'colibri.sesion.v3': '{"seccion":0,"solapa":0,"orden":"por_color"}',
      });

      await sesion.cargar();

      expect(sesion.orden, Orden.cargados);
    });

    testWidgets('con pocos libros no aparece el control', (tester) async {
      // Con cuatro libros los ves todos de un vistazo, y un botón de
      // ordenar es un botón que solo ocupa lugar.
      SharedPreferences.setMockInitialValues({});
      await biblioteca.cargar();
      for (final l in [...biblioteca.todos]) {
        await biblioteca.quitar(l);
      }
      await cuenta.crear(usuario: 'lectora', nombre: 'L');
      await biblioteca.agregar(libro('Uno', 'Alguien'));

      await tester.binding.setSurfaceSize(const Size(500, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PantallaBiblioteca())),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);
    });
  });

  group('las notas privadas', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await biblioteca.cargar();
      for (final l in [...biblioteca.todos]) {
        await biblioteca.quitar(l);
      }
      await cuenta.crear(usuario: 'lectora', nombre: 'L');
    });

    test('son un campo aparte de la reseña', () {
      final l = libro('Un libro', 'Alguien')
        ..resena = 'Lo que le cuento a otra persona.'
        ..nota = 'Lo que anoto para mí.';

      expect(l.tieneResena, isTrue);
      expect(l.tieneNota, isTrue);
      expect(l.resena, isNot(contains('para mí')));
    });

    test('sobreviven a guardar y volver a leer del teléfono', () {
      final l = libro('Un libro', 'Alguien')..nota = 'Releer el capítulo 12.';
      final vuelto = Libro.desdeJson(l.aJson());

      expect(vuelto.nota, 'Releer el capítulo 12.');
    });

    test('la nota NO viaja en la fila de la lectura', () {
      // La prueba de la promesa. `lecturas` es la tabla que algún día va a
      // ser visible para otra persona; si la nota se colara ahí, la regla
      // de la base no podría protegerla, porque Postgres protege filas y
      // no columnas.
      final l = libro('Un libro', 'Alguien')
        ..resena = 'Mi reseña'
        ..nota = 'ESTO ES SECRETO';

      final fila = filaDeLectura(l, perfilId: 'perfil-1', edicionId: 'e-1');

      expect(fila.toString(), isNot(contains('ESTO ES SECRETO')));
      expect(fila.keys, isNot(contains('nota')));
      // Y la reseña sí, porque para eso está.
      expect(fila['resena'], 'Mi reseña');
    });

    test('vuelve de la nube desde su propia tabla embebida', () {
      final l = libroDeFila({
        'estado': 'leido',
        'edicion_id': 'e-1',
        'ediciones': {
          'id': 'e-1',
          'titulo': 'Un libro',
          'obras': {'autor': 'Alguien'},
        },
        'fanfics': null,
        'notas': {'texto': 'Mi nota de vuelta'},
      });

      expect(l!.nota, 'Mi nota de vuelta');
    });

    test('sin nota en la nube, el libro vuelve sin nota', () {
      final l = libroDeFila({
        'estado': 'leido',
        'edicion_id': 'e-1',
        'ediciones': {
          'id': 'e-1',
          'titulo': 'Un libro',
          'obras': {'autor': 'Alguien'},
        },
        'fanfics': null,
        'notas': null,
      });

      expect(l!.nota, isNull);
    });

    testWidgets('se escribe desde la ficha y queda guardada', (tester) async {
      final l = libro('Un libro', 'Alguien');
      await biblioteca.agregar(l);

      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: PantallaFicha(l)));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Anotar algo para mí'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Anotar algo para mí'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Releer el capítulo 12.');
      await tester.tap(find.text('Guardar nota'));
      await tester.pumpAndSettle();

      expect(
        biblioteca.buscarPorClave(l.clave)!.nota,
        'Releer el capítulo 12.',
      );

      // El aviso tiene su propio reloj para cerrarse solo, aparte del que
      // usa Flutter. Sin dejarlo terminar, la prueba se queda con un
      // temporizador pendiente y falla al cerrar, aunque la pantalla haya
      // hecho exactamente lo que tenía que hacer. Mismo caso que en
      // pantallas_cuenta_test.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('la pantalla dice en palabras que no se comparte', (
      tester,
    ) async {
      // No alcanza con el color. Prometer privacidad con un tono de gris es
      // pedirle a alguien que adivine una promesa.
      final l = libro('Un libro', 'Alguien');
      await biblioteca.agregar(l);

      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: PantallaNota(l)));
      await tester.pumpAndSettle();

      expect(find.textContaining('no se comparte nunca'), findsOneWidget);
    });

    testWidgets('una nota escrita se muestra marcada como privada', (
      tester,
    ) async {
      final l = libro('Un libro', 'Alguien')..nota = 'Mi nota';
      await biblioteca.agregar(l);

      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NotaPropia(l, alTocar: () {})),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SOLO VOS VES ESTO'), findsOneWidget);
      expect(find.text('Mi nota'), findsOneWidget);
    });
  });
}
