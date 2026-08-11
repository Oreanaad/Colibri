import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/api.dart';
import 'package:colibri/modelos.dart';

/// Filtrar las ediciones por idioma, sin pedirle nada a internet.
///
/// # El bug que esto atrapa
///
/// Cada toque en un idioma volvía a pedirle las 200 ediciones a Open
/// Library. Ese pedido, medido: mediana **12 segundos**, cola hasta 60, con
/// algún 503 en el medio. Y no dependía de cuánto se pidiera —`limit=24`
/// tardaba lo mismo que `limit=200`— así que no había forma de acelerarlo
/// del lado nuestro.
///
/// Probar «Español», después «Todos», después «Portugués» eran tres esperas
/// de más de diez segundos cada una **para filtrar una lista que la
/// pantalla ya tenía completa en la memoria**.
///
/// Filtrar es mirar una lista. Estas pruebas son la prueba de que no hace
/// falta la red: si alguna necesitara internet, no correría acá, porque
/// `flutter test` corta toda petición.
void main() {
  Edicion edicion(String titulo, List<String> idiomas, {int? tapa}) => (
    libro: Libro(
      id: '/books/$titulo',
      titulo: titulo,
      autor: 'Alguien',
      tapaId: tapa,
    ),
    idiomas: idiomas,
  );

  final todas = <Edicion>[
    edicion('Harry Potter and the Philosopher’s Stone', ['eng'], tapa: 1),
    edicion('Harry Potter y la piedra filosofal', ['spa'], tapa: 2),
    edicion('Harry Potter e a Pedra Filosofal', ['por'], tapa: 3),
    // La de Salamandra: existe, es española, y el catálogo no lo anotó.
    edicion('Harry Potter y la piedra filosofal (Salamandra)', [], tapa: 4),
    edicion('Harry Potter à l’école des sorciers', ['fre'], tapa: 5),
  ];

  group('filtrar por idioma', () {
    test('trae solo las de ese idioma', () {
      final r = Api.porIdioma(todas, 'spa');

      expect(r.confirmadas.map((l) => l.titulo), [
        'Harry Potter y la piedra filosofal',
      ]);
    });

    test('las que no dicen el idioma van aparte, no se descartan', () {
      // De las 200 ediciones de Harry Potter, 78 no tienen idioma anotado,
      // y la primera de esa lista es justo la de Salamandra. Filtrando por
      // español, la edición que más gente tiene en la mano quedaba afuera.
      final r = Api.porIdioma(todas, 'spa');

      expect(r.sinIdioma.map((l) => l.titulo), [
        'Harry Potter y la piedra filosofal (Salamandra)',
      ]);
    });

    test('sin idioma pedido, salen todas juntas', () {
      final r = Api.porIdioma(todas, null);

      expect(r.confirmadas, hasLength(5));
      expect(
        r.sinIdioma,
        isEmpty,
        reason: 'si no se filtra, no hay nada que separar',
      );
    });

    test('un idioma que no está no rompe nada', () {
      final r = Api.porIdioma(todas, 'jpn');

      expect(r.confirmadas, isEmpty);
      // Y las sin idioma siguen apareciendo: puede que la japonesa sea una
      // de esas.
      expect(r.sinIdioma, hasLength(1));
    });

    test('una edición en varios idiomas cuenta para los dos', () {
      final bilingue = [
        edicion('Edición bilingüe', ['spa', 'eng']),
      ];

      expect(Api.porIdioma(bilingue, 'spa').confirmadas, hasLength(1));
      expect(Api.porIdioma(bilingue, 'eng').confirmadas, hasLength(1));
    });

    test('una lista vacía no explota', () {
      final r = Api.porIdioma(const [], 'spa');
      expect(r.confirmadas, isEmpty);
      expect(r.sinIdioma, isEmpty);
    });

    test('cambiar de idioma no pierde ninguna', () {
      // Lo que hace posible filtrar sin volver a pedir: la lista completa
      // no se toca nunca. Si `porIdioma` la modificara, el segundo toque
      // trabajaría sobre datos ya recortados.
      Api.porIdioma(todas, 'spa');
      Api.porIdioma(todas, 'eng');
      Api.porIdioma(todas, null);

      expect(todas, hasLength(5));
      expect(Api.porIdioma(todas, 'por').confirmadas, hasLength(1));
    });
  });

  group('convertir las entradas crudas', () {
    // La forma exacta que devuelve Open Library.
    final crudas = <Map<String, dynamic>>[
      {
        'key': '/books/OL1M',
        'title': 'Harry Potter y la piedra filosofal',
        'languages': [
          {'key': '/languages/spa'},
        ],
        'covers': [12345, 999],
        'publishers': ['Salamandra', 'Otra'],
        'publish_date': 'Jun 04, 2020',
        'number_of_pages': 254,
      },
      {'key': '/books/OL2M', 'title': 'Sin nada anotado'},
    ];

    final obra = Libro(
      id: '/works/OL82563W',
      titulo: 'Harry Potter and the Philosopher’s Stone',
      autor: 'J. K. Rowling',
    );

    test('el idioma sale del final de la clave', () {
      final r = Api.edicionesDe(crudas, obra, '/works/OL82563W');
      expect(r.first.idiomas, ['spa']);
    });

    test('se toma la primera tapa y la primera editorial', () {
      final r = Api.edicionesDe(crudas, obra, '/works/OL82563W');

      expect(r.first.libro.tapaId, 12345);
      expect(r.first.libro.editorial, 'Salamandra');
    });

    test('del texto de la fecha se saca el año', () {
      final r = Api.edicionesDe(crudas, obra, '/works/OL82563W');
      expect(r.first.libro.anio, 2020);
    });

    test('la autoría la pone la obra, porque la edición no la trae', () {
      final r = Api.edicionesDe(crudas, obra, '/works/OL82563W');
      expect(r.first.libro.autor, 'J. K. Rowling');
    });

    test('una entrada pelada no rompe la lista', () {
      final r = Api.edicionesDe(crudas, obra, '/works/OL82563W');

      expect(r, hasLength(2));
      expect(r.last.idiomas, isEmpty);
      expect(r.last.libro.tapaId, isNull);
      // Sin título propio hereda el de la obra, que es mejor que vacío.
      expect(r.last.libro.titulo, 'Sin nada anotado');
    });
  });
}
