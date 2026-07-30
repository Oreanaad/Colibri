import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';

Libro _libro(String titulo) =>
    Libro(id: titulo, titulo: titulo, autor: 'Alguien');

void main() {
  // La biblioteca guarda en el teléfono; en los tests le damos un
  // almacenamiento falso y vacío antes de cada prueba.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('crear un estante devuelve su nombre limpio', () async {
    final b = Biblioteca();
    expect(await b.crearEstante('  Los que me rompieron '),
        'Los que me rompieron');
    expect(b.estantes, ['Los que me rompieron']);
  });

  test('no se puede crear uno vacío ni uno repetido', () async {
    final b = Biblioteca();
    await b.crearEstante('Terror');

    expect(await b.crearEstante('   '), isNull);
    expect(await b.crearEstante('terror'), isNull,
        reason: 'repetido aunque cambien las mayúsculas');
    expect(b.estantes.length, 1);
  });

  test('un libro puede estar en varios estantes a la vez', () async {
    final b = Biblioteca();
    final l = _libro('Cometierra');
    await b.agregar(l);
    await b.crearEstante('Terror');
    await b.crearEstante('Argentinas');

    await b.alternarEstante(l, 'Terror');
    await b.alternarEstante(l, 'Argentinas');
    expect(l.estantes, {'Terror', 'Argentinas'});

    // El estado sigue siendo uno solo: los estantes no lo tocan.
    expect(l.estado, Estado.pendiente);

    await b.alternarEstante(l, 'Terror');
    expect(l.estantes, {'Argentinas'});
  });

  test('borrar un estante no borra los libros', () async {
    final b = Biblioteca();
    final l = _libro('Las malas');
    await b.agregar(l);
    await b.crearEstante('Favoritos');
    await b.alternarEstante(l, 'Favoritos');

    await b.borrarEstante('Favoritos');

    expect(b.estantes, isEmpty);
    expect(l.estantes, isEmpty);
    expect(b.todos.length, 1, reason: 'el libro sigue en la biblioteca');
  });

  test('renombrar arrastra los libros al nombre nuevo', () async {
    final b = Biblioteca();
    final l = _libro('Mugre rosa');
    await b.agregar(l);
    await b.crearEstante('Raros');
    await b.alternarEstante(l, 'Raros');

    await b.renombrarEstante('Raros', 'Distopías');

    expect(b.estantes, ['Distopías']);
    expect(l.estantes, {'Distopías'});
    expect(b.enEstante('Distopías').length, 1);
  });

  test('los estantes sobreviven al cerrar y abrir la app', () async {
    final b = Biblioteca();
    final l = _libro('Nuestra parte de noche');
    await b.agregar(l);
    await b.crearEstante('Me destruyó');
    await b.alternarEstante(l, 'Me destruyó');
    await b.crearEstante('Vacío a propósito');

    // Otra instancia: es lo que pasa cuando se vuelve a abrir la app.
    final otra = Biblioteca();
    await otra.cargar();

    expect(otra.estantes, ['Me destruyó', 'Vacío a propósito'],
        reason: 'un estante vacío no se pierde');
    expect(otra.enEstante('Me destruyó').first.titulo,
        'Nuestra parte de noche');
  });

  test('lee bien las bibliotecas guardadas con el formato viejo', () {
    // Antes el campo se llamaba "estante" y no existían los propios.
    final l = Libro.desdeJson({
      'id': '1',
      'titulo': 'Rayuela',
      'autor': 'Julio Cortázar',
      'estante': 1, // leído
      'puntaje': 5,
    });

    expect(l.estado, Estado.leido);
    expect(l.estantes, isEmpty);
    expect(l.puntaje, 5);
  });
}
