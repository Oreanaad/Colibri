import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/vitrina.dart';
import 'package:colibri/pantallas/estantes.dart';
import 'package:colibri/vitrina.dart';
import 'package:colibri/widgets.dart';

/// «Armá tu estante»: el mueble decorable.
///
/// # Qué se prueba
///
/// Lo que se puede romper sin que se vea: el reparto de libros por repisa,
/// que las cuentas del ancho incluyan los adornos, y que la decoración
/// sobreviva a guardar y volver a leer.
///
/// Lo que no se puede probar acá es si queda linda. Eso se mira.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Libro libro(String t, {int? paginas}) =>
      Libro(id: t, titulo: t, autor: 'Alguien', paginas: paginas);

  List<Libro> muchos(int n) => [
    for (var i = 0; i < n; i++) libro('Libro $i', paginas: 300 + i * 40),
  ];

  Future<void> dibujar(
    WidgetTester tester,
    List<Libro> libros,
    Vitrina v, {
    double ancho = 380,
  }) async {
    await tester.binding.setSurfaceSize(Size(ancho + 40, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: ancho,
              child: MuebleDeEstante(
                libros: libros,
                vitrina: v,
                alTocar: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('el mueble se dibuja sin desbordar', () {
    testWidgets('con adornos, que también ocupan lugar', (tester) async {
      // El bug que esto atrapa: la primera versión repartía los libros y
      // **después** ponía los adornos al final de la fila. Desbordaba 63
      // píxeles, porque la planta y el gato no entraban en el lugar que ya
      // se habían llevado los libros.
      await dibujar(
        tester,
        muchos(12),
        const Vitrina(
          repisas: 3,
          adornos: {Adorno.luces, Adorno.planta, Adorno.gato, Adorno.hojas},
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('con las seis repisas y los seis adornos', (tester) async {
      await dibujar(
        tester,
        muchos(30),
        Vitrina(repisas: 6, adornos: Adorno.values.toSet()),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('en una pantalla angosta', (tester) async {
      await dibujar(
        tester,
        muchos(10),
        const Vitrina(adornos: {Adorno.planta, Adorno.gato}),
        ancho: 300,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('con todos de tapa, que son más anchos que los lomos', (
      tester,
    ) async {
      final libros = muchos(8);
      await dibujar(
        tester,
        libros,
        Vitrina(
          repisas: 3,
          adornos: const {Adorno.planta},
          deTapa: {for (final l in libros) l.clave},
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('las repisas', () {
    testWidgets('se dibujan todas, incluso las vacías', (tester) async {
      // Un mueble de cinco repisas con dos libros sigue siendo un mueble de
      // cinco repisas: si se dibujaran solo las que tienen algo, elegir el
      // número no haría nada visible.
      await dibujar(tester, muchos(2), const Vitrina(repisas: 5));

      // Una tabla por repisa. Se cuentan por su alto, que es fijo.
      final tablas = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.constraints?.maxHeight == 7)
          .length;
      expect(tablas, 5);
    });

    testWidgets('ningún libro queda afuera', (tester) async {
      // Con más libros que lugar, la última repisa aguanta lo que sobre.
      // Esconder libros sin decirlo sería peor que una repisa apretada.
      await dibujar(tester, muchos(40), const Vitrina(repisas: 2));

      expect(find.byType(GestureDetector), findsNWidgets(40));
    });
  });

  group('la postura de cada libro', () {
    testWidgets('de lomo por defecto', (tester) async {
      await dibujar(tester, muchos(3), const Vitrina());
      expect(find.byType(Tapa), findsNothing);
    });

    testWidgets('de tapa el que vos elegiste', (tester) async {
      final libros = muchos(3);
      await dibujar(tester, libros, Vitrina(deTapa: {libros[1].clave}));

      expect(find.byType(Tapa), findsOneWidget);
    });

    test('se guarda por libro y no por posición', () {
      // Si se guardara la posición, sacar un libro del estante le cambiaría
      // la postura a todos los que quedan detrás.
      final v = const Vitrina().alternarPostura('uno|autor');

      expect(v.posturaDe('uno|autor'), Postura.tapa);
      expect(v.posturaDe('otro|autor'), Postura.lomo);
    });
  });

  group('se puede encontrar', () {
    testWidgets('la solapa vacía cuenta que los estantes se decoran', (
      tester,
    ) async {
      // El bug que esto atrapa no era de código: el armador vive adentro de
      // un estante, así que quien no tiene ninguno no tenía forma de
      // enterarse de que existe. Se reportó como «no veo en la web el
      // cambio para hacerlo». Estaba publicado y era invisible.
      SharedPreferences.setMockInitialValues({});
      await biblioteca.cargar();
      for (final e in [...biblioteca.estantes]) {
        await biblioteca.borrarEstante(e);
      }

      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VistaEstantes())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('lo armás como un mueble'), findsOneWidget);
      expect(find.textContaining('repisas'), findsOneWidget);
      expect(find.text('Armar mi primer estante'), findsOneWidget);
    });
  });

  group('lo que se guarda', () {
    test('sobrevive a guardar y volver a leer', () async {
      SharedPreferences.setMockInitialValues({});
      await vitrinas.cargar();

      await vitrinas.guardar(
        'Fantasía épica',
        const Vitrina(
          repisas: 5,
          fondo: FondoDeVitrina.bosque,
          adornos: {Adorno.planta, Adorno.gato},
          deTapa: {'uno|a'},
        ),
      );

      await vitrinas.cargar();
      final v = vitrinas.de('Fantasía épica');

      expect(v.repisas, 5);
      expect(v.fondo, FondoDeVitrina.bosque);
      expect(v.adornos, {Adorno.planta, Adorno.gato});
      expect(v.deTapa, {'uno|a'});
    });

    test('cada estante tiene la suya', () async {
      // Un estante de terror y uno de poesía no se decoran igual, y esa es
      // la mitad de la gracia.
      SharedPreferences.setMockInitialValues({});
      await vitrinas.cargar();

      await vitrinas.guardar(
        'Terror',
        const Vitrina(fondo: FondoDeVitrina.vino),
      );
      await vitrinas.guardar(
        'Poesía',
        const Vitrina(fondo: FondoDeVitrina.niebla),
      );

      expect(vitrinas.de('Terror').fondo, FondoDeVitrina.vino);
      expect(vitrinas.de('Poesía').fondo, FondoDeVitrina.niebla);
    });

    test('renombrar el estante se lleva su decoración', () async {
      SharedPreferences.setMockInitialValues({});
      await vitrinas.cargar();
      await vitrinas.guardar('Viejo', const Vitrina(repisas: 6));

      await vitrinas.renombrar('Viejo', 'Nuevo');

      expect(vitrinas.de('Nuevo').repisas, 6);
      expect(vitrinas.de('Viejo').repisas, 3, reason: 'vuelve a la de fábrica');
    });

    test('un estante sin decoración usa la de fábrica', () async {
      SharedPreferences.setMockInitialValues({});
      await vitrinas.cargar();

      final v = vitrinas.de('Nunca decorado');
      expect(v.repisas, 3);
      expect(v.adornos, {Adorno.luces});
    });

    test('un adorno que la app ya no conoce no rompe el estante', () {
      // Perder la decoración es molesto; no poder abrir el estante es peor.
      final v = Vitrina.desdeJson({
        'repisas': 4,
        'fondo': 'un_color_inventado',
        'adornos': ['planta', 'dragon_de_peluche'],
        'deTapa': ['uno|a', 42],
      });

      expect(v.repisas, 4);
      expect(v.fondo, FondoDeVitrina.noche, reason: 'vuelve al de fábrica');
      expect(v.adornos, {Adorno.planta});
      expect(v.deTapa, {'uno|a'}, reason: 'lo que no es texto se saltea');
    });

    test('el número de repisas no se puede pasar de los topes', () {
      expect(const Vitrina().copiarCon(repisas: 99).repisas, 6);
      expect(const Vitrina().copiarCon(repisas: 0).repisas, 2);
      expect(Vitrina.desdeJson({'repisas': 300}).repisas, 6);
    });
  });
}
