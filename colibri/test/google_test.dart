import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/api.dart';
import 'package:colibri/google.dart';
import 'package:colibri/modelos.dart';

/// Google Books, el segundo catálogo.
///
/// # Lo que estas pruebas sí garantizan
///
/// Que la app no se rompe sin clave, que no manda a nadie a internet de
/// más, que junta los dos catálogos sin repetir y que sabe leer la forma
/// de respuesta de Google, incluidas las tapas con sus dos vicios.
///
/// # Lo que no
///
/// **Las respuestas de acá abajo están armadas con la documentación, no
/// copiadas de una respuesta real.** La cuota anónima de Google estaba
/// agotada cuando se escribió esto —«Queries per day … for consumer
/// project_number:624717413613», que es un proyecto compartido por todo
/// internet— así que no hubo forma de traer una de verdad.
///
/// Traducido: si Google devuelve algo con una forma que no previmos,
/// estas pruebas van a pasar igual. Por eso existe `tool/probar_google.dart`,
/// que se corre con clave y habla con Google de verdad. **Hay que correrlo
/// una vez antes de confiar en esto.**
void main() {
  group('sin clave', () {
    test('la app sabe que Google no está disponible', () {
      // Los tests corren sin --dart-define, así que este es el estado
      // normal de cualquiera que clone el repositorio.
      expect(Google.disponible, isFalse);
    });

    test('buscar devuelve vacío sin tocar internet', () async {
      expect(await Google.buscar('cometierra'), isEmpty);
    });

    test('por ISBN devuelve nada sin tocar internet', () async {
      expect(await Google.porIsbn('9789874063656'), isNull);
    });
  });

  group('leer un volumen de Google', () {
    Map<String, dynamic> volumen({
      String id = 'abc123',
      Map<String, dynamic>? info,
    }) => {'id': id, 'volumeInfo': info ?? const {}};

    test('saca título, autoría, editorial, año y páginas', () {
      final libro = Libro.desdeGoogle(
        volumen(
          info: {
            'title': 'Cometierra',
            'authors': ['Dolores Reyes'],
            'publisher': 'Sigilo',
            'publishedDate': '2019-03-15',
            'pageCount': 176,
          },
        ),
      );

      expect(libro.titulo, 'Cometierra');
      expect(libro.autor, 'Dolores Reyes');
      expect(libro.editorial, 'Sigilo');
      expect(libro.anio, 2019);
      expect(libro.paginas, 176);
    });

    test('la fecha viene de tres formas y de las tres saca el año', () {
      for (final fecha in ['2019', '2019-03', '2019-03-15']) {
        final libro = Libro.desdeGoogle(
          volumen(info: {'title': 'x', 'publishedDate': fecha}),
        );
        expect(libro.anio, 2019, reason: 'con la fecha «$fecha»');
      }
    });

    test('sobrevive a un volumen casi vacío', () {
      // Google devuelve fichas incompletas seguido. Que falte la autoría
      // no puede tirar abajo toda la búsqueda.
      final libro = Libro.desdeGoogle(volumen());

      expect(libro.titulo, 'Sin título');
      expect(libro.autor, 'Autor desconocido');
      expect(libro.tapaUrl, isNull);
      expect(libro.anio, isNull);
    });

    test('el identificador lleva prefijo para no chocar con Open Library', () {
      final libro = Libro.desdeGoogle(volumen(id: 'OL123W'));

      // Sin el prefijo, un volumen de Google llamado igual que una obra de
      // Open Library serían el mismo libro para la app.
      expect(libro.id, 'google:OL123W');
    });

    group('la tapa', () {
      String? tapaDe(Map<String, dynamic> imagenes) => Libro.desdeGoogle({
        'id': 'x',
        'volumeInfo': {'title': 't', 'imageLinks': imagenes},
      }).tapaUrl;

      test('pasa de http a https', () {
        // Una página segura no muestra imágenes inseguras: sin esto se
        // verían todas las tapas rotas.
        final url = tapaDe({
          'thumbnail': 'http://books.google.com/books/content?id=x&img=1',
        });
        expect(url, startsWith('https://'));
        expect(url, isNot(contains('http://')));
      });

      test('le saca la esquina de papel doblada', () {
        final url = tapaDe({
          'thumbnail':
              'http://books.google.com/books/content?id=x&edge=curl&img=1',
        });
        expect(url, isNot(contains('edge=curl')));
        expect(url, contains('img=1'));
      });

      test('si no hay grande usa la chica', () {
        expect(
          tapaDe({'smallThumbnail': 'http://x/chica.jpg'}),
          'https://x/chica.jpg',
        );
      });

      test('sin imágenes no inventa una dirección', () {
        expect(tapaDe(const {}), isNull);
      });
    });
  });

  group('juntar los dos catálogos', () {
    Libro libro(String titulo, String autor, {String id = 'x'}) =>
        Libro(id: id, titulo: titulo, autor: autor);

    test('lo que ya estaba va primero', () {
      // Quien busca casi siempre quiere el primer resultado. Mover de
      // lugar lo que Open Library puso arriba sería peor que no traer
      // nada nuevo.
      final juntos = Api.unir(
        [libro('Cometierra', 'Dolores Reyes')],
        [libro('Las malas', 'Camila Sosa Villada')],
      );

      expect(juntos.map((l) => l.titulo), ['Cometierra', 'Las malas']);
    });

    test('el mismo libro en los dos catálogos aparece una sola vez', () {
      final juntos = Api.unir(
        [libro('Pedro Páramo', 'Juan Rulfo', id: 'ol')],
        [libro('pedro paramo', 'Rulfo, Juan', id: 'google:g')],
      );

      // Distinto título escrito, distinta forma del nombre, mismo libro.
      expect(juntos, hasLength(1));
      expect(juntos.single.id, 'ol', reason: 'gana el que ya estaba');
    });

    test('respeta el tope', () {
      final muchos = [
        for (var i = 0; i < 30; i++) libro('Libro $i', 'Alguien', id: '$i'),
      ];

      expect(Api.unir(muchos, const [], maximo: 15), hasLength(15));
    });

    test('con un catálogo vacío devuelve el otro tal cual', () {
      final uno = [libro('Cometierra', 'Dolores Reyes')];

      expect(Api.unir(uno, const []), hasLength(1));
      expect(Api.unir(const [], uno), hasLength(1));
      expect(Api.unir(const [], const []), isEmpty);
    });
  });

  group('la tapa, venga de donde venga', () {
    test('si hay dirección propia, se usa esa', () {
      final deGoogle = Libro(
        id: 'g',
        titulo: 't',
        autor: 'a',
        tapaUrl: 'https://books.google.com/tapa.jpg',
      );

      expect(Api.tapaDe(deGoogle), 'https://books.google.com/tapa.jpg');
    });

    test('si no, se arma con el número de Open Library', () {
      final deOpenLibrary = Libro(id: 'o', titulo: 't', autor: 'a', tapaId: 42);

      expect(Api.tapaDe(deOpenLibrary), contains('/b/id/42-M.jpg'));
    });

    test('sin ninguna de las dos, no hay tapa', () {
      expect(Api.tapaDe(Libro(id: 'x', titulo: 't', autor: 'a')), isNull);
    });

    test('la dirección sobrevive a guardar y volver a abrir', () async {
      final libro = Libro(
        id: 'g',
        titulo: 't',
        autor: 'a',
        tapaUrl: 'https://books.google.com/tapa.jpg',
      );

      // Si no se guardara, cada libro que vino de Google perdería la tapa
      // al cerrar la app.
      expect(
        Libro.desdeJson(libro.aJson()).tapaUrl,
        'https://books.google.com/tapa.jpg',
      );
    });
  });
}
