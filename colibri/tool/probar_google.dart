import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/api.dart';
import 'package:colibri/google.dart';
import 'package:colibri/isbn.dart';

/// Verificación de Google Books contra Google Books.
///
/// **Correr esto una vez antes de confiar en el segundo catálogo.** Las
/// pruebas de `test/google_test.dart` usan respuestas armadas a mano,
/// porque cuando se escribió el código la cuota anónima de Google estaba
/// agotada y no hubo forma de traer una real. Si Google contesta con una
/// forma que no previmos, aquellas pasan igual y esta no.
///
///     flutter test tool/probar_google.dart --dart-define-from-file=claves.json
void main() {
  const porTitulo = [
    'Cometierra Dolores Reyes',
    'Las malas Camila Sosa Villada',
    'Catedrales Claudia Pineiro',
    'Nuestra parte de noche Mariana Enriquez',
  ];

  // El primero es real y Open Library lo tiene: sirve de control, si ese
  // falla el problema es otro. Los otros dos son códigos con prefijo
  // argentino y dígito de control válido, pero **no sabemos si existen**:
  // están para ver si Google contesta donde Open Library no.
  //
  // Lo que de verdad vale es que agregues acá los ISBN de los libros que
  // tenés en tu casa. Son los únicos que importan.
  const porCodigo = ['9789874063656', '9789878918273', '9789504983057'];

  test(
    'Google Books contesta y la app lo entiende',
    () async {
      if (!Google.disponible) {
        fail(
          'No hay clave.\n\n'
          'Sacá una gratis en console.cloud.google.com, activá la Books API '
          'y ponela en colibri/claves.json:\n\n'
          '    { "GOOGLE_BOOKS": "tu_clave" }\n\n'
          'Ese archivo está ignorado por Git y no se sube a ningún lado.',
        );
      }

      // ignore: avoid_print
      print('\n--- por título ---');
      for (final consulta in porTitulo) {
        final deGoogle = await Google.buscar(consulta, maximo: 1);
        final libro = deGoogle.isEmpty ? null : deGoogle.first;
        // ignore: avoid_print
        print(
          '${consulta.padRight(42)} '
          '${libro == null ? "— nada —" : "${libro.titulo} / ${libro.autor}"}',
        );
        if (libro?.tapaUrl != null) {
          // ignore: avoid_print
          print('${" " * 42} tapa: ${libro!.tapaUrl}');
        }
      }

      // ignore: avoid_print
      print('\n--- por código de barras: Open Library vs Google ---');
      for (final codigo in porCodigo) {
        final abierto = await Api.porIsbn(codigo);
        final google = await Google.porIsbn(codigo);
        // ignore: avoid_print
        print(
          '${codigo.padRight(16)} ${Isbn.queEs(codigo).name.padRight(9)} '
          'openlibrary+google=${(abierto?.titulo ?? "— nada —").padRight(30)} '
          'solo google=${google?.titulo ?? "— nada —"}',
        );
      }

      expect(
        await Google.buscar('cometierra', maximo: 1),
        isNotEmpty,
        reason: 'si esto falla, la clave no está activada para la Books API',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
