import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';

/// Lo que pasa con un libro que ya tenías cuando la nube trae otra versión.
///
/// El caso que lo trajo: el mismo Iron Flame iba por la página 375 en el
/// teléfono y seguía en pendientes en la compu, porque la bajada salteaba
/// todo lo que ya estaba.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
  });

  Libro ironFlame() =>
      Libro(id: '1', titulo: 'Iron Flame', autor: 'Rebecca Yarros');

  test('toma de la nube el estado, la página y las estrellas', () async {
    final tuyo = ironFlame();
    await biblioteca.agregar(tuyo);
    final nube = ironFlame()
      ..estado = Estado.leyendo
      ..paginaActual = 375
      ..puntaje = 3;

    await biblioteca.ponerAlDia([(tuyo, nube)]);

    final ahora = biblioteca.buscarPorClave(tuyo.clave)!;
    expect(ahora.estado, Estado.leyendo);
    expect(ahora.paginaActual, 375);
    expect(ahora.puntaje, 3);
  });

  test('las frases se suman, no se reemplazan', () async {
    final tuyo = ironFlame()..frases.add(Frase(texto: 'La mía'));
    await biblioteca.agregar(tuyo);
    final nube = ironFlame()
      ..frases.addAll([Frase(texto: 'La mía'), Frase(texto: 'La del otro')]);

    await biblioteca.ponerAlDia([(tuyo, nube)]);

    expect(biblioteca.buscarPorClave(tuyo.clave)!.frases.map((f) => f.texto), [
      'La mía',
      'La del otro',
    ]);
  });

  test('una lista vacía en la nube no borra la tuya', () async {
    final tuyo = ironFlame()
      ..estantes.add('Romantasy')
      ..personajes.add('Xaden');
    await biblioteca.agregar(tuyo);

    await biblioteca.ponerAlDia([(tuyo, ironFlame())]);

    final ahora = biblioteca.buscarPorClave(tuyo.clave)!;
    expect(ahora.estantes, {'Romantasy'});
    expect(ahora.personajes, ['Xaden']);
  });

  test('un estante que llega de la nube aparece como solapa', () async {
    final tuyo = ironFlame();
    await biblioteca.agregar(tuyo);

    await biblioteca.ponerAlDia([(tuyo, ironFlame()..estantes.add('Prueba'))]);

    expect(biblioteca.estantes, contains('Prueba'));
  });

  test('queda guardado', () async {
    final tuyo = ironFlame();
    await biblioteca.agregar(tuyo);
    await biblioteca.ponerAlDia([(tuyo, ironFlame()..paginaActual = 375)]);

    await biblioteca.cargar();
    expect(biblioteca.buscarPorClave(tuyo.clave)!.paginaActual, 375);
  });
}
