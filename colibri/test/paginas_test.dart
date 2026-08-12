import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/cuenta.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/ficha.dart';

/// Escribir en qué página vas y cuántas tiene tu edición.
///
/// # El bug que esto atrapa
///
/// La ficha tenía, en su `initState`:
///
///     l.paginas ??= 320; // la demo necesita un total para mostrar el avance
///
/// El comentario decía «para mostrar», pero no mostraba: **le escribía 320
/// páginas al libro y quedaba guardado**. Abrir un libro cuyo catálogo no
/// trae el total le inventaba uno para siempre, y a partir de ahí el
/// porcentaje de avance y el total de páginas leídas del perfil contaban
/// ese número como si fuera un dato.
///
/// Y no se podía corregir: el avance era solo un deslizador, sin ningún
/// lugar donde escribir. Con un libro de 800 páginas, llegar arrastrando a
/// la 437 exacta no se puede, y 437 es justo el número que alguien quiere
/// anotar cuando marca la página y cierra el libro.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
    await cuenta.crear(usuario: 'lectora', nombre: 'L');
  });

  Future<Libro> abrir(WidgetTester tester, Libro libro) async {
    await biblioteca.agregar(libro);
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(home: PantallaFicha(libro)));
    await tester.pumpAndSettle();
    return libro;
  }

  group('abrir un libro no le inventa páginas', () {
    testWidgets('sin total en el catálogo, sigue sin total', (tester) async {
      final libro = Libro(
        id: '1',
        titulo: 'Sin páginas anotadas',
        autor: 'Alguien',
        estado: Estado.leyendo,
      );
      expect(libro.paginas, isNull, reason: 'así viene del catálogo');

      await abrir(tester, libro);

      expect(
        biblioteca.buscarPorClave(libro.clave)!.paginas,
        isNull,
        reason: 'abrir la ficha no puede escribirle un total inventado',
      );
    });

    testWidgets('y lo dice en vez de dibujar una barra falsa', (tester) async {
      await abrir(
        tester,
        Libro(
          id: '1',
          titulo: 'Sin páginas anotadas',
          autor: 'Alguien',
          estado: Estado.leyendo,
        ),
      );

      expect(find.byType(Slider), findsNothing);
      expect(
        find.textContaining('no dice cuántas páginas'),
        findsOneWidget,
        reason: 'el vacío se dice; una barra sobre un total inventado miente',
      );
    });

    testWidgets('con total, sí hay barra', (tester) async {
      await abrir(
        tester,
        Libro(
          id: '1',
          titulo: 'Con páginas',
          autor: 'Alguien',
          estado: Estado.leyendo,
          paginas: 254,
          paginaActual: 120,
        ),
      );

      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('120 de 254'), findsOneWidget);
    });
  });

  group('escribir la página y corregir el total', () {
    Future<void> abrirLaHoja(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
    }

    testWidgets('se puede escribir un número exacto', (tester) async {
      final libro = await abrir(
        tester,
        Libro(
          id: '1',
          titulo: 'Un libro largo',
          autor: 'Alguien',
          estado: Estado.leyendo,
          paginas: 800,
          paginaActual: 10,
        ),
      );

      await abrirLaHoja(tester);
      // 437 arrastrando un deslizador de 800 es imposible de acertar.
      await tester.enterText(find.byType(TextField).first, '437');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(biblioteca.buscarPorClave(libro.clave)!.paginaActual, 437);
    });

    testWidgets('se puede corregir el total de tu edición', (tester) async {
      // El caso de verdad: el catálogo dice 352 porque anotó la de tapa
      // dura, y el ejemplar que alguien tiene es la de bolsillo, de 480.
      final libro = await abrir(
        tester,
        Libro(
          id: '1',
          titulo: 'Otra edición',
          autor: 'Alguien',
          estado: Estado.leyendo,
          paginas: 352,
        ),
      );

      await abrirLaHoja(tester);
      await tester.enterText(find.byType(TextField).last, '480');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(biblioteca.buscarPorClave(libro.clave)!.paginas, 480);
    });

    testWidgets('poner el total donde no había desbloquea la barra', (
      tester,
    ) async {
      await abrir(
        tester,
        Libro(
          id: '1',
          titulo: 'Sin páginas anotadas',
          autor: 'Alguien',
          estado: Estado.leyendo,
        ),
      );
      expect(find.byType(Slider), findsNothing);

      await abrirLaHoja(tester);
      await tester.enterText(find.byType(TextField).last, '300');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('una página mayor que el total no se guarda', (tester) async {
      final libro = await abrir(
        tester,
        Libro(
          id: '1',
          titulo: 'Un libro',
          autor: 'Alguien',
          estado: Estado.leyendo,
          paginas: 254,
          paginaActual: 100,
        ),
      );

      await abrirLaHoja(tester);
      await tester.enterText(find.byType(TextField).first, '900');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('no existe en un libro de 254'),
        findsOneWidget,
      );
      expect(biblioteca.buscarPorClave(libro.clave)!.paginaActual, 100);
    });

    testWidgets(
      'bajar el total debajo de tu página avisa, no lo arregla solo',
      (tester) async {
        // Pasa de verdad: arrastrás el deslizador hasta el final con el total
        // viejo de 800 y después corregís el total a 250.
        //
        // Acá la app podría recortar sola la página a 250, y estaría
        // perdiendo dónde ibas sin avisar. Prefiere decir que los dos números
        // no cierran y dejar que decidas cuál está mal: capaz el total nuevo
        // es el equivocado.
        final libro = await abrir(
          tester,
          Libro(
            id: '1',
            titulo: 'Un libro',
            autor: 'Alguien',
            estado: Estado.leyendo,
            paginas: 800,
            paginaActual: 800,
          ),
        );

        await abrirLaHoja(tester);
        await tester.enterText(find.byType(TextField).first, '800');
        await tester.enterText(find.byType(TextField).last, '250');
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('no existe en un libro de 250'),
          findsOneWidget,
        );

        final guardado = biblioteca.buscarPorClave(libro.clave)!;
        expect(guardado.paginas, 800, reason: 'no se guardó nada');
        expect(guardado.paginaActual, 800);
      },
    );
  });

  group('las reseñas de la comunidad', () {
    testWidgets('dice que todavía no hay, en vez de inventar tres', (
      tester,
    ) async {
      // Había tres reseñas firmadas con nombres de personas y sin ningún
      // cartel que dijera que eran de mentira. Puestas en la ficha de
      // cualquier libro, elogiaban «la mitad del medio, cuando aparece la
      // casa» de novelas que no tienen ninguna casa.
      await abrir(
        tester,
        Libro(
          id: '1',
          titulo: 'Cualquier libro',
          autor: 'Alguien',
          estado: Estado.leyendo,
          paginas: 254,
        ),
      );

      // La ficha es una lista perezosa: lo que está más abajo no existe
      // hasta que se llega. Hay que desplazarse, igual que una persona.
      // Se baja hasta el rótulo de la sección y no hasta una solapa: las
      // solapas ahora solo aparecen si hay reseñas de las dos clases, así
      // que no sirven de ancla.
      await tester.scrollUntilVisible(
        find.text('RESEÑAS DE LA COMUNIDAD'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Todavía no hay reseñas de este libro'),
        findsOneWidget,
      );
      for (final inventada in ['Caro Vidal', 'Juli Peralta', 'Mara Giménez']) {
        expect(
          find.textContaining(inventada),
          findsNothing,
          reason: '$inventada no existe y no opinó de este libro',
        );
      }
    });

    testWidgets('sin reseñas no hay solapas de spoiler que mostrar', (
      tester,
    ) async {
      // Dejaron de ser tres y pasaron a ser dos, y solo aparecen cuando hay
      // reseñas de las dos clases: un candado sobre una habitación vacía es
      // peor que no tener la puerta. Ver _Capas en ficha.dart.
      await abrir(
        tester,
        Libro(
          id: '1',
          titulo: 'Cualquier libro',
          autor: 'Alguien',
          estado: Estado.leyendo,
          paginas: 254,
        ),
      );

      // Se baja hasta el rótulo de la sección y no hasta una solapa: las
      // solapas ahora solo aparecen si hay reseñas de las dos clases, así
      // que no sirven de ancla.
      await tester.scrollUntilVisible(
        find.text('RESEÑAS DE LA COMUNIDAD'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sin spoilers'), findsNothing);
      expect(find.textContaining('Hasta la mitad'), findsNothing);
    });
  });
}
