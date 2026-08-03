import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/api.dart';
import 'package:colibri/isbn.dart';

/// Verificación contra Open Library de verdad.
///
/// **No entra en la suite normal**: vive fuera de `test/`, así que
/// `flutter test` no lo levanta. Necesita internet y depende de que un
/// catálogo ajeno siga teniendo los mismos libros, y un test que se rompe
/// porque alguien editó una ficha del otro lado del mundo es un test que
/// se termina ignorando.
///
/// Se corre a mano cuando se toca la búsqueda por ISBN:
///
///     flutter test tool/probar_isbn.dart
void main() {
  const casos = {
    '9789874063656': 'Cometierra, edición argentina',
    '978-1-5143-8596-8': 'Pedro Páramo, escrito con guiones',
    '9789500767170': 'Cien años de soledad',
    '0140449132': 'un ISBN viejo, de diez dígitos',
    '9789874063657': 'control roto: no tiene que salir a internet',
    '7790123450006': 'un producto que no es un libro',
  };

  test(
    'la búsqueda por ISBN contra Open Library',
    () async {
      for (final caso in casos.entries) {
        final que = Isbn.queEs(caso.key);
        final libro = await Api.porIsbn(caso.key);
        final resultado = libro == null
            ? '— nada —'
            : '${libro.titulo} / ${libro.autor}';
        // ignore: avoid_print
        print(
          '${caso.key.padRight(18)} ${que.name.padRight(10)} '
          '${resultado.padRight(46)} (${caso.value})',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
