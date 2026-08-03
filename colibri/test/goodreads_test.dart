import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/goodreads.dart';
import 'package:colibri/modelos.dart';

/// Traer tu biblioteca de Goodreads.
///
/// El archivo de abajo tiene las mañas reales del export de Goodreads, que
/// son las que rompen un lector escrito de memoria:
///
/// - los ISBN vienen envueltos en una fórmula de planilla, `="978…"`, y a
///   veces la fórmula está vacía;
/// - las reseñas traen comas, comillas dobles escritas dos veces y saltos
///   de línea **adentro del campo**;
/// - las reseñas viejas traen HTML;
/// - el título arrastra la colección entre paréntesis;
/// - hay filas sin autoría, sin fecha y sin nada.
const _archivo =
    'Book Id,Title,Author,Author l-f,Additional Authors,ISBN,ISBN13,'
    'My Rating,Average Rating,Publisher,Binding,Number of Pages,'
    'Year Published,Original Publication Year,Date Read,Date Added,'
    'Bookshelves,Bookshelves with positions,Exclusive Shelf,My Review,'
    'Spoiler,Private Notes,Read Count,Owned Copies\n'
    '2767052,"Cometierra (Trilogía, #1)","Dolores Reyes","Reyes, Dolores",,'
    '="9874063653",="9789874063656",5,4.15,"Sigilo","Paperback",176,'
    '2019,2019,"2019/03/15","2019/02/01","favoritos, terror, read",'
    '"favoritos (#1)","read","Lo leí de un tirón, en una noche. '
    'Ella dice ""veo cosas"" y le creés.",,"nota privada",1,1\n'
    '41865,"Las malas","Camila Sosa Villada","Sosa Villada, Camila",,'
    '="",="",0,4.30,"Tusquets","Paperback",224,2019,2019,,"2024/05/02",'
    '"to-read","","to-read","",,,0,0\n'
    '99999,"Nuestra parte de noche","Mariana Enriquez","Enriquez, Mariana",,'
    '="8433998676",="9788433998675",4,4.21,"Anagrama","Hardcover",667,'
    '2019,2019,,"2025/01/10",,"","currently-reading",'
    '"<i>Enorme</i>.<br/>Todavía no la termino &amp; ya la extraño.",'
    'true,,1,1\n';

void main() {
  group('leer el archivo', () {
    test('entran todos los libros', () {
      final r = Goodreads.leer(_archivo);

      expect(r.libros, hasLength(3));
      expect(r.filas, 3);
      expect(r.sinTitulo, 0);
      expect(r.noEsDeGoodreads, isFalse);
    });

    test('el estante de Goodreads se convierte en estado', () {
      final r = Goodreads.leer(_archivo);

      expect(r.libros[0].estado, Estado.leido);
      expect(r.libros[1].estado, Estado.pendiente);
      expect(r.libros[2].estado, Estado.leyendo);
    });

    test('el puntaje viaja, y un cero es cero y no una estrella', () {
      final r = Goodreads.leer(_archivo);

      expect(r.libros[0].puntaje, 5);
      expect(r.libros[1].puntaje, 0);
      expect(r.libros[2].puntaje, 4);
    });

    test('la fecha de lectura solo si el libro está leído', () {
      final r = Goodreads.leer(_archivo);

      expect(r.libros[0].terminado, DateTime(2019, 3, 15));
      // Este está leyéndose: no puede tener fecha de terminado, aunque
      // Goodreads guarde algo en esa columna.
      expect(r.libros[2].terminado, isNull);
    });

    test('los estantes propios viajan, sin los de Goodreads', () {
      final r = Goodreads.leer(_archivo);

      // «read» es el estado, no un estante: si entrara, tendrías un
      // estante llamado «read» al lado de la solapa Leídos.
      expect(r.libros[0].estantes, {'favoritos', 'terror'});
      expect(r.libros[1].estantes, isEmpty);
    });
  });

  group('las mañas del archivo', () {
    test('la reseña sobrevive a comas, comillas y saltos de línea', () {
      final r = Goodreads.leer(_archivo);

      // Es el campo que rompe cualquier lector hecho a mano: tiene una
      // coma, comillas escritas dos veces y un salto de línea adentro.
      expect(r.libros[0].resena, contains('Lo leí de un tirón'));
      expect(r.libros[0].resena, contains('"veo cosas"'));
    });

    test('a las reseñas viejas se les saca el HTML', () {
      final r = Goodreads.leer(_archivo);

      expect(
        r.libros[2].resena,
        'Enorme.\nTodavía no la termino & ya la extraño.',
      );
      expect(r.libros[2].resena, isNot(contains('<')));
      expect(r.libros[2].resena, isNot(contains('&amp;')));
    });

    test('el aviso de spoilers viaja', () {
      final r = Goodreads.leer(_archivo);

      expect(r.libros[2].resenaConSpoilers, isTrue);
      expect(r.libros[0].resenaConSpoilers, isFalse);
    });

    test('el título pierde la colección', () {
      final r = Goodreads.leer(_archivo);

      // «Cometierra (Trilogía, #1)» ensucia la ficha y además rompe la
      // coincidencia con el mismo libro cargado desde un catálogo.
      expect(r.libros[0].titulo, 'Cometierra');
    });

    test('el ISBN sale de adentro de la fórmula de planilla', () {
      final r = Goodreads.leer(_archivo);

      expect(r.libros[0].isbn, '9789874063656');
      expect(r.libros[2].isbn, '9788433998675');
    });

    test('una fórmula vacía no es un ISBN', () {
      final r = Goodreads.leer(_archivo);

      expect(r.libros[1].isbn, isNull);
      expect(r.conIsbn, 2);
    });

    test('el ISBN de diez se convierte al de trece', () {
      // Goodreads guarda los dos; si el de trece faltara, el de diez sirve
      // igual para ir a buscar la tapa después.
      final soloDiez = _archivo.replaceFirst('="9789874063656"', '=""');
      final r = Goodreads.leer(soloDiez);

      expect(r.libros[0].isbn, '9789874063656');
    });
  });

  group('archivos que no son lo que se esperaba', () {
    test('uno vacío no rompe nada', () {
      expect(Goodreads.leer('').vacia, isTrue);
      expect(Goodreads.leer('').filas, 0);
    });

    test('una planilla que no es de Goodreads se reconoce', () {
      // Sin esto, importar la lista del supermercado daría «0 libros» sin
      // decir por qué, y parecería un error de la app.
      final r = Goodreads.leer('Nombre,Cantidad\nLeche,2\n');

      expect(r.noEsDeGoodreads, isTrue);
      expect(r.vacia, isTrue);
    });

    test('las filas sin título se cuentan y no se importan', () {
      final r = Goodreads.leer(
        'Title,Author\n"",Alguien\n"Cometierra",Dolores\n',
      );

      expect(r.libros, hasLength(1));
      expect(r.sinTitulo, 1);
      expect(r.filas, 2);
    });

    test('un archivo con solo el título alcanza', () {
      // Goodreads cambió las columnas más de una vez. Buscándolas por
      // nombre, que falten no rompe: lo que no está, no viaja.
      final r = Goodreads.leer('Title\n"Cometierra"\n');

      expect(r.libros.single.titulo, 'Cometierra');
      expect(r.libros.single.autor, 'Autor desconocido');
      expect(r.libros.single.estado, Estado.pendiente);
    });

    test('columnas en otro orden dan lo mismo', () {
      // Un lector que cuente posiciones importaría todo corrido, y en
      // silencio.
      final r = Goodreads.leer(
        'Exclusive Shelf,My Rating,Author,Title\n'
        'read,3,"Dolores Reyes","Cometierra"\n',
      );

      expect(r.libros.single.titulo, 'Cometierra');
      expect(r.libros.single.autor, 'Dolores Reyes');
      expect(r.libros.single.puntaje, 3);
      expect(r.libros.single.estado, Estado.leido);
    });

    test('los finales de línea de Windows no dejan basura', () {
      final r = Goodreads.leer('Title,Author\r\n"Cometierra","Dolores"\r\n');

      expect(r.libros.single.titulo, 'Cometierra');
      expect(r.libros.single.autor, 'Dolores');
    });
  });

  group('lo que se guarda queda guardado', () {
    test('un libro importado sobrevive a cerrar la app', () {
      final libro = Goodreads.leer(_archivo).libros.first;
      final vuelto = Libro.desdeJson(libro.aJson());

      expect(vuelto.titulo, 'Cometierra');
      expect(vuelto.isbn, '9789874063656');
      expect(vuelto.puntaje, 5);
      expect(vuelto.estantes, {'favoritos', 'terror'});
      expect(vuelto.terminado, DateTime(2019, 3, 15));
      expect(vuelto.resena, contains('veo cosas'));
    });
  });
}
