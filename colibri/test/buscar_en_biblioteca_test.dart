import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';

/// El buscador de la biblioteca.
///
/// Lo que se prueba acá no es que «funcione la búsqueda», es que funcione
/// como busca una persona: sin acordarse de los acentos, sin acordarse de
/// las mayúsculas, escribiendo un pedacito del medio del título.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
  });

  var siguiente = 0;

  Future<Libro> agregar(
    String titulo,
    String autor, {
    List<String> estantes = const [],
  }) async {
    final libro = Libro(
      id: 'prueba-${siguiente++}',
      titulo: titulo,
      autor: autor,
    );
    libro.estantes.addAll(estantes);
    await biblioteca.agregar(libro);
    return libro;
  }

  test('encuentra por un pedazo del título', () async {
    await agregar('Cometierra', 'Dolores Reyes');
    await agregar('Las malas', 'Camila Sosa Villada');

    expect(biblioteca.buscarEnMiBiblioteca('tierra').single.titulo, 'Cometierra');
  });

  test('no importan los acentos ni las mayúsculas', () async {
    await agregar('Pedro Páramo', 'Juan Rulfo');

    for (final escrito in ['páramo', 'paramo', 'PARAMO', 'Páramo']) {
      expect(
        biblioteca.buscarEnMiBiblioteca(escrito),
        hasLength(1),
        reason: 'escribiendo «$escrito» debería aparecer',
      );
    }
  });

  test('encuentra por la autoría', () async {
    await agregar('Pedro Páramo', 'Juan Rulfo');
    await agregar('El llano en llamas', 'Juan Rulfo');
    await agregar('Cometierra', 'Dolores Reyes');

    expect(biblioteca.buscarEnMiBiblioteca('rulfo'), hasLength(2));
  });

  test('encuentra por el nombre de un estante', () async {
    await agregar('Un libro', 'Alguien', estantes: ['Fantasía']);
    await agregar('Otro libro', 'Otra persona');

    expect(
      biblioteca.buscarEnMiBiblioteca('fantasia').single.titulo,
      'Un libro',
    );
  });

  test('busca en toda la biblioteca, no solo en una solapa', () async {
    final leyendo = await agregar('Cometierra', 'Dolores Reyes');
    final leido = await agregar('Cometierra dos', 'Dolores Reyes');
    await biblioteca.cambiarEstado(leyendo, Estado.leyendo);
    await biblioteca.cambiarEstado(leido, Estado.leido);

    // Los dos aparecen aunque estén en estados distintos: si buscás un
    // libro que tenés, lo tenés que encontrar sin adivinar dónde lo
    // guardaste.
    expect(biblioteca.buscarEnMiBiblioteca('cometierra'), hasLength(2));
  });

  test('con una sola letra no busca', () async {
    await agregar('Cometierra', 'Dolores Reyes');

    // Con una letra media biblioteca coincide y el resultado no dice nada.
    expect(biblioteca.buscarEnMiBiblioteca('c'), isEmpty);
    expect(biblioteca.buscarEnMiBiblioteca(''), isEmpty);
    expect(biblioteca.buscarEnMiBiblioteca('  '), isEmpty);
  });

  test('un libro que coincide dos veces aparece una sola vez', () async {
    // El título y la autoría dicen «reyes»: no puede salir duplicado.
    await agregar('Reyes de la noche', 'Dolores Reyes');

    expect(biblioteca.buscarEnMiBiblioteca('reyes'), hasLength(1));
  });

  test('lo que no está, no aparece', () async {
    await agregar('Cometierra', 'Dolores Reyes');

    expect(biblioteca.buscarEnMiBiblioteca('duna'), isEmpty);
  });
}
