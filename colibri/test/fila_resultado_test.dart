import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/buscar.dart';

/// La fila de un resultado de búsqueda.
///
/// Existe porque alguien dijo «no veo el más». La única forma de contestar
/// eso sin adivinar es dibujar la fila y preguntarle a Flutter qué hay.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
  });

  Libro cometierra() =>
      Libro(id: '1', titulo: 'Cometierra', autor: 'Dolores Reyes');

  Future<void> dibujar(WidgetTester tester, Libro libro, {double ancho = 390}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: ancho, child: FilaDeResultado(libro)),
          ),
        ),
      ),
    );
  }

  testWidgets('un libro que no tenés muestra el más', (tester) async {
    await dibujar(tester, cometierra());

    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('el más se puede tocar', (tester) async {
    await dibujar(tester, cometierra());

    // Que esté dibujado no alcanza: si algo lo tapa, no se puede tocar.
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(find.text('¿Dónde lo ponés?'), findsOneWidget);
  });

  testWidgets('un libro que ya tenés muestra el estante', (tester) async {
    final libro = cometierra();
    await biblioteca.agregar(libro);
    await biblioteca.cambiarEstado(libro, Estado.leyendo);

    await dibujar(tester, libro);

    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    expect(find.text('Leyendo'), findsOneWidget);
  });

  testWidgets('entra en una pantalla angosta sin desbordarse', (tester) async {
    // Un título largo empujando: si la fila se pasa de ancho, Flutter
    // marca el desborde y lo que sobra queda fuera de la pantalla. Que es
    // exactamente cómo se vería un más que no está.
    await dibujar(
      tester,
      Libro(
        id: '2',
        titulo: 'Un título larguísimo que ocupa varios renglones seguidos',
        autor: 'Una autoría con nombre muy largo también',
        editorial: 'Una editorial de nombre interminable',
        anio: 2019,
      ),
      ancho: 320,
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('debajo de los resultados hay salida para cargarlo a mano', (
    tester,
  ) async {
    // Este renglón existía desde el primer día y no se dibujó nunca: la
    // lista decía tener tantos elementos como resultados, y el renglón
    // estaba escrito para la posición siguiente, que nunca se pedía.
    //
    // Lo que se perdía no era decorativo. Es la única salida cuando el
    // catálogo no tiene tu edición, que es la mitad de las veces con la
    // narrativa de acá.
    final libros = [
      for (var i = 0; i < 3; i++)
        Libro(id: '$i', titulo: 'Libro $i', autor: 'Alguien'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: libros.length + 1,
            itemBuilder: (_, i) => i == libros.length
                ? const Text('¿Ninguno es el que tenés en la mano?')
                : FilaDeResultado(libros[i]),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add_circle_outline), findsNWidgets(3));
    expect(find.text('¿Ninguno es el que tenés en la mano?'), findsOneWidget);
  });
}
