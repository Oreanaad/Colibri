import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/fanfic.dart';
import 'package:colibri/modelos.dart';

/// Que el mismo fanfic no entre cuatro mil veces.
///
/// La regla es una sola: **la identidad de un fanfic es su dirección**, no
/// su título. Todo lo de abajo son formas distintas de escribir la misma
/// dirección, que es exactamente lo que va a pasar cuando lo cargue mucha
/// gente desde teléfonos y navegadores distintos.
void main() {
  group('Archive of Our Own', () {
    // El mismo fic, pegado por seis personas distintas.
    const mismas = [
      'https://archiveofourown.org/works/1234567',
      'http://archiveofourown.org/works/1234567',
      'https://www.archiveofourown.org/works/1234567',
      'archiveofourown.org/works/1234567',
      '  https://archiveofourown.org/works/1234567  ',
      'https://archiveofourown.org/works/1234567?view_full_work=true',
    ];

    test('todas las formas de escribirlo dan la misma identidad', () {
      final identidades = mismas.map(Fanfic.identidad).toSet();

      expect(identidades, hasLength(1), reason: 'salieron $identidades');
      expect(identidades.single, 'ao3:1234567');
    });

    test('el enlace a un capítulo es el mismo fic', () {
      // Esto no lo decidimos nosotras: pedirle a AO3 la dirección con
      // capítulo contesta 302 hacia la dirección sin capítulo. El sitio
      // mismo dice cuál es la forma buena.
      expect(
        Fanfic.identidad(
          'https://archiveofourown.org/works/1234567/chapters/98765',
        ),
        'ao3:1234567',
      );
    });

    test('el enlace desde una colección también', () {
      expect(
        Fanfic.identidad(
          'https://archiveofourown.org/collections/algo/works/1234567',
        ),
        'ao3:1234567',
      );
    });

    test('dos fics distintos no se confunden', () {
      expect(
        Fanfic.identidad('https://archiveofourown.org/works/1234567'),
        isNot(Fanfic.identidad('https://archiveofourown.org/works/7654321')),
      );
    });
  });

  group('los otros sitios', () {
    test('Wattpad: la historia, con o sin el título pegado', () {
      const conTitulo =
          'https://www.wattpad.com/story/336699-todo-lo-que-somos';
      const sinTitulo = 'https://wattpad.com/story/336699';

      expect(Fanfic.identidad(conTitulo), 'wattpad:336699');
      expect(Fanfic.identidad(sinTitulo), 'wattpad:336699');
    });

    test('FanFiction.net: la historia, sin el capítulo ni el título', () {
      expect(
        Fanfic.identidad('https://www.fanfiction.net/s/1234567/1/El-titulo'),
        'ffn:1234567',
      );
      expect(
        Fanfic.identidad('https://www.fanfiction.net/s/1234567/12/El-titulo'),
        'ffn:1234567',
      );
    });

    test('un sitio cualquiera igual tiene identidad', () {
      // No es tan firme como un número de obra, pero sigue siendo mucho
      // mejor que comparar títulos escritos a mano.
      expect(
        Fanfic.identidad('https://miblog.com/fics/el-titulo'),
        'web:miblog.com/fics/el-titulo',
      );
      expect(
        Fanfic.identidad('http://www.miblog.com/fics/el-titulo/'),
        'web:miblog.com/fics/el-titulo',
      );
    });

    test('se reconoce de qué sitio es', () {
      expect(Fanfic.sitioDe('https://archiveofourown.org/works/1'), Sitio.ao3);
      expect(Fanfic.sitioDe('https://wattpad.com/story/1'), Sitio.wattpad);
      expect(Fanfic.sitioDe('https://fanfiction.net/s/1'), Sitio.fanfiction);
      expect(Fanfic.sitioDe('https://miblog.com/x'), Sitio.otro);
    });
  });

  group('lo que no es una dirección', () {
    test('un título escrito no pasa por enlace', () {
      // Sin esto, escribir el título en el campo del enlace daría una
      // identidad válida y volveríamos a tener cuatro mil fichas.
      for (final texto in ['', '   ', 'Todo lo que somos', 'cometierra']) {
        expect(
          Fanfic.identidad(texto),
          isNull,
          reason: '«$texto» no es una dirección',
        );
      }
    });

    test('pareceEnlace dice lo mismo', () {
      expect(Fanfic.pareceEnlace('archiveofourown.org/works/1'), isTrue);
      expect(Fanfic.pareceEnlace('Todo lo que somos'), isFalse);
    });
  });

  group('el enlace que se guarda', () {
    test('queda ordenado, sin importar cómo lo pegaron', () {
      expect(
        Fanfic.limpiar('  http://www.archiveofourown.org/works/123?x=1  '),
        'https://archiveofourown.org/works/123',
      );
    });

    test('el capítulo se conserva para poder volver a él', () {
      // Distinto de la identidad: para saber si es el mismo fic da igual
      // el capítulo, pero para abrirlo no. Si alguien pegó el capítulo 12,
      // ahí es donde quiere volver.
      expect(
        Fanfic.limpiar('archiveofourown.org/works/123/chapters/456'),
        'https://archiveofourown.org/works/123/chapters/456',
      );
      expect(
        Fanfic.identidad('archiveofourown.org/works/123/chapters/456'),
        'ao3:123',
      );
    });
  });

  group('en la biblioteca', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await biblioteca.cargar();
      for (final l in [...biblioteca.todos]) {
        await biblioteca.quitar(l);
      }
    });

    Libro fic(String titulo, String enlace, {String autor = 'alguien'}) =>
        Libro(
          id: enlace,
          titulo: titulo,
          autor: autor,
          enlace: enlace,
          origen: Origen.fanfic,
        );

    test('el mismo fic con títulos distintos entra una sola vez', () async {
      // Este es el caso entero: cuatro personas, cuatro títulos, un fic.
      await biblioteca.agregar(
        fic('Todo lo que somos', 'https://archiveofourown.org/works/1234567'),
      );

      final entraron = await biblioteca.agregarVarios([
        fic('todo lo q somos', 'http://www.archiveofourown.org/works/1234567'),
        fic('TODO LO QUE SOMOS [Drarry]', 'archiveofourown.org/works/1234567'),
        fic(
          'Drarry - todo lo que somos',
          'https://archiveofourown.org/works/1234567/chapters/999',
        ),
      ]);

      expect(entraron, 0);
      expect(biblioteca.todos, hasLength(1));
    });

    test('dos fics distintos con el mismo título entran los dos', () {
      // El otro lado de la moneda, y es igual de importante: los títulos
      // se repiten muchísimo entre fandoms.
      final uno = fic(
        'Segundas oportunidades',
        'archiveofourown.org/works/111',
      );
      final otro = fic(
        'Segundas oportunidades',
        'archiveofourown.org/works/222',
      );

      expect(uno.clave, isNot(otro.clave));
    });

    test('un fanfic nunca choca con un libro', () {
      final libro = Libro(
        id: '1',
        titulo: 'Cometierra',
        autor: 'Dolores Reyes',
      );
      final elFic = fic('Cometierra', 'archiveofourown.org/works/1');

      expect(libro.clave, isNot(elFic.clave));
    });

    test('sin enlace se compara como un libro cualquiera', () {
      // No se rompe: simplemente pierde la garantía, y por eso la pantalla
      // pide el enlace.
      final sinEnlace = Libro(
        id: 'x',
        titulo: 'Todo lo que somos',
        autor: 'alguien',
        origen: Origen.fanfic,
      );

      expect(sinEnlace.clave, 'todo lo que somos|alguien');
    });

    test('sobrevive a cerrar y volver a abrir la app', () async {
      await biblioteca.agregar(
        Libro(
          id: 'f',
          titulo: 'Todo lo que somos',
          autor: 'unaAutora',
          enlace: 'https://archiveofourown.org/works/1234567',
          fandom: 'Harry Potter',
          origen: Origen.fanfic,
        ),
      );

      final otra = Biblioteca();
      await otra.cargar();
      final guardado = otra.todos.single;

      expect(guardado.origen, Origen.fanfic);
      expect(guardado.fandom, 'Harry Potter');
      expect(guardado.clave, 'fanfic|ao3:1234567');
    });
  });
}
