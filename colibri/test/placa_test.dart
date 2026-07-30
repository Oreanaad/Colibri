import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/compartir.dart';
import 'package:colibri/tema.dart';

const _frase =
    'Vine a Comala porque me dijeron que acá vivía mi padre, un tal '
    'Pedro Páramo.';

Widget _armar({
  String texto = _frase,
  Fondo fondo = Fondo.noche,
  Formato formato = Formato.cuadrado,
}) {
  return MaterialApp(
    theme: construirTema(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          height: formato == Formato.cuadrado ? 400 : 400 * 16 / 9,
          child: Placa(
            libro: Libro(
              id: '1',
              titulo: 'Pedro Páramo',
              autor: 'Juan Rulfo',
            ),
            frase: Frase(texto: texto),
            fondo: fondo,
            formato: formato,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('la placa muestra la frase, el título y la autoría',
      (tester) async {
    await tester.pumpWidget(_armar());

    expect(find.text(_frase), findsOneWidget);
    expect(find.text('Pedro Páramo'), findsOneWidget);
    expect(find.text('Juan Rulfo'), findsOneWidget);
  });

  testWidgets('hay una sola marca, chica y con el secreto en oro',
      (tester) async {
    await tester.pumpWidget(_armar());

    final conTramos = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.textSpan != null)
        .toList();

    expect(conTramos.length, 1,
        reason: 'se sacó la marca de agua grande de atrás');

    final marca = conTramos.single.textSpan! as TextSpan;
    final tramos = marca.children!.cast<TextSpan>();
    expect(tramos.map((t) => t.text).join(), 'colibrí');
    expect(tramos.firstWhere((t) => t.text == 'libr').style!.color, isNotNull);

    // Chica de verdad: más chica que la propia autoría.
    final tamanoMarca = marca.style!.fontSize!;
    final tamanoAutor =
        tester.widget<Text>(find.text('Juan Rulfo')).style!.fontSize!;
    expect(tamanoMarca, lessThan(tamanoAutor));
  });

  testWidgets('la marca va pegada a la autoría, donde no se puede recortar',
      (tester) async {
    await tester.pumpWidget(_armar());

    final autor = tester.getBottomLeft(find.text('Juan Rulfo'));
    final marca = tester.getTopLeft(
      find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
    );

    // Justo debajo de la autoría y alineada con ella: si alguien recorta
    // la marca, se lleva puesta la cita.
    expect(marca.dy - autor.dy, lessThan(20));
    expect((marca.dx - tester.getTopLeft(find.text('Juan Rulfo')).dx).abs(),
        lessThan(2));
  });

  testWidgets('una frase larga se dibuja más chica para que entre entera',
      (tester) async {
    final corta = _armar(texto: 'Una frase corta y linda de leer siempre.');
    final larga = _armar(texto: 'a' * 400);

    await tester.pumpWidget(corta);
    final tamanoCorta = tester
        .widget<Text>(find.text('Una frase corta y linda de leer siempre.'))
        .style!
        .fontSize!;

    await tester.pumpWidget(larga);
    final tamanoLarga =
        tester.widget<Text>(find.text('a' * 400)).style!.fontSize!;

    expect(tamanoLarga, lessThan(tamanoCorta));
  });

  testWidgets('los tres fondos dibujan sin romperse', (tester) async {
    for (final fondo in Fondo.values) {
      for (final formato in Formato.values) {
        await tester.pumpWidget(_armar(fondo: fondo, formato: formato));
        expect(tester.takeException(), isNull,
            reason: 'fondo ${fondo.name} en formato ${formato.name}');
      }
    }
  });

  testWidgets('en Papel el texto va oscuro y en Noche va claro',
      (tester) async {
    await tester.pumpWidget(_armar(fondo: Fondo.papel));
    final claro = tester.widget<Text>(find.text(_frase)).style!.color!;

    await tester.pumpWidget(_armar(fondo: Fondo.noche));
    final oscuro = tester.widget<Text>(find.text(_frase)).style!.color!;

    expect(claro.computeLuminance(), lessThan(oscuro.computeLuminance()),
        reason: 'sobre papel claro el texto tiene que ser el oscuro');
  });
}
