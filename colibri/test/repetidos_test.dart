import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/api.dart';

/// Una ficha de Open Library, con lo mínimo para el test.
Map<String, dynamic> ficha({
  required String titulo,
  String? autor,
  int? tapa,
  String? editorial,
  int? anio,
  int ediciones = 1,
}) => {
  'key': '/works/${titulo.hashCode}${autor.hashCode}$anio',
  'title': titulo,
  if (autor != null) 'author_name': <String>[autor],
  'cover_i': ?tapa,
  if (editorial != null) 'publisher': [editorial],
  'first_publish_year': ?anio,
  'edition_count': ediciones,
};

void main() {
  test('el mismo libro escrito de tres maneras sale una sola vez', () {
    // Es literalmente lo que devuelve Open Library al buscar esto.
    final r = Api.sinRepetidos([
      ficha(titulo: 'Cazadores de sombras', autor: 'Cassandra Clare', tapa: 1),
      ficha(titulo: 'Cazadores De Sombras', autor: 'Clare, Cassandra'),
      ficha(
        titulo: 'cazadores de sombras',
        autor: 'Cassandra Clare',
        anio: 2013,
      ),
    ]);

    expect(r.length, 1);
    expect(r.first.tapaId, 1, reason: 'gana la ficha que tiene tapa');
  });

  test('las fichas sin autor se pegan a la que sí lo tiene', () {
    final r = Api.sinRepetidos([
      ficha(titulo: 'Cazadores de sombras', autor: 'Cassandra Clare', tapa: 1),
      ficha(titulo: 'Cazadores de sombras'), // "Autor desconocido"
    ]);

    expect(r.length, 1);
    expect(r.first.autor, 'Cassandra Clare');
  });

  test('los tomos distintos siguen siendo libros distintos', () {
    final r = Api.sinRepetidos([
      ficha(titulo: 'Cazadores de sombras', autor: 'Cassandra Clare'),
      ficha(titulo: 'Cazadores de sombras 2', autor: 'Cassandra Clare'),
    ]);

    expect(r.length, 2, reason: 'son dos libros, no dos fichas del mismo');
  });

  test('mismo título y autores distintos: se muestran los dos', () {
    // Perder un libro es peor que mostrar dos parecidos.
    final r = Api.sinRepetidos([
      ficha(titulo: 'Fiebre', autor: 'Una Autora'),
      ficha(titulo: 'Fiebre', autor: 'Otro Autor'),
    ]);

    expect(r.length, 2);
  });

  test('gana la ficha más completa, no la primera', () {
    final r = Api.sinRepetidos([
      ficha(titulo: 'Rayuela', autor: 'Julio Cortázar'),
      ficha(
        titulo: 'Rayuela',
        autor: 'Julio Cortázar',
        tapa: 99,
        editorial: 'Alfaguara',
        anio: 1963,
        ediciones: 40,
      ),
    ]);

    expect(r.length, 1);
    expect(r.first.tapaId, 99);
    expect(r.first.editorial, 'Alfaguara');
    expect(r.first.anio, 1963);
  });

  test('se respeta el orden de relevancia que manda Open Library', () {
    final r = Api.sinRepetidos([
      ficha(titulo: 'Primero', autor: 'A A'),
      ficha(titulo: 'Segundo', autor: 'B B'),
      ficha(titulo: 'Primero', autor: 'A A', tapa: 5),
      ficha(titulo: 'Tercero', autor: 'C C'),
    ]);

    expect(r.map((l) => l.titulo).toList(), ['Primero', 'Segundo', 'Tercero']);
    expect(
      r.first.tapaId,
      5,
      reason: 'el mejor del grupo, en el lugar del primero',
    );
  });

  test('una ficha sin título no rompe nada', () {
    final r = Api.sinRepetidos([
      {'key': '/works/1'},
      ficha(titulo: 'Rayuela', autor: 'Julio Cortázar'),
    ]);

    expect(r.length, 1);
  });

  test('sin resultados, lista vacía', () {
    expect(Api.sinRepetidos(const []), isEmpty);
  });

  test('el traductor puesto como autor no genera un libro fantasma', () {
    // Open Library a veces carga al traductor en el campo de autoría. Se
    // nota en el peso: la ficha buena junta decenas de ediciones y la
    // otra tiene una sola.
    final r = Api.sinRepetidos([
      ficha(
        titulo: 'Cazadores de sombras',
        autor: 'Cassandra Clare',
        tapa: 1,
        ediciones: 40,
      ),
      ficha(titulo: 'Cazadores De Sombras', autor: 'Gemma Gallart'),
    ]);

    expect(r.length, 1);
    expect(r.first.autor, 'Cassandra Clare');
  });

  test('si los dos pesan parecido, se quedan los dos', () {
    // Ahí sí es probable que sean libros distintos con el mismo título.
    final r = Api.sinRepetidos([
      ficha(titulo: 'Fiebre', autor: 'Una Autora', ediciones: 8),
      ficha(titulo: 'Fiebre', autor: 'Otro Autor', ediciones: 6),
    ]);

    expect(r.length, 2);
  });

  test('la lista tiene un tope: cincuenta resultados no se leen', () {
    final muchos = List.generate(
      60,
      (i) => ficha(titulo: 'Libro $i', autor: 'Autor $i'),
    );

    expect(Api.sinRepetidos(muchos).length, 15);
    expect(Api.sinRepetidos(muchos, maximo: 5).length, 5);
  });
}
