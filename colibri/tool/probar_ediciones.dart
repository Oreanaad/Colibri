import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/api.dart';
import 'package:colibri/modelos.dart';

/// El filtro de idiomas contra Open Library de verdad.
///
/// Nació de un reporte: «si pongo todos veo portadas en español que si
/// pongo español no salen». Vive fuera de `test/` porque necesita internet
/// y depende de fichas que edita gente de todo el mundo.
///
///     flutter test tool/probar_ediciones.dart
void main() {
  const obras = {
    '/works/OL82563W': "Harry Potter and the Philosopher's Stone",
    '/works/OL27448W': 'The Lord of the Rings',
    '/works/OL1731119W': 'Pedro Páramo',
    '/works/OL274505W': 'Cien años de soledad',
  };

  test(
    'filtrar por español no esconde las ediciones en español',
    () async {
      for (final obra in obras.entries) {
        final libro = Libro(id: obra.key, titulo: obra.value, autor: '');

        final todas = await Api.ediciones(libro, maximo: 200);
        final enEspanol = await Api.ediciones(
          libro,
          idioma: 'spa',
          maximo: 200,
        );

        // ignore: avoid_print
        print(
          '\n${obra.value}\n'
          '  todas                    ${todas.confirmadas.length}\n'
          '  dicen estar en español   ${enEspanol.confirmadas.length}\n'
          '  no dicen nada            ${enEspanol.sinIdioma.length}',
        );

        final sospechosas = enEspanol.sinIdioma
            .where((e) => e.tapaId != null)
            .take(4);
        for (final e in sospechosas) {
          // ignore: avoid_print
          print('    sin idioma: ${e.titulo}  ·  ${e.editorial ?? "?"}');
        }

        expect(
          enEspanol.confirmadas.length + enEspanol.sinIdioma.length,
          greaterThan(enEspanol.confirmadas.length),
          reason:
              'si no aparece ninguna sin idioma, el arreglo no está haciendo '
              'nada y el filtro sigue escondiendo ediciones',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
