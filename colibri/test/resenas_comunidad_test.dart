import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/nube.dart';

/// Las reseñas que escribieron otras lectoras.
///
/// # Lo que se prueba acá y lo que no
///
/// [resenasDeFilas] es pura: recibe las filas que devuelve PostgREST y
/// devuelve reseñas, sin tocar la red. Eso se prueba entero acá.
///
/// Que la **consulta** sea válida contra el servidor de verdad no se puede
/// probar desde Dart, porque `flutter test` corta toda petición HTTP: lo
/// hace `servidor/probar_resenas.sh`.
///
/// # Lo que NO hace este código, y es a propósito
///
/// No filtra por «perfiles públicos». Eso lo hace la regla de `lecturas` en
/// el esquema: una lectura se ve si es tuya, o si hay sesión y el perfil es
/// público. Escribirlo también acá sería tener la misma decisión en dos
/// lugares, y el día que cambien uno solo, el que manda es el de la base.
void main() {
  Map<String, dynamic> fila({
    String resena = 'Una reseña',
    bool spoilers = false,
    String usuario = 'lectora',
    String nombre = 'Una Lectora',
    String perfilId = 'otra-persona',
    int puntaje = 0,
    String? terminado,
  }) => {
    'resena': resena,
    'resena_con_spoilers': spoilers,
    'puntaje': puntaje,
    'terminado': terminado,
    'perfil_id': perfilId,
    'perfiles': {'usuario': usuario, 'nombre': nombre},
  };

  group('convertir las filas en reseñas', () {
    test('saca el texto, la marca de spoilers y quién la escribió', () {
      final r = resenasDeFilas([
        fila(resena: 'Me arruinó la semana.', spoilers: true, puntaje: 5),
      ]);

      expect(r, hasLength(1));
      expect(r.first.texto, 'Me arruinó la semana.');
      expect(r.first.conSpoilers, isTrue);
      expect(r.first.puntaje, 5);
      expect(r.first.usuario, 'lectora');
    });

    test('se firma con el nombre, y con el @usuario si no puso nombre', () {
      expect(resenasDeFilas([fila(nombre: 'Caro')]).first.comoSeLlama, 'Caro');
      expect(
        resenasDeFilas([fila(nombre: '', usuario: 'caro')]).first.comoSeLlama,
        '@caro',
      );
      // Un nombre de espacios es lo mismo que no tener nombre.
      expect(
        resenasDeFilas([
          fila(nombre: '   ', usuario: 'caro'),
        ]).first.comoSeLlama,
        '@caro',
      );
    });

    test('una reseña vacía no es una reseña', () {
      // La consulta ya pide que no sea null, pero un texto de espacios pasa
      // ese filtro y en pantalla sería un hueco con una firma debajo.
      final r = resenasDeFilas([
        fila(resena: '   '),
        fila(resena: ''),
        fila(resena: 'Esta sí'),
      ]);

      expect(r, hasLength(1));
      expect(r.first.texto, 'Esta sí');
    });

    test('sin perfil no entra: no habría de quién es', () {
      final r = resenasDeFilas([
        {'resena': 'Huérfana', 'perfiles': null},
      ]);

      expect(r, isEmpty);
    });

    test('basura en la respuesta no rompe nada', () {
      final r = resenasDeFilas(['no soy un mapa', 42, null, fila()]);
      expect(r, hasLength(1));
    });

    test('una respuesta vacía devuelve vacío', () {
      expect(resenasDeFilas(const []), isEmpty);
    });
  });

  group('el orden', () {
    test('la más reciente primero', () {
      // Quien terminó el libro anteayer tiene más fresco lo que sintió que
      // quien lo terminó en 2019.
      final r = resenasDeFilas([
        fila(resena: 'vieja', terminado: '2019-01-01'),
        fila(resena: 'nueva', terminado: '2026-07-01'),
        fila(resena: 'media', terminado: '2023-03-01'),
      ]);

      expect(r.map((x) => x.texto), ['nueva', 'media', 'vieja']);
    });

    test('las que no anotaron cuándo van al final', () {
      // Un null suelto ordena primero, y las reseñas sin fecha taparían a
      // las que sí la tienen.
      final r = resenasDeFilas([
        fila(resena: 'sin fecha'),
        fila(resena: 'con fecha', terminado: '2020-01-01'),
      ]);

      expect(r.map((x) => x.texto), ['con fecha', 'sin fecha']);
    });

    test('la tuya va primera de todas, aunque sea la más vieja', () {
      // No por vanidad: es lo que hace que se entienda de un vistazo que
      // una de esas voces sos vos, en vez de leerla creyendo que es de otra
      // persona que dijo justo lo mismo.
      final r = resenasDeFilas([
        fila(resena: 'de otra', terminado: '2026-07-01'),
        fila(resena: 'la mía', perfilId: 'yo', terminado: '2001-01-01'),
      ], yo: 'yo');

      expect(r.first.texto, 'la mía');
      expect(r.first.esTuya, isTrue);
      expect(r.last.esTuya, isFalse);
    });

    test('sin sesión, ninguna es tuya', () {
      final r = resenasDeFilas([fila(perfilId: 'yo')]);
      expect(r.first.esTuya, isFalse);
    });
  });

  group('la consulta que se le manda al servidor', () {
    test('nunca pide edición Y fanfic con inner en la misma consulta', () {
      // El bug que esto atrapa, y que casi se escapó entero:
      //
      // La primera versión pedía `ediciones!inner` **y** `fanfics!inner` en
      // el mismo select. `!inner` es un inner join: exige coincidencia. Y
      // `lecturas` tiene un check que dice
      //
      //     check (num_nonnulls(edicion_id, fanfic_id) = 1)
      //
      // o sea que ninguna fila tiene las dos, nunca. Habría devuelto cero
      // reseñas siempre.
      //
      // Y no lo habría cazado nadie: la consulta es válida, el servidor
      // contesta 200, y devuelve una lista vacía —lo mismo que devuelve
      // cuando de verdad no hay reseñas—. Se vio leyendo el esquema.
      for (final consulta in [resenasDeUnLibro, resenasDeUnFanfic]) {
        final pideEdicion = consulta.contains('ediciones!inner');
        final pideFanfic = consulta.contains('fanfics!inner');
        expect(
          pideEdicion && pideFanfic,
          isFalse,
          reason: 'una lectura nunca tiene las dos cosas: $consulta',
        );
      }
    });

    test('las dos piden el perfil con inner', () {
      // Sin `!inner`, PostgREST devuelve también las lecturas cuyo perfil no
      // se puede ver, con el embebido en null.
      expect(resenasDeUnLibro, contains('perfiles!inner'));
      expect(resenasDeUnFanfic, contains('perfiles!inner'));
    });

    test('ninguna pide la nota privada', () {
      // Lo más importante de estas consultas es lo que **no** traen. Las
      // notas son de quien las escribió y la base no las dejaría salir, pero
      // pedirlas ya sería la señal de que alguien pensó que podía.
      for (final consulta in [resenasDeUnLibro, resenasDeUnFanfic]) {
        expect(consulta, isNot(contains('nota')));
      }
    });

    test('la de libros llega a la clave de la obra', () {
      expect(resenasDeUnLibro, contains('obras!inner(clave)'));
    });

    test('las dos traen perfil_id, que es como se sabe si es tuya', () {
      for (final consulta in [resenasDeUnLibro, resenasDeUnFanfic]) {
        expect(consulta, contains('perfil_id'));
      }
    });
  });
}
