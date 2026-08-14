import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/compartir_resena.dart';
import 'package:colibri/widgets.dart';

/// La reseña convertida en imagen para compartir.
///
/// # De dónde salió
///
/// De las plantillas que circulan entre lectoras: una hoja con la tapa, las
/// fechas, las estrellas y el texto escrito a mano. Lo que hacen esas
/// plantillas es convertir «leí un libro» en algo que se puede mostrar.
///
/// # Qué se prueba
///
/// Sobre todo **lo que no sale**. Una imagen se comparte y no se vuelve
/// atrás: lo que se filtre ahí, se filtró para siempre. Por eso la primera
/// prueba de este archivo es que la nota privada no aparece.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Libro conTodo() => Libro(
    id: '1',
    titulo: 'Fuego y sangre',
    autor: 'George R. R. Martin',
    anio: 2018,
    paginas: 880,
    estado: Estado.leido,
    puntaje: 5,
    lagrimas: 2,
    romantico: 1,
    picante: 3,
    empezado: DateTime(2025, 12, 24),
    terminado: DateTime(2026, 3, 25),
    resena: 'Una narrativa muy buena con historias y personajes increíbles.',
    animos: ['no pude parar', 'me dejó pensando'],
    estantes: {'Fantasía épica'},
    personajes: ['Rhaenyra'],
    nota: 'ESTO ES MI NOTA PRIVADA',
  );

  Future<void> dibujar(WidgetTester tester, Libro libro) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: PlacaDeResena(libro: libro),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('lo que NO sale en la imagen', () {
    testWidgets('la nota privada, nunca', (tester) async {
      // La prueba más importante del archivo. Una imagen compartida no se
      // vuelve atrás: lo que se filtre ahí, se filtró para siempre.
      await dibujar(tester, conTodo());

      expect(find.textContaining('NOTA PRIVADA'), findsNothing);
      expect(find.textContaining('ESTO ES MI'), findsNothing);
    });

    testWidgets('ni siquiera con la nota larga y la reseña vacía', (
      tester,
    ) async {
      // El caso donde más tentador sería «llenar el hueco con algo».
      final l = conTodo()
        ..resena = null
        ..nota = 'Una nota larguísima que ocuparía perfecto ese lugar vacío.';

      await dibujar(tester, l);

      expect(find.textContaining('larguísima'), findsNothing);
    });
  });

  group('lo que sí sale', () {
    testWidgets('el título, la autoría y los datos', (tester) async {
      await dibujar(tester, conTodo());

      expect(find.text('Fuego y sangre'), findsWidgets);
      // Dos veces: dentro de la tapa dibujada y como dato al lado. La
      // tapa generada escribe el título y la autoría encima.
      expect(find.text('George R. R. Martin'), findsWidgets);
      // El año y las páginas van en un renglón: dos números en dos
      // renglones era gastar alto en nada.
      expect(find.text('2018  ·  880 páginas'), findsOneWidget);
    });

    testWidgets('las fechas y cuánto te llevó', (tester) async {
      await dibujar(tester, conTodo());

      // Con flecha y no con dos rótulos: se lee de un vistazo y ocupa un
      // renglón donde «EMPECÉ / TERMINÉ» ocupaba cuatro.
      expect(find.textContaining('→'), findsOneWidget);
      // Del 24/12 al 25/3, contando los dos extremos.
      expect(find.textContaining('me llevó'), findsOneWidget);
    });

    testWidgets('la reseña', (tester) async {
      await dibujar(tester, conTodo());
      expect(find.textContaining('personajes increíbles'), findsOneWidget);
    });

    testWidgets('cómo te dejó, y en qué estante lo guardaste', (tester) async {
      await dibujar(tester, conTodo());

      expect(find.text('no pude parar'), findsOneWidget);
      expect(find.text('me dejó pensando'), findsOneWidget);
      expect(find.text('Fantasía épica'), findsOneWidget);
    });

    testWidgets('las escalas van con su nombre, no solo el dibujo', (
      tester,
    ) async {
      // Una gota azul no dice «lágrimas» si no lo sabés de antes, y quien
      // ve esta imagen es justamente alguien que nunca abrió Colibrí.
      await dibujar(tester, conTodo());

      // En mayúsculas y debajo de cada escala: es un pie de ficha, no un
      // formulario con etiquetas a la izquierda.
      for (final n in ['PUNTAJE', 'LÁGRIMAS', 'ROMANCE', 'PICANTE']) {
        expect(find.text(n), findsOneWidget);
      }
    });
  });

  group('las cuatro escalas', () {
    testWidgets('salen las que puntuaste', (tester) async {
      await dibujar(tester, conTodo());

      // Las cuatro tienen valor en este libro.
      expect(find.byType(Puntuacion), findsNWidgets(4));
    });

    testWidgets('las que no puntuaste no salen', (tester) async {
      // Cinco estrellas vacías se leen como un cero, y no es cero: es que
      // no dijiste nada. Es la misma regla que en la grilla del estante.
      final l = conTodo()
        ..lagrimas = 0
        ..romantico = 0
        ..picante = 0;

      await dibujar(tester, l);

      expect(find.byType(Puntuacion), findsOneWidget);
    });

    testWidgets('sin ninguna puntuada, lo dice', (tester) async {
      final l = conTodo()
        ..puntaje = 0
        ..lagrimas = 0
        ..romantico = 0
        ..picante = 0;

      await dibujar(tester, l);

      // El bloque entero desaparece: un recuadro que dice «sin puntuar»
      // es un recuadro ocupando lugar para decir que no hay nada.
      expect(find.byType(Puntuacion), findsNothing);
    });
  });

  group('los casos que rompen una plantilla de papel', () {
    testWidgets('un libro sin fechas ni páginas no deja huecos', (
      tester,
    ) async {
      final l = Libro(id: '1', titulo: 'Pelado', autor: 'Alguien')
        ..resena = 'Corta.';

      await dibujar(tester, l);

      expect(tester.takeException(), isNull);
      expect(find.text('EMPECÉ'), findsNothing);
    });

    testWidgets('una reseña larguísima no desborda la placa', (tester) async {
      // El caso que rompe: una reseña de tres mil caracteres no entra en
      // una imagen a ningún tamaño legible. Se achica hasta el mínimo y de
      // ahí se recorta, en vez de dibujarse encima de todo lo demás.
      final l = conTodo()
        ..resena = List.filled(
          120,
          'Esta novela me atravesó de una forma que todavía no sé explicar.',
        ).join(' ');

      await dibujar(tester, l);

      expect(
        tester.takeException(),
        isNull,
        reason: 'una reseña larga no puede romper el dibujo',
      );
    });

    testWidgets('un título larguísimo tampoco', (tester) async {
      // `titulo` es final, así que el libro se arma con él puesto: es un
      // caso de verdad, porque cargar un libro a mano deja escribir
      // cualquier cosa.
      final l = Libro(
        id: '1',
        titulo:
            'Un título absurdamente largo que ninguna tapa real tendría '
            'pero que alguien puede escribir al cargar un libro a mano',
        autor: 'Alguien con un nombre igual de largo, y dos apellidos',
        puntaje: 5,
      )..resena = 'Corta.';

      await dibujar(tester, l);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin reseña se dibuja igual', (tester) async {
      final l = conTodo()..resena = null;

      await dibujar(tester, l);
      expect(tester.takeException(), isNull);
      // Cambia el rótulo: sin reseña la placa no es «mi reseña», es el
      // libro que leí. Y el hueco se llena con el puntaje en palabras.
      expect(find.text('LO QUE LEÍ'), findsOneWidget);
      expect(find.text('De los que no se prestan'), findsOneWidget);
    });

    testWidgets('con reseña, el rótulo es el otro', (tester) async {
      await dibujar(tester, conTodo());
      expect(find.text('MI RESEÑA'), findsOneWidget);
    });
  });

  group('los tres fondos y los dos formatos', () {
    testWidgets('ninguna combinación rompe el dibujo', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final fondo in FondoDeResena.values) {
        for (final formato in FormatoDeResena.values) {
          await tester.binding.setSurfaceSize(const Size(400, 900));
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 360,
                  height: formato == FormatoDeResena.cuadrado ? 360 : 640,
                  child: PlacaDeResena(
                    libro: conTodo(),
                    fondo: fondo,
                    formato: formato,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'fondo $fondo, formato $formato',
          );
        }
      }
    });
  });
}
