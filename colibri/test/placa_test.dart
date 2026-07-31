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
            libro: Libro(id: '1', titulo: 'Pedro Páramo', autor: 'Juan Rulfo'),
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
  testWidgets('la placa muestra la frase, el título y la autoría', (
    tester,
  ) async {
    await tester.pumpWidget(_armar());

    expect(find.text(_frase), findsOneWidget);
    expect(find.text('Pedro Páramo'), findsOneWidget);
    expect(find.text('Juan Rulfo'), findsOneWidget);
  });

  testWidgets('hay una sola marca, chica y con el secreto en oro', (
    tester,
  ) async {
    await tester.pumpWidget(_armar());

    final conTramos = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.textSpan != null)
        .toList();

    expect(
      conTramos.length,
      1,
      reason: 'se sacó la marca de agua grande de atrás',
    );

    final marca = conTramos.single.textSpan! as TextSpan;
    final tramos = marca.children!.cast<TextSpan>();
    expect(tramos.map((t) => t.text).join(), 'colibrí');
    expect(tramos.firstWhere((t) => t.text == 'libr').style!.color, isNotNull);

    // Chica de verdad: más chica que la propia autoría.
    final tamanoMarca = marca.style!.fontSize!;
    final tamanoAutor = tester
        .widget<Text>(find.text('Juan Rulfo'))
        .style!
        .fontSize!;
    expect(tamanoMarca, lessThan(tamanoAutor));
  });

  testWidgets('la marca va pegada a la autoría, donde no se puede recortar', (
    tester,
  ) async {
    await tester.pumpWidget(_armar());

    final autor = tester.getBottomLeft(find.text('Juan Rulfo'));
    final marca = tester.getTopLeft(
      find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
    );

    // Justo debajo de la autoría y alineada con ella: si alguien recorta
    // la marca, se lleva puesta la cita.
    expect(marca.dy - autor.dy, lessThan(20));
    expect(
      (marca.dx - tester.getTopLeft(find.text('Juan Rulfo')).dx).abs(),
      lessThan(2),
    );
  });

  testWidgets('una frase larga se dibuja más chica para que entre entera', (
    tester,
  ) async {
    const corta = 'Una frase corta y linda de leer siempre.';
    final larga = List.filled(24, 'palabras interminables').join(' ');

    await tester.pumpWidget(_armar(texto: corta));
    final tamanoCorta = tester.widget<Text>(find.text(corta)).style!.fontSize!;

    await tester.pumpWidget(_armar(texto: larga));
    final tamanoLarga = tester.widget<Text>(find.text(larga)).style!.fontSize!;

    expect(tamanoLarga, lessThan(tamanoCorta));
  });

  testWidgets('la frase entra entera, sin cortarse', (tester) async {
    // El bug que esto cuida: el tamaño salía de una tabla por largo de
    // texto y adivinaba mal, así que la frase quedaba cortada abajo.
    final casos = [
      'Corta.',
      'Oh, Violet. Worried brown eyes look down at me as strong hands '
          'catch my shoulders before I can fall.',
      List.filled(28, 'una palabra bastante larga').join(' '),
      'a' * 780, // una sola palabra enorme, sin dónde cortar
    ];

    for (final formato in Formato.values) {
      for (final crudo in casos) {
        // Frase recorta lo que pasa del tope, así que lo que se dibuja
        // no siempre es igual a lo que se le pasó.
        final texto = Frase(texto: crudo).texto;

        await tester.pumpWidget(_armar(texto: crudo, formato: formato));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'formato ${formato.name}, ${texto.length} caracteres',
        );

        // Si no entrara, Flutter recortaría el texto y la altura pintada
        // sería mayor que la caja que le tocó.
        final frase = find.text(texto);
        expect(frase, findsOneWidget);

        final alto = tester.getSize(frase).height;
        final disponible = tester.getSize(find.byType(Placa)).height;
        expect(
          alto,
          lessThan(disponible),
          reason: 'la frase se pasa de la placa en ${formato.name}',
        );
      }
    }
  });

  testWidgets('los tres fondos dibujan sin romperse', (tester) async {
    for (final fondo in Fondo.values) {
      for (final formato in Formato.values) {
        await tester.pumpWidget(_armar(fondo: fondo, formato: formato));
        expect(
          tester.takeException(),
          isNull,
          reason: 'fondo ${fondo.name} en formato ${formato.name}',
        );
      }
    }
  });

  testWidgets('en Papel el texto va oscuro y en Noche va claro', (
    tester,
  ) async {
    await tester.pumpWidget(_armar(fondo: Fondo.papel));
    final claro = tester.widget<Text>(find.text(_frase)).style!.color!;

    await tester.pumpWidget(_armar(fondo: Fondo.noche));
    final oscuro = tester.widget<Text>(find.text(_frase)).style!.color!;

    expect(
      claro.computeLuminance(),
      lessThan(oscuro.computeLuminance()),
      reason: 'sobre papel claro el texto tiene que ser el oscuro',
    );
  });
}
