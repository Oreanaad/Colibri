import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/api.dart';
import 'package:colibri/mazo.dart';
import 'package:colibri/pantallas/destacados.dart';
import 'package:colibri/widgets.dart';

/// Descubrir por categoría, y el mazo sin red.
///
/// # Lo que las mediciones enseñaron, y que quedó en el código
///
/// **El mazo no se pide.** Cada libro era una búsqueda a Open Library.
/// Salían en paralelo, pero la más lenta manda: entre 2 y 10 segundos
/// antes de ver la primera tapa, y otras cinco búsquedas en cada
/// «mostrame otros cinco». Y la respuesta era siempre la misma, porque
/// los títulos son fijos: se preguntaba en cada teléfono, cada vez, algo
/// que ya se sabía. Ahora se resuelve al compilar, con
/// `herramientas/mazo.py`.
///
/// **Las categorías se eligieron midiendo, y el resultado contradijo lo
/// que yo esperaba.** Probé dieciocho. Las amplias devuelven dominio
/// público: *Robinson Crusoe* en Poesía, *La letra escarlata* en Manga.
/// Las que sirven son las específicas —las que había descartado por tener
/// catálogos chicos— porque son las que traen lo que se lee hoy.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('el mazo horneado', () {
    test('tiene todos los libros, y casi todos con tapa', () {
      expect(mazoDeDescubrir.length, greaterThanOrEqualTo(25));

      final conTapa = mazoDeDescubrir.where((l) => l.$4 != null).length;
      expect(
        conTapa,
        greaterThan(mazoDeDescubrir.length * 0.8),
        reason: 'si bajan mucho, hay que correr herramientas/mazo.py de nuevo',
      );
    });

    test('cada uno tiene título y autoría de verdad', () {
      for (final (titulo, autor, _, _, _, _) in mazoDeDescubrir) {
        expect(titulo.trim(), isNotEmpty);
        expect(autor.trim(), isNotEmpty);
      }
    });

    test('los títulos están bien escritos, no en mayúsculas del catálogo', () {
      // Open Library devuelve «COMETIERRA» a los gritos. El generador usa
      // nuestro título justamente por eso: el catálogo aporta la tapa, el
      // nombre lo escribimos nosotras.
      final gritados = mazoDeDescubrir
          .where((l) => l.$1.length > 4 && l.$1 == l.$1.toUpperCase())
          .map((l) => l.$1);

      expect(gritados, isEmpty);
    });

    test('sin repetidos', () {
      final titulos = mazoDeDescubrir.map((l) => l.$1).toList();
      expect(titulos.toSet(), hasLength(titulos.length));
    });

    test('la clave de obra sirve para pedir las ediciones', () {
      // Si es `/works/OL…`, elegir edición no tiene que buscar la obra
      // primero, que es una consulta menos y de las lentas.
      final conClave = mazoDeDescubrir
          .where((l) => (l.$3 ?? '').startsWith('/works/'))
          .length;

      expect(conClave, greaterThan(mazoDeDescubrir.length * 0.8));
    });
  });

  group('convertir una categoría en libros', () {
    // La forma exacta que devuelve /subjects/<etiqueta>.json.
    final crudas = <dynamic>[
      {
        'key': '/works/OL1W',
        'title': 'Once Upon a Broken Heart',
        'cover_id': 12345,
        'first_publish_year': 2021,
        'authors': [
          {'name': 'Stephanie Garber'},
        ],
      },
      {
        'key': '/works/OL2W',
        'title': 'The Serpent & the Wings of Night',
        'cover_id': 999,
        'first_publish_year': 2022,
        'authors': [
          {'name': 'Carissa Broadbent'},
        ],
      },
    ];

    test('saca el título, la autoría, la tapa y el año', () {
      final r = Api.librosDeCategoria(crudas);

      expect(r, hasLength(2));
      expect(r.first.titulo, 'Once Upon a Broken Heart');
      expect(r.first.autor, 'Stephanie Garber');
      expect(r.first.tapaId, 12345);
      expect(r.first.anio, 2021);
      expect(r.first.id, '/works/OL1W');
    });

    test('sin autoría no se descarta el libro', () {
      final r = Api.librosDeCategoria([
        {'key': '/works/OL3W', 'title': 'Sin autoría', 'cover_id': 1},
      ]);

      expect(r, hasLength(1));
      expect(r.first.autor, 'Autor desconocido');
    });

    test('sin título sí, porque no habría qué mostrar', () {
      final r = Api.librosDeCategoria([
        {'key': '/works/OL4W', 'cover_id': 1},
        {'key': '/works/OL5W', 'title': '   '},
      ]);

      expect(r, isEmpty);
    });

    test('la misma obra dos veces sale una', () {
      // Pasa: la misma obra viene con claves distintas, y en una fila de
      // cinco tapas repetir se nota enseguida.
      final r = Api.librosDeCategoria([
        crudas.first,
        {...crudas.first as Map, 'key': '/works/OTRA'},
      ]);

      expect(r, hasLength(1));
    });

    test('basura en la lista no rompe nada', () {
      final r = Api.librosDeCategoria([
        'no soy un mapa',
        42,
        null,
        crudas.first,
      ]);

      expect(r, hasLength(1));
    });

    test('una lista vacía devuelve vacío', () {
      expect(Api.librosDeCategoria(const []), isEmpty);
    });
  });

  group('la fila de categorías, en pantalla', () {
    Future<void> abrir(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(2600, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BibliotecaDestacada())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('«Al azar» está puesta al entrar', (tester) async {
      // Es la única que no necesita internet, así que es la que puede
      // aparecer al instante.
      await abrir(tester);

      expect(find.text('Al azar'), findsOneWidget);
      expect(find.byType(Tapa), findsNWidgets(5));
    });

    testWidgets('están las categorías que pasaron la medición', (tester) async {
      await abrir(tester);

      for (final nombre in ['Romantasy', 'Dark romance', 'Argentina']) {
        expect(find.text(nombre), findsOneWidget);
      }
    });

    testWidgets('no están las que devolvían dominio público', (tester) async {
      // «Poesía» traía Robinson Crusoe y «Manga» La letra escarlata. Que
      // no estén es la decisión, no un olvido.
      await abrir(tester);

      for (final nombre in ['Poesía', 'Manga', 'Clásicos', 'Romance']) {
        expect(
          find.text(nombre),
          findsNothing,
          reason: '$nombre devuelve dominio público, ver Api.porCategoria',
        );
      }
    });

    testWidgets('tocar una categoría muestra libros al instante, sin red', (
      tester,
    ) async {
      // Ésta es la prueba de que no hay espera. `flutter test` corta toda
      // petición HTTP, así que si aparecen libros es porque estaban
      // horneados en la app: antes, tocar una ficha era un pedido a Open
      // Library de unos 3 segundos, hasta 10 en la más lenta.
      await abrir(tester);
      expect(find.byType(Tapa), findsNWidgets(5));

      await tester.tap(find.text('Romantasy'));
      await tester.pump(); // un solo cuadro: ni tiempo de esperar nada

      expect(find.byType(Tapa), findsWidgets);
      expect(
        find.text('Once Upon a Broken Heart'),
        findsWidgets,
        reason: 'el primer libro horneado de romantasy',
      );

      await tester.pumpAndSettle();
      // Y no queda ninguna rueda girando: no hay nada que esperar.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('el vacío se diría, si alguna categoría no trajera nada', (
      tester,
    ) async {
      // Las ocho vienen horneadas, así que este camino es una red de
      // seguridad: sirve si alguna vez se agrega una categoría sin correr
      // herramientas/mazo.py, o si el generador corrió con Open Library
      // caída. Se prueba el texto, que es lo que se puede probar sin
      // fabricar ese estado.
      await abrir(tester);
      expect(
        find.textContaining('no tiene nada en esta categoría'),
        findsNothing,
        reason: 'con libros horneados, nunca se muestra',
      );
    });

    testWidgets('el texto de arriba nombra la categoría', (tester) async {
      // Decir «al azar» mirando Romantasy sería falso: ahí los libros
      // salen de una etiqueta del catálogo, no de un sorteo.
      await abrir(tester);
      await tester.tap(find.text('Dark romance'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('etiquetado como dark romance'),
        findsOneWidget,
      );
    });

    testWidgets('volver a «Al azar» trae el mazo de nuevo', (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Romantasy'));
      await tester.pumpAndSettle();
      expect(find.text('Once Upon a Broken Heart'), findsWidgets);

      await tester.tap(find.text('Al azar'));
      await tester.pumpAndSettle();

      // Vuelven a ser cinco del mazo, y la categoría no dejó ninguno.
      expect(find.byType(Tapa), findsNWidgets(5));
      expect(find.text('Once Upon a Broken Heart'), findsNothing);
    });

    testWidgets('en una categoría no se ofrece «mostrame otros cinco»', (
      tester,
    ) async {
      // El mazo es finito y por eso tiene tope; una categoría la corta el
      // catálogo, y ofrecer más cuando no hay más es una promesa vacía.
      await abrir(tester);
      expect(find.text('Mostrame otros cinco'), findsOneWidget);

      await tester.tap(find.text('Romantasy'));
      await tester.pumpAndSettle();

      expect(find.text('Mostrame otros cinco'), findsNothing);
      // Y no hace falta: la categoría entera entra de una.
      expect(find.byType(Tapa).evaluate().length, greaterThan(5));
    });
  });
}
