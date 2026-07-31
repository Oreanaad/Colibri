import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/chile.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/animos.dart';
import 'package:colibri/tema.dart';
import 'package:colibri/widgets.dart';

Libro _libro() => Libro(id: '1', titulo: 'Cometierra', autor: 'Dolores Reyes');

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('la lista de etiquetas', () {
    test('son pocas a propósito', () {
      // Con veinte lectoras y treinta etiquetas, cada una tendría cero o
      // un uso y la función se vería muerta el día que se abre.
      expect(Animos.todas.length, lessThanOrEqualTo(15));
      expect(Animos.maximo, 3);
    });

    test('no hay repetidas', () {
      expect(Animos.todas.toSet().length, Animos.todas.length);
    });

    test('hay al menos una honesta', () {
      // Si todas fueran buenas, todos los libros se verían bien y
      // ninguna serviría para decidir.
      expect(Animos.todas, contains('me aburrió'));
    });
  });

  group('las cuatro puntuaciones', () {
    test('son independientes: miden cosas distintas', () async {
      final b = Biblioteca();
      final l = _libro()
        ..puntaje = 3
        ..lagrimas = 5
        ..romantico = 0
        ..picante = 0;
      await b.agregar(l);

      final otra = Biblioteca();
      await otra.cargar();
      final g = otra.todos.first;

      expect(g.puntaje, 3, reason: 'no es la gran novela');
      expect(g.lagrimas, 5, reason: 'pero te destrozó igual');
      expect(g.romantico, 0, reason: 'y no tiene nada de romance');
      expect(g.picante, 0);
    });

    test('romance sin picante es una combinación válida', () async {
      final b = Biblioteca();
      final l = _libro()
        ..romantico = 5
        ..picante = 0;
      await b.agregar(l);

      final otra = Biblioteca();
      await otra.cargar();
      final g = otra.todos.first;

      expect(g.romantico, 5);
      expect(g.picante, 0, reason: 'con una sola nota esto se perdía');
    });

    test('un libro viejo arranca las nuevas en cero', () {
      final l = Libro.desdeJson({
        'id': '1',
        'titulo': 'Rayuela',
        'autor': 'Julio Cortázar',
        'puntaje': 4,
      });

      expect(l.puntaje, 4);
      expect(l.lagrimas, 0);
      expect(l.romantico, 0);
      expect(l.picante, 0);
      expect(l.animos, isEmpty);
    });

    test('cada escala tiene su pregunta', () {
      for (final e in Escala.values) {
        expect(e.pregunta, isNotEmpty);
        expect(e.nombre, isNotEmpty);
      }
    });

    testWidgets('el chile se dibuja, lleno y vacío', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: construirTema(),
          home: const Scaffold(
            body: Center(child: Puntuacion(Escala.chiles, 2)),
          ),
        ),
      );

      expect(find.byType(Chile), findsNWidgets(5));
      final chiles = tester.widgetList<Chile>(find.byType(Chile)).toList();
      expect(chiles.where((c) => c.lleno).length, 2);
      expect(chiles.every((c) => c.color == Paleta.oro || c.color == Paleta.linea),
          isTrue, reason: 'las tres escalas van en oro, cambia la forma');
    });

    testWidgets('tocar la misma marca borra la puntuación', (tester) async {
      var valor = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: construirTema(),
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (_, setState) => Puntuacion(
                  Escala.lagrimas,
                  valor,
                  alTocar: (v) => setState(() => valor = v),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Icon).at(2));
      await tester.pump();
      expect(valor, 3);

      await tester.tap(find.byType(Icon).at(2));
      await tester.pump();
      expect(valor, 0, reason: 'la salida para el toque sin querer');
    });
  });

  group('elegir etiquetas', () {
    testWidgets('no deja pasar de tres', (tester) async {
      final elegidas = <String>{};

      await tester.pumpWidget(
        MaterialApp(
          theme: construirTema(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) => ChipsDeAnimo(
                elegidas: elegidas,
                alAlternar: (a) => setState(() {
                  if (!elegidas.remove(a) && elegidas.length < Animos.maximo) {
                    elegidas.add(a);
                  }
                }),
              ),
            ),
          ),
        ),
      );

      for (final a in Animos.todas.take(5)) {
        await tester.tap(find.text(a));
        await tester.pump();
      }

      expect(elegidas.length, 3, reason: 'el tope es lo que da el dato');
    });

    testWidgets('los chips no muestran cuánta gente eligió cada una',
        (tester) async {
      // Primero elegís, después ves. Si vieras los números antes, ibas a
      // poner lo que puso la mayoría.
      await tester.pumpWidget(
        MaterialApp(
          theme: construirTema(),
          home: Scaffold(
            body: ChipsDeAnimo(elegidas: const {}, alAlternar: (_) {}),
          ),
        ),
      );

      expect(find.textContaining('·'), findsNothing);
      expect(find.textContaining(RegExp(r'\d')), findsNothing);
    });
  });

  group('proponer una etiqueta', () {
    test('se guarda y sobrevive al reinicio', () async {
      final b = Biblioteca();
      await b.proponerAnimo('  Me dejó VACÍA  ');

      final otra = Biblioteca();
      await otra.cargar();
      expect(otra.animosPropuestos, ['me dejó vacía']);
    });

    test('no acepta vacías ni las que ya están', () async {
      final b = Biblioteca();
      await b.proponerAnimo('   ');
      await b.proponerAnimo('Me Destruyó');
      await b.proponerAnimo('a' * 60);

      expect(b.animosPropuestos, isEmpty);
    });
  });
}
