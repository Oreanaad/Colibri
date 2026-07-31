import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/api.dart';
import 'package:colibri/modelos.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('un libro cargado a mano no tiene ediciones que pedir', () async {
    // Sin id de obra no hay a quién preguntarle, y hay que salir sin
    // tocar la red en vez de armar una URL inventada.
    final propio = Libro(
      id: 'propio:123',
      titulo: 'Las niñas del naranjel',
      autor: 'Gabriela Cabezón Cámara',
      origen: Origen.propio,
    );

    expect(await Api.ediciones(propio), isEmpty);
  });

  test('cambiar de edición no te borra nada tuyo', () async {
    // Lo que se pierde en un cambio de edición mal hecho es lo que más
    // duele: las frases que subrayaste y lo que escribiste.
    final b = Biblioteca();

    final original = Libro(
      id: '/works/OL82563W',
      titulo: "Harry Potter and the Philosopher's Stone",
      autor: 'J. K. Rowling',
      estado: Estado.leido,
      puntaje: 5,
      empezado: DateTime(2026, 1, 10),
      terminado: DateTime(2026, 1, 22),
      resena: 'Lo leí de un tirón.',
      resenaConSpoilers: true,
      personajes: ['Hermione'],
      estantes: {'De la infancia'},
      frases: [Frase(texto: 'Una frase que subrayé y no quiero perder.')],
    );
    await b.agregar(original);

    // Así queda después de elegir la edición en español.
    final traducido = Libro(
      id: original.id,
      titulo: 'Harry Potter y la piedra filosofal',
      autor: original.autor,
      tapaId: 15155841,
      editorial: 'Salamandra',
      anio: 2018,
      estado: original.estado,
      puntaje: original.puntaje,
      empezado: original.empezado,
      terminado: original.terminado,
      resena: original.resena,
      resenaConSpoilers: original.resenaConSpoilers,
      personajes: original.personajes,
      estantes: original.estantes,
      frases: original.frases,
      origen: original.origen,
    );

    await b.quitar(original);
    await b.agregar(traducido);

    final otra = Biblioteca();
    await otra.cargar();
    final guardado = otra.todos.single;

    expect(guardado.titulo, 'Harry Potter y la piedra filosofal');
    expect(guardado.editorial, 'Salamandra');
    expect(guardado.tapaId, 15155841);

    // Y todo lo tuyo sigue en su lugar.
    expect(guardado.puntaje, 5);
    expect(guardado.resena, 'Lo leí de un tirón.');
    expect(guardado.resenaConSpoilers, isTrue);
    expect(guardado.personajes, ['Hermione']);
    expect(guardado.estantes, {'De la infancia'});
    expect(guardado.frases.length, 1);
    expect(guardado.diasDeLectura, 13);
  });

  test('la clave cambia con el título, y eso es correcto', () {
    // Es la contracara de traducir el título: dos personas que tienen el
    // mismo libro en idiomas distintos dejan de coincidir.
    //
    // Se anota acá para que quede visible: cuando haya servidor, las
    // coincidencias tienen que calcularse por la obra (/works/OL82563W)
    // y no por el título, que es justo lo que cambia entre ediciones.
    final ingles = Libro(
      id: '/works/OL82563W',
      titulo: "Harry Potter and the Philosopher's Stone",
      autor: 'J. K. Rowling',
    );
    final espanol = Libro(
      id: '/works/OL82563W',
      titulo: 'Harry Potter y la piedra filosofal',
      autor: 'J. K. Rowling',
    );

    expect(ingles.clave, isNot(espanol.clave));
    expect(
      ingles.id,
      espanol.id,
      reason: 'la obra es la misma: por acá va a ir la coincidencia',
    );
  });
}
