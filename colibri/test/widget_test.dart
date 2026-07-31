import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/tema.dart';
import 'package:colibri/widgets.dart';

Widget _envolver(Widget hijo) => MaterialApp(
  theme: construirTema(),
  home: Scaffold(body: Center(child: hijo)),
);

void main() {
  test('la clave ignora acentos, mayúsculas y puntuación', () {
    final a = Libro(id: '1', titulo: 'Pedro Páramo', autor: 'Juan Rulfo');
    final b = Libro(id: '2', titulo: 'PEDRO PARAMO', autor: 'Rulfo, Juan');
    final c = Libro(id: '3', titulo: 'Pedro Páramo', autor: 'Otra Persona');

    expect(a.clave, b.clave, reason: 'el mismo libro cargado distinto');
    expect(a.clave, isNot(c.clave), reason: 'mismo título, otro autor');
  });

  test('desdeOpenLibrary sobrevive a un resultado incompleto', () {
    final l = Libro.desdeOpenLibrary({'title': 'Cometierra'});
    expect(l.titulo, 'Cometierra');
    expect(l.autor, 'Autor desconocido');
    expect(l.tapaId, isNull);
  });

  testWidgets('el logotipo muestra las letras del secreto en oro', (
    tester,
  ) async {
    await tester.pumpWidget(_envolver(const Logotipo()));

    final texto = tester.widget<Text>(find.byType(Text));
    final tramos = (texto.textSpan! as TextSpan).children!.cast<TextSpan>();

    expect(tramos.map((t) => t.text).join(), 'colibrí');
    expect(tramos.firstWhere((t) => t.text == 'libr').style!.color, Paleta.oro);
  });

  testWidgets('un libro sin tapa igual dibuja una', (tester) async {
    await tester.pumpWidget(
      _envolver(
        Tapa(Libro(id: '1', titulo: 'Mugre rosa', autor: 'Fernanda Trías')),
      ),
    );

    expect(find.text('Mugre rosa'), findsOneWidget);
    expect(find.text('Fernanda Trías'), findsOneWidget);
  });

  testWidgets('las estrellas se pueden puntuar y despuntuar', (tester) async {
    var puntaje = 0;
    await tester.pumpWidget(
      _envolver(
        StatefulBuilder(
          builder: (_, setState) =>
              Estrellas(puntaje, alTocar: (p) => setState(() => puntaje = p)),
        ),
      ),
    );

    await tester.tap(find.byType(Icon).at(3)); // cuarta estrella
    await tester.pump();
    expect(puntaje, 4);

    await tester.tap(find.byType(Icon).at(3)); // la misma otra vez
    await tester.pump();
    expect(puntaje, 0, reason: 'tocar la misma estrella borra el puntaje');
  });
}
