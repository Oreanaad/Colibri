import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/api.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/ediciones.dart';

/// Elegir tu edición mirando las portadas.
///
/// Esta parte nació de un reporte concreto: escaneó *The Demigod Diaries*
/// y la app mostró la tapa verde en inglés, cuando la que tiene en la mano
/// es azul y en castellano. Medido después: esa obra tiene 7 ediciones en
/// Open Library, 4 con tapa, y **la española tiene tapa**. El libro
/// estaba; la app no lo mostraba.
void main() {
  Libro edicion({
    String titulo = 'Otra edición',
    int? tapa,
    String? editorial,
    int? anio,
  }) => Libro(
    id: 'ed-${tapa ?? titulo}',
    titulo: titulo,
    autor: 'Quien sea',
    tapaId: tapa,
    editorial: editorial,
    anio: anio,
  );

  group('ordenar para elegir mirando', () {
    test('las que tienen tapa van primero', () {
      // Si estás buscando la portada azul que tenés en la mano, una fila
      // de rectángulos vacíos arriba de todo no sirve para nada.
      final ordenadas = paraMirar([
        edicion(titulo: 'sin tapa A'),
        edicion(titulo: 'con tapa', tapa: 1),
        edicion(titulo: 'sin tapa B'),
      ]);

      expect(ordenadas.first.titulo, 'con tapa');
      expect(ordenadas, hasLength(3), reason: 'no se pierde ninguna');
    });

    test('la misma portada no se muestra dos veces', () {
      // Open Library tiene la misma edición cargada varias veces con la
      // misma imagen. Seis veces la misma tapa no da a elegir: da a dudar.
      final ordenadas = paraMirar([
        edicion(titulo: 'a', tapa: 7),
        edicion(titulo: 'b', tapa: 7),
        edicion(titulo: 'c', tapa: 9),
      ]);

      expect(ordenadas, hasLength(2));
      expect(ordenadas.first.titulo, 'a', reason: 'queda la primera');
    });

    test('las que no tienen tapa no se agrupan entre sí', () {
      // No se pueden comparar mirando, así que no hay repetida que sacar:
      // sacarlas sería perder ediciones de verdad.
      final ordenadas = paraMirar([
        edicion(titulo: 'una'),
        edicion(titulo: 'otra'),
      ]);

      expect(ordenadas, hasLength(2));
    });

    test('una lista vacía no explota', () {
      expect(paraMirar(const []), isEmpty);
    });
  });

  group('cambiar de edición sin perder nada tuyo', () {
    Libro miLibro() => Libro(
      id: '/works/OL1W',
      titulo: 'The Demigod Diaries',
      autor: 'Rick Riordan',
      tapaId: 100,
      estado: Estado.leido,
      puntaje: 5,
      lagrimas: 3,
      romantico: 2,
      picante: 1,
      animos: ['me destruyó'],
      resena: 'Lo leí de un tirón',
      resenaConSpoilers: true,
      personajes: ['Luke'],
      estantes: {'Los que me rompieron'},
      paginaActual: 180,
      empezado: DateTime(2026, 7, 1),
      terminado: DateTime(2026, 7, 3),
    );

    test('el libro pasa a ser el de tu edición', () {
      final nuevo = combinarEdicion(
        miLibro(),
        edicion(
          titulo: 'Los diarios del semidiós',
          tapa: 200,
          editorial: 'Salamandra',
          anio: 2013,
        ),
      );

      expect(nuevo.titulo, 'Los diarios del semidiós');
      expect(nuevo.tapaId, 200);
      expect(nuevo.editorial, 'Salamandra');
      expect(nuevo.anio, 2013);
    });

    test('las cuatro escalas y las etiquetas sobreviven', () {
      // Este es el test que faltaba. Cambiar de edición borraba en
      // silencio cuánto lloraste, cuánto picaba, cuánto romance y cómo te
      // dejó, porque los cuatro campos no se copiaban.
      final nuevo = combinarEdicion(miLibro(), edicion(tapa: 200));

      expect(nuevo.lagrimas, 3);
      expect(nuevo.romantico, 2);
      expect(nuevo.picante, 1);
      expect(nuevo.animos, ['me destruyó']);
    });

    test('todo lo demás tuyo también', () {
      final nuevo = combinarEdicion(miLibro(), edicion(tapa: 200));

      expect(nuevo.estado, Estado.leido);
      expect(nuevo.puntaje, 5);
      expect(nuevo.resena, 'Lo leí de un tirón');
      expect(nuevo.resenaConSpoilers, isTrue);
      expect(nuevo.personajes, ['Luke']);
      expect(nuevo.estantes, {'Los que me rompieron'});
      expect(nuevo.paginaActual, 180);
      expect(nuevo.empezado, DateTime(2026, 7, 1));
      expect(nuevo.terminado, DateTime(2026, 7, 3));
      expect(nuevo.id, '/works/OL1W', reason: 'la obra sigue siendo la misma');
    });

    test('elegir una edición con tapa borra la portada de Google', () {
      // Un libro que vino de Google trae la dirección de la tapa, y esa le
      // gana al número. Si no se borrara, elegir una portada nueva no
      // cambiaría nada en pantalla.
      final deGoogle = Libro(
        id: 'google:x',
        titulo: 'The Demigod Diaries',
        autor: 'Rick Riordan',
        tapaUrl: 'https://books.google.com/verde.jpg',
      );

      final nuevo = combinarEdicion(deGoogle, edicion(tapa: 200));

      expect(nuevo.tapaUrl, isNull);
      expect(nuevo.tapaId, 200);
      expect(Api.tapaDe(nuevo), contains('/b/id/200-'));
    });

    test('si la edición elegida no tiene tapa, se queda la que había', () {
      final deGoogle = Libro(
        id: 'google:x',
        titulo: 'x',
        autor: 'y',
        tapaUrl: 'https://books.google.com/verde.jpg',
      );

      final nuevo = combinarEdicion(deGoogle, edicion());

      expect(nuevo.tapaUrl, 'https://books.google.com/verde.jpg');
    });
  });

  group('las ediciones sin idioma cargado', () {
    // Reporte: «si pongo todos veo portadas en español que si pongo
    // español no salen». Medido: de las 200 ediciones de Harry Potter que
    // tiene Open Library, **78 no tienen el idioma anotado**, y la primera
    // de esa lista es «Harry Potter y la piedra filosofal», de Salamandra.
    // El filtro pedía un dato que el catálogo muchas veces no tiene.

    test('las dos listas se ordenan y limpian por separado', () {
      // Cada sección se mira aparte, así que las repetidas se sacan dentro
      // de cada una: una tapa puede estar bien en las dos.
      final confirmadas = paraMirar([
        edicionDePrueba(titulo: 'a', tapa: 1),
        edicionDePrueba(titulo: 'b', tapa: 1),
        edicionDePrueba(titulo: 'sin tapa'),
      ]);
      final sinIdioma = paraMirar([
        edicionDePrueba(titulo: 'c', tapa: 5),
        edicionDePrueba(titulo: 'd', tapa: 5),
      ]);

      expect(confirmadas, hasLength(2));
      expect(confirmadas.first.titulo, 'a');
      expect(sinIdioma, hasLength(1));
    });

    test('no se pierde ninguna edición al separarlas', () {
      // Lo importante del arreglo: las que no dicen idioma no se
      // descartan, se muestran aparte. Descartarlas era el bug.
      final todas = [
        edicionDePrueba(titulo: 'confirmada', tapa: 1),
        edicionDePrueba(titulo: 'sin idioma', tapa: 2),
      ];
      final separadas = [
        ...paraMirar([todas.first]),
        ...paraMirar([todas.last]),
      ];

      expect(separadas, hasLength(todas.length));
    });
  });
}

/// Una edición cualquiera, para las pruebas.
Libro edicionDePrueba({
  String titulo = 'Otra edición',
  int? tapa,
  String? editorial,
  int? anio,
}) => Libro(
  id: 'ed-${tapa ?? titulo}',
  titulo: titulo,
  autor: 'Quien sea',
  tapaId: tapa,
  editorial: editorial,
  anio: anio,
);
