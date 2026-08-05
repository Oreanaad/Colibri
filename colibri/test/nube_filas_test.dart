import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/nube.dart';

/// Lo que se manda a la base, antes de que se mande.
///
/// Estas funciones son puras: arman un mapa a partir de un Libro y nada
/// más. No tocan la red, así que se prueban solas, igual que ya se hizo
/// con los mensajes de error de Supabase. Que la base de verdad acepte
/// estas formas se comprueba aparte, con servidor/probar_biblioteca.sh.
void main() {
  Libro libro({
    String titulo = 'Cometierra',
    String autor = 'Dolores Reyes',
    String? isbn,
    String? enlace,
    String? fandom,
    String? editorial,
    int? anio,
    int? paginas,
    Origen origen = Origen.catalogo,
  }) => Libro(
    id: 'x',
    titulo: titulo,
    autor: autor,
    isbn: isbn,
    enlace: enlace,
    fandom: fandom,
    editorial: editorial,
    anio: anio,
    paginas: paginas,
    origen: origen,
  );

  group('filaDeObra', () {
    test('lleva título, autor y la clave normalizada', () {
      final fila = filaDeObra(
        libro(titulo: 'Pedro Páramo', autor: 'Juan Rulfo'),
      );

      expect(fila['titulo'], 'Pedro Páramo');
      expect(fila['autor'], 'Juan Rulfo');
      // La misma cuenta que usa la app para reconocer un libro que ya
      // tenés, sin acentos ni mayúsculas.
      expect(fila['clave'], 'pedro paramo|juan rulfo');
    });

    test('"Juan Rulfo" y "Rulfo, Juan" dan la misma clave', () {
      final a = filaDeObra(libro(autor: 'Juan Rulfo'));
      final b = filaDeObra(libro(autor: 'Rulfo, Juan'));

      expect(a['clave'], b['clave']);
    });
  });

  group('filaDeEdicion', () {
    test('lleva la obra, el ISBN y de dónde salió', () {
      final l = libro(
        isbn: '9789874063656',
        editorial: 'Sigilo',
        anio: 2019,
        paginas: 176,
      )..tapaUrl = 'https://x/tapa.jpg';

      final fila = filaDeEdicion(l, obraId: 'obra-1', cargadaPor: 'yo');

      expect(fila['obra_id'], 'obra-1');
      expect(fila['isbn'], '9789874063656');
      expect(fila['editorial'], 'Sigilo');
      expect(fila['anio'], 2019);
      expect(fila['paginas'], 176);
      expect(fila['tapa_url'], 'https://x/tapa.jpg');
      expect(fila['cargada_por'], 'yo');
    });

    test('un libro sin ISBN manda isbn nulo, no lo inventa', () {
      final fila = filaDeEdicion(libro(), obraId: 'o', cargadaPor: 'yo');

      expect(fila['isbn'], isNull);
    });

    test('el origen se traduce a lo que acepta la base', () {
      final catalogo = filaDeEdicion(
        libro(origen: Origen.catalogo),
        obraId: 'o',
        cargadaPor: 'yo',
      );
      final propio = filaDeEdicion(
        libro(origen: Origen.propio),
        obraId: 'o',
        cargadaPor: 'yo',
      );

      // Son los dos únicos valores que el check de la base acepta.
      expect(catalogo['origen'], 'catalogo');
      expect(propio['origen'], 'propio');
    });
  });

  group('filaDeFanfic', () {
    test('la identidad sale del enlace, no se inventa', () {
      final fila = filaDeFanfic(
        libro(
          titulo: 'Todo lo que somos',
          enlace: 'https://archiveofourown.org/works/1234567',
          fandom: 'Harry Potter',
          origen: Origen.fanfic,
        ),
      );

      expect(fila['identidad'], 'ao3:1234567');
      expect(fila['fandom'], 'Harry Potter');
      expect(fila['autoria'], 'Dolores Reyes');
    });

    test('la autoría del fanfic sale del autor del libro', () {
      // El fanfic no tiene un campo "autor" separado del que ya usa el
      // resto de la app: es el mismo dato, con otro nombre de columna.
      final fila = filaDeFanfic(
        libro(
          autor: 'unaAutora',
          enlace: 'archiveofourown.org/works/1',
          origen: Origen.fanfic,
        ),
      );

      expect(fila['autoria'], 'unaAutora');
    });
  });

  group('filaDeLectura', () {
    test('las cuatro escalas y el estado viajan', () {
      final l = libro()
        ..estado = Estado.leido
        ..puntaje = 5
        ..lagrimas = 3
        ..romantico = 2
        ..picante = 1;

      final fila = filaDeLectura(l, perfilId: 'yo', edicionId: 'ed-1');

      expect(fila['estado'], 'leido');
      expect(fila['puntaje'], 5);
      expect(fila['lagrimas'], 3);
      expect(fila['romantico'], 2);
      expect(fila['picante'], 1);
      expect(fila['edicion_id'], 'ed-1');
      expect(fila.containsKey('fanfic_id'), isFalse);
    });

    test('los tres estados son exactamente los que acepta la base', () {
      for (final e in Estado.values) {
        final fila = filaDeLectura(
          libro()..estado = e,
          perfilId: 'yo',
          edicionId: 'ed',
        );
        expect(fila['estado'], anyOf('leyendo', 'leido', 'pendiente'));
      }
    });

    test('las fechas se mandan sin hora, y solo si están puestas', () {
      final l = libro()..terminado = DateTime(2026, 3, 4, 23, 47);

      final fila = filaDeLectura(l, perfilId: 'yo', edicionId: 'ed');

      expect(fila['terminado'], '2026-03-04');
      expect(fila.containsKey('empezado'), isFalse);
    });

    test('un fanfic manda fanfic_id y no edicion_id', () {
      final fila = filaDeLectura(libro(), perfilId: 'yo', fanficId: 'fic-1');

      expect(fila['fanfic_id'], 'fic-1');
      expect(fila.containsKey('edicion_id'), isFalse);
    });
  });

  group('paginaDeFrase', () {
    test('convierte la posición a página con las páginas de esta edición', () {
      final l = libro(paginas: 200);
      final frase = Frase(texto: 'x', posicion: 0.5);

      expect(paginaDeFrase(frase, l), 100);
    });

    test('sin páginas o sin posición, no inventa un número', () {
      final conPaginas = libro(paginas: 200);
      final sinPaginas = libro();

      expect(paginaDeFrase(Frase(texto: 'x'), conPaginas), isNull);
      expect(
        paginaDeFrase(Frase(texto: 'x', posicion: 0.5), sinPaginas),
        isNull,
      );
    });
  });
}
