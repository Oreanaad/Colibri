import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/api.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/nube.dart';

/// Traer la biblioteca de vuelta de la nube.
///
/// # Por qué esto se puede probar de verdad
///
/// `flutter test` corta toda petición HTTP, así que no se puede hablar con
/// Supabase desde acá. Pero [libroDeFila] es pura: recibe el mapa que
/// devuelve PostgREST y devuelve un [Libro], sin tocar la red. Así que lo
/// que se prueba no es "esperemos que ande": es la conversión completa,
/// con la forma exacta que tiene la respuesta del servidor.
///
/// Que la forma sea la exacta lo verifica `servidor/probar_bajada.sh`
/// contra el servidor de verdad, porque eso sí necesita internet.
///
/// # El viaje de ida y vuelta
///
/// La prueba que más importa es la última: armar un libro, pasarlo por las
/// funciones que lo suben, meter el resultado en la forma en que vuelve, y
/// comprobar que del otro lado está el mismo libro. Es la única forma de
/// atrapar un campo que se sube pero no se baja —o al revés—, que es
/// exactamente el tipo de cosa que nadie nota hasta que reinstala.

/// La respuesta del servidor para una lectura de un libro.
Map<String, dynamic> _filaDeLibro({
  Map<String, dynamic>? cambios,
  Map<String, dynamic>? enLaEdicion,
  List<Map<String, dynamic>>? animos,
  List<Map<String, dynamic>>? personajes,
  List<Map<String, dynamic>>? frases,
  List<Map<String, dynamic>>? estantes,
}) => {
  'id': 'lectura-1',
  'perfil_id': 'perfil-1',
  'edicion_id': 'edicion-1',
  'fanfic_id': null,
  'estado': 'leido',
  'puntaje': 5,
  'lagrimas': 3,
  'romantico': 4,
  'picante': 2,
  'pagina_actual': 120,
  'empezado': '2026-03-01',
  'terminado': '2026-03-14',
  'resena': 'Me arruinó la semana.',
  'resena_con_spoilers': true,
  'ediciones': {
    'id': 'edicion-1',
    'titulo': 'Cometierra',
    'editorial': 'Sigilo',
    'anio': 2019,
    'paginas': 180,
    'tapa_url': 'https://covers.openlibrary.org/b/id/999-M.jpg',
    'isbn': '9789873888014',
    'origen': 'catalogo',
    'obras': {'titulo': 'Cometierra', 'autor': 'Dolores Reyes'},
    ...?enLaEdicion,
  },
  'fanfics': null,
  'lectura_animos':
      animos ??
      [
        {'animo': 'me destruyó'},
      ],
  'personajes':
      personajes ??
      [
        {'nombre': 'la Cometierra'},
      ],
  'frases':
      frases ??
      [
        {
          'texto': 'La tierra me habla.',
          'pagina': 90,
          'creada': '2026-03-10T18:00:00Z',
        },
      ],
  'estante_lecturas':
      estantes ??
      [
        {
          'estantes': {'nombre': 'Argentinas'},
        },
      ],
  ...?cambios,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('sin servidor no se cae, no hace nada', () {
    // El bug: preguntar quién está en sesión pasa por
    // `Supabase.instance`, que **tira** si la app arrancó sin claves, y
    // esa pregunta estaba afuera del try de los tres métodos. En la app
    // no se notaba porque `main` solo engancha la nube cuando hay claves,
    // así que el camino era inalcanzable; pero significaba que la clase
    // entera no se podía probar sin un servidor de verdad, y que
    // cualquiera que la llamara desde otro lado se iba a comer una caída.
    //
    // Apareció justo al agregar `sincronizar`: la subida vieja recorría
    // la biblioteca primero, así que con la biblioteca vacía nunca
    // llegaba a preguntar. La bajada pregunta siempre.

    test('bajar no trae nada y no tira', () async {
      SharedPreferences.setMockInitialValues({});
      await biblioteca.cargar();

      expect(await nube.bajarTodo(biblioteca), 0);
    });

    test('sincronizar tampoco, ni con libros en el teléfono', () async {
      SharedPreferences.setMockInitialValues({});
      await biblioteca.cargar();
      for (final l in [...biblioteca.todos]) {
        await biblioteca.quitar(l);
      }
      await biblioteca.agregar(
        Libro(id: '1', titulo: 'Un libro', autor: 'Alguien'),
      );

      final cuenta = await nube.sincronizar(biblioteca);

      expect(cuenta.bajados, 0);
      expect(cuenta.subidos, 0);
      // Y sobre todo: el libro sigue estando. Que no haya servidor no
      // puede costarle nada a la biblioteca del teléfono.
      expect(biblioteca.todos, hasLength(1));
    });
  });

  group('una lectura de la nube se vuelve un libro', () {
    test('lo que se lee de la edición y de la obra', () {
      final libro = libroDeFila(_filaDeLibro())!;

      // El título sale de la edición y no de la obra: son distintos a
      // propósito —la obra guarda el original, la edición el de su
      // idioma— y lo que la lectora tiene en la mano es la edición.
      expect(libro.titulo, 'Cometierra');
      // La autoría sí sale de la obra: la tabla de ediciones no la tiene.
      expect(libro.autor, 'Dolores Reyes');
      expect(libro.editorial, 'Sigilo');
      expect(libro.anio, 2019);
      expect(libro.paginas, 180);
      expect(libro.isbn, '9789873888014');
      expect(libro.origen, Origen.catalogo);
    });

    test('las cuatro escalas, que son lo más fácil de perder', () {
      // Ya se perdieron una vez, al cambiar de edición. Ver
      // `combinarEdicion` en ediciones.dart.
      final libro = libroDeFila(_filaDeLibro())!;

      expect(libro.puntaje, 5);
      expect(libro.lagrimas, 3);
      expect(libro.romantico, 4);
      expect(libro.picante, 2);
    });

    test('el estado, las fechas y la reseña', () {
      final libro = libroDeFila(_filaDeLibro())!;

      expect(libro.estado, Estado.leido);
      expect(libro.empezado, DateTime(2026, 3, 1));
      expect(libro.terminado, DateTime(2026, 3, 14));
      expect(libro.resena, 'Me arruinó la semana.');
      expect(libro.resenaConSpoilers, isTrue);
      expect(libro.paginaActual, 120);
    });

    test('los ánimos, los personajes y los estantes', () {
      final libro = libroDeFila(_filaDeLibro())!;

      expect(libro.animos, ['me destruyó']);
      expect(libro.personajes, ['la Cometierra']);
      expect(libro.estantes, {'Argentinas'});
    });

    test('un estado que la app no conoce no la rompe', () {
      // La base solo admite tres estados, pero si algún día se agrega uno
      // más, una app vieja no tiene por qué caerse.
      final libro = libroDeFila(
        _filaDeLibro(cambios: {'estado': 'abandonado'}),
      )!;

      expect(libro.estado, Estado.pendiente);
    });

    test('una fila sin edición ni fanfic se saltea', () {
      // La base lo prohíbe con un check, así que esto no debería pasar.
      // Que no pase no es razón para caerse si pasa.
      final libro = libroDeFila(
        _filaDeLibro(cambios: {'ediciones': null, 'fanfics': null}),
      );

      expect(libro, isNull);
    });
  });

  group('las frases vuelven con su posición', () {
    test('la página se convierte en fracción del libro', () {
      // La app guarda "cerca del final" como un número de 0 a 1, porque
      // las páginas cambian con cada edición. La base guarda la página.
      final libro = libroDeFila(_filaDeLibro())!;

      expect(libro.frases, hasLength(1));
      expect(libro.frases.first.texto, 'La tierra me habla.');
      expect(libro.frases.first.posicion, closeTo(90 / 180, 0.001));
    });

    test('sin saber las páginas, la frase vuelve igual sin posición', () {
      // El texto es lo que importa; la posición es el adorno. Perder el
      // adorno no puede costar la frase.
      final libro = libroDeFila(_filaDeLibro(enLaEdicion: {'paginas': null}))!;

      expect(libro.frases.first.texto, 'La tierra me habla.');
      expect(libro.frases.first.posicion, isNull);
    });

    test('una página más grande que el libro no se pasa de 1', () {
      final libro = libroDeFila(
        _filaDeLibro(
          frases: [
            {'texto': 'Una', 'pagina': 400, 'creada': null},
          ],
        ),
      )!;

      expect(libro.frases.first.posicion, 1.0);
    });

    test('el tope de 800 caracteres sigue valiendo al bajar', () {
      // Es la protección legal del proyecto, no un detalle técnico: ver
      // Frase.topeDeCaracteres. Si al bajar entrara texto sin recortar,
      // el tope solo existiría de un lado.
      final libro = libroDeFila(
        _filaDeLibro(
          frases: [
            {'texto': 'a' * 2000, 'pagina': null, 'creada': null},
          ],
        ),
      )!;

      expect(
        libro.frases.first.texto.length,
        lessThanOrEqualTo(Frase.topeDeCaracteres + 1), // +1 por el «…»
      );
    });
  });

  group('los fanfics vuelven como fanfics', () {
    Map<String, dynamic> filaDeFanfic() => {
      'id': 'lectura-2',
      'perfil_id': 'perfil-1',
      'edicion_id': null,
      'fanfic_id': 'fanfic-1',
      'estado': 'leyendo',
      'puntaje': 4,
      'lagrimas': 0,
      'romantico': 5,
      'picante': 3,
      'pagina_actual': 12,
      'resena': null,
      'resena_con_spoilers': false,
      'ediciones': null,
      'fanfics': {
        'id': 'fanfic-1',
        'identidad': 'ao3:12345',
        'enlace': 'https://archiveofourown.org/works/12345',
        'titulo': 'All the Young Dudes',
        'autoria': 'MsKingBean89',
        'fandom': 'Harry Potter',
        'capitulos': 188,
      },
      'lectura_animos': [],
      'personajes': [],
      'frases': [],
      'estante_lecturas': [],
    };

    test('el origen, el enlace y el fandom', () {
      final libro = libroDeFila(filaDeFanfic())!;

      expect(libro.origen, Origen.fanfic);
      expect(libro.enlace, 'https://archiveofourown.org/works/12345');
      expect(libro.fandom, 'Harry Potter');
      // La autoría de un fanfic está en el fanfic, no en una obra: no
      // tiene obra, y ese era el caso que más fácil salía vacío.
      expect(libro.autor, 'MsKingBean89');
    });

    test('los capítulos son las páginas', () {
      final libro = libroDeFila(filaDeFanfic())!;
      expect(libro.paginas, 188);
    });

    test('vuelve con la clave de fanfic, no con la de libro', () {
      // Si volviera con la clave de libro, el mismo fic subido por dos
      // personas con títulos distintos entraría dos veces.
      final libro = libroDeFila(filaDeFanfic())!;
      expect(libro.clave, startsWith('fanfic|'));
    });
  });

  group('el viaje de ida y vuelta', () {
    /// Sube un libro y lo trae de vuelta, armando la respuesta que daría
    /// el servidor con lo que se le mandó.
    Libro idaYVuelta(Libro libro) {
      final edicion = filaDeEdicion(
        libro,
        obraId: 'obra-1',
        cargadaPor: 'perfil-1',
      );
      final obra = filaDeObra(libro);
      final lectura = filaDeLectura(
        libro,
        perfilId: 'perfil-1',
        edicionId: 'edicion-1',
      );

      return libroDeFila({
        ...lectura,
        'edicion_id': 'edicion-1',
        'fanfic_id': null,
        'ediciones': {
          ...edicion,
          'id': 'edicion-1',
          'obras': {'titulo': obra['titulo'], 'autor': obra['autor']},
        },
        'fanfics': null,
        'lectura_animos': [
          for (final a in libro.animos) {'animo': a},
        ],
        'personajes': [
          for (final p in libro.personajes) {'nombre': p},
        ],
        'frases': [
          for (final f in libro.frases)
            {
              'texto': f.texto,
              'pagina': paginaDeFrase(f, libro),
              'creada': f.guardada.toIso8601String(),
            },
        ],
        'estante_lecturas': [
          for (final e in libro.estantes)
            {
              'estantes': {'nombre': e},
            },
        ],
      })!;
    }

    test('nada de lo que la lectora escribió se pierde en el viaje', () {
      final antes = Libro(
        id: '/works/OL1W',
        titulo: 'Las malas',
        autor: 'Camila Sosa Villada',
        editorial: 'Tusquets',
        anio: 2019,
        paginas: 224,
        isbn: '9789876706100',
        estado: Estado.leido,
        puntaje: 5,
        lagrimas: 4,
        romantico: 2,
        picante: 1,
        paginaActual: 224,
        empezado: DateTime(2026, 1, 5),
        terminado: DateTime(2026, 1, 20),
        resena: 'No se lo presto a nadie.',
        resenaConSpoilers: true,
        animos: ['me destruyó', 'me abrazó'],
        personajes: ['la Tía Encarna'],
        estantes: {'Argentinas', 'Para siempre'},
        frases: [
          Frase(
            texto: 'Nadie nos había dicho que podíamos vivir.',
            posicion: 0.5,
          ),
        ],
      );

      final despues = idaYVuelta(antes);

      expect(despues.titulo, antes.titulo);
      expect(despues.autor, antes.autor);
      expect(despues.editorial, antes.editorial);
      expect(despues.anio, antes.anio);
      expect(despues.paginas, antes.paginas);
      expect(despues.isbn, antes.isbn);
      expect(despues.estado, antes.estado);
      expect(despues.puntaje, antes.puntaje);
      expect(despues.lagrimas, antes.lagrimas);
      expect(despues.romantico, antes.romantico);
      expect(despues.picante, antes.picante);
      expect(despues.paginaActual, antes.paginaActual);
      expect(despues.empezado, antes.empezado);
      expect(despues.terminado, antes.terminado);
      expect(despues.resena, antes.resena);
      expect(despues.resenaConSpoilers, antes.resenaConSpoilers);
      expect(despues.animos, antes.animos);
      expect(despues.personajes, antes.personajes);
      expect(despues.estantes, antes.estantes);
      expect(despues.frases.first.texto, antes.frases.first.texto);
      expect(despues.frases.first.posicion, closeTo(0.5, 0.01));

      // Y lo más importante: sigue siendo el mismo libro para la app, así
      // que no entra dos veces.
      expect(despues.clave, antes.clave);
    });

    test('la tapa de un libro de Open Library sobrevive el viaje', () {
      // El bug: los libros de Open Library —o sea casi todos— no traen
      // una dirección de tapa, traen un número con el que se arma. La
      // fila que se subía mandaba `libro.tapaUrl` crudo, que en esos
      // casos es null, así que la tapa se perdía y al bajar el libro
      // aparecía con la tapa dibujada.
      final antes = Libro(
        id: '/works/OL2W',
        titulo: 'Distancia de rescate',
        autor: 'Samanta Schweblin',
        tapaId: 8231856, // número, no dirección
      );

      expect(antes.tapaUrl, isNull, reason: 'así viene de Open Library');

      final despues = idaYVuelta(antes);

      expect(despues.tapaUrl, isNotNull);
      expect(despues.tapaUrl, contains('8231856'));
      expect(Api.tapaDe(despues), Api.tapaDe(antes));
    });
  });
}
