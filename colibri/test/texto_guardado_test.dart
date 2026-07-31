import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';

Libro _libro() => Libro(id: '1', titulo: 'Rayuela', autor: 'Julio Cortázar');

/// Un libro largo de mentira, con texto variado para que comprima como
/// comprimiría uno de verdad y no como mil veces la misma letra.
List<String> novela({int parrafos = 2500}) {
  const palabras = [
    'la',
    'noche',
    'y',
    'el',
    'agua',
    'volvía',
    'sobre',
    'los',
    'árboles',
    'como',
    'si',
    'nadie',
    'hubiera',
    'estado',
    'nunca',
    'ahí',
    'mirando',
    'el',
    'río',
    'que',
    'no',
    'termina',
    'de',
    'pasar',
    'entre',
    'las',
    'piedras',
    'húmedas',
    'del',
    'fondo',
    'oscuro',
  ];
  return List.generate(parrafos, (i) {
    final b = StringBuffer();
    for (var j = 0; j < 60; j++) {
      b.write(palabras[(i * 7 + j * 3) % palabras.length]);
      b.write(' ');
    }
    return '${b.toString().trim()} ($i).';
  });
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('el texto vuelve idéntico al que se guardó', () async {
    final b = Biblioteca();
    final l = _libro();
    await b.agregar(l);

    final original = [
      'Vine a Comala porque me dijeron que acá vivía mi padre.',
      'Un párrafo con «comillas», guiones —así— y puntos suspensivos…',
      'Otro con ñ, tildes: canción, después, así.',
    ];

    expect(await b.guardarTexto(l, original), isTrue);
    expect(await b.textoDe(l), original);
  });

  test('una novela entera entra, gracias a la compresión', () async {
    final b = Biblioteca();
    final l = _libro();
    await b.agregar(l);
    final texto = novela();

    expect(await b.guardarTexto(l, texto), isTrue);

    final crudo = utf8.encode(texto.join()).length;
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString('colibri.texto.${l.clave}')!.length;

    // Sin comprimir, una novela así pasa el tope de unos 5 MB que tiene
    // el guardado del navegador y la importación falla entera.
    expect(
      guardado,
      lessThan(crudo ~/ 2),
      reason: 'comprimido tiene que ocupar menos de la mitad',
    );
    expect(
      guardado,
      lessThan(2 * 1024 * 1024),
      reason: 'y entrar cómodo en el tope del navegador',
    );
  });

  test('el libro sigue ahí después de cerrar y abrir la app', () async {
    final b = Biblioteca();
    final l = _libro();
    await b.agregar(l);
    await b.guardarTexto(l, novela(parrafos: 200));

    final otra = Biblioteca();
    await otra.cargar();
    final guardado = otra.todos.first;

    expect(
      otra.tieneTexto(guardado),
      isTrue,
      reason: 'no hay que volver a importar el EPUB',
    );
    expect((await otra.textoDe(guardado))!.length, 200);
  });

  test('borrar el texto no toca las frases subrayadas', () async {
    final b = Biblioteca();
    final l = _libro()
      ..frases.add(Frase(texto: 'Una frase que ya había subrayado.'));
    await b.agregar(l);
    await b.guardarTexto(l, novela(parrafos: 50));

    await b.borrarTexto(l);

    expect(b.tieneTexto(l), isFalse);
    expect(await b.textoDe(l), isNull);
    expect(l.frases.length, 1, reason: 'las frases son suyas, no del archivo');
  });

  test('lee el formato viejo, sin comprimir', () async {
    final l = _libro();
    SharedPreferences.setMockInitialValues({
      'colibri.conTexto.v1': [l.clave],
      'colibri.texto.${l.clave}': ['Párrafo uno.', 'Párrafo dos.'],
    });

    final b = Biblioteca();
    await b.cargar();

    expect(await b.textoDe(l), ['Párrafo uno.', 'Párrafo dos.']);
  });
}
