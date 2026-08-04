import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/cuenta.dart';

final _hoy = DateTime(2026, 8, 4);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('el nombre de usuario', () {
    test('la arroba y las mayúsculas no cuentan', () {
      // Sería absurdo que @Lucia y lucia fueran dos personas distintas.
      for (final escrito in [
        'lucia',
        '@lucia',
        'Lucia',
        '@LUCIA',
        ' @Lucia ',
      ]) {
        expect(Usuario.limpiar(escrito), 'lucia', reason: 'con «$escrito»');
      }
    });

    test('acepta los que están bien', () {
      for (final u in ['lucia', 'lu.lectora', 'ana_2', 'sofi.lee_libros']) {
        expect(Usuario.sirve(u), isTrue, reason: '«$u» debería servir');
      }
    });

    group('y lo que rechaza', () {
      test('demasiado corto o demasiado largo', () {
        expect(Usuario.queEstaMal('lu'), contains('al menos'));
        expect(Usuario.queEstaMal('a' * 21), contains('No puede pasar'));
      });

      test('que no empiece con letra', () {
        // Si empezara con número, un @usuario y un identificador serían
        // indistinguibles el día que existan las dos cosas.
        expect(Usuario.queEstaMal('1lucia'), contains('empezar con una letra'));
        expect(Usuario.queEstaMal('_lucia'), contains('empezar con una letra'));
      });

      test('caracteres que no van', () {
        for (final u in ['lucía', 'lu cia', 'lu-cia', 'lu@cia', 'lu!']) {
          expect(Usuario.sirve(u), isFalse, reason: '«$u» no debería servir');
        }
      });

      test('puntos y guiones al final o repetidos', () {
        // Dos puntos seguidos se leen mal y se copian peor; y un punto al
        // final se pierde cuando alguien escribe el @usuario en un texto.
        expect(Usuario.queEstaMal('lucia.'), contains('terminar'));
        expect(Usuario.queEstaMal('lucia_'), contains('terminar'));
        expect(Usuario.queEstaMal('lu..cia'), contains('dos puntos'));
        expect(Usuario.queEstaMal('lu__cia'), contains('dos puntos'));
      });

      test('los nombres reservados', () {
        // Si alguien se queda con «ayuda», el día que exista una cuenta de
        // ayuda no se le puede pedir que la devuelva.
        for (final u in ['admin', 'colibri', 'ayuda', '@Soporte']) {
          expect(Usuario.sirve(u), isFalse, reason: '«$u» está reservado');
        }
      });

      test('cada problema dice qué arreglar', () {
        // «Ese usuario no sirve» no le dice a nadie qué hacer.
        final motivos = {
          Usuario.queEstaMal('lu'),
          Usuario.queEstaMal('1lucia'),
          Usuario.queEstaMal('lucia.'),
          Usuario.queEstaMal('admin'),
        };
        expect(motivos, hasLength(4));
        expect(motivos.every((m) => m != null && m.length > 10), isTrue);
      });
    });
  });

  group('crear el perfil', () {
    test('se guarda y sobrevive a cerrar la app', () async {
      final c = Cuenta();
      final r = await c.crear(
        usuario: '@Lucia',
        nombre: 'Lucía',
        presentacion: 'Leo de noche',
        hoy: _hoy,
      );

      expect(r.bien, isTrue);

      final otra = Cuenta();
      await otra.cargar();

      expect(otra.hayPerfil, isTrue);
      expect(otra.perfil!.usuario, 'lucia', reason: 'guardado en minúsculas');
      expect(otra.perfil!.nombre, 'Lucía');
      expect(otra.perfil!.presentacion, 'Leo de noche');
      expect(otra.perfil!.desde, _hoy);
    });

    test('un usuario inválido no crea nada y explica por qué', () async {
      final c = Cuenta();
      final r = await c.crear(usuario: 'lu', nombre: 'Lucía', hoy: _hoy);

      expect(r.bien, isFalse);
      expect(r.problema, contains('al menos'));
      expect(c.hayPerfil, isFalse);
    });

    test('sin nombre igual se puede: se muestra el @usuario', () async {
      final c = Cuenta();
      await c.crear(usuario: 'lucia', nombre: '', hoy: _hoy);

      expect(c.perfil!.comoSeLlama, '@lucia');
      expect(c.perfil!.inicial, 'L');
    });
  });

  group('editar el perfil', () {
    Future<Cuenta> conPerfil() async {
      final c = Cuenta();
      await c.crear(usuario: 'lucia', nombre: 'Lucía', hoy: _hoy);
      return c;
    }

    test('cambia nombre y presentación', () async {
      final c = await conPerfil();
      final r = await c.editar(nombre: 'Lu', presentacion: 'Terror y poesía');

      expect(r.bien, isTrue);
      expect(c.perfil!.nombre, 'Lu');
      expect(c.perfil!.presentacion, 'Terror y poesía');
      expect(c.perfil!.usuario, 'lucia', reason: 'el usuario no se tocó');
    });

    test('cambiar el usuario a uno inválido no rompe el que tenías', () async {
      final c = await conPerfil();
      final r = await c.editar(usuario: 'admin');

      expect(r.bien, isFalse);
      expect(c.perfil!.usuario, 'lucia');
    });

    test('la fecha de cuándo llegaste no se toca', () async {
      final c = await conPerfil();
      await c.editar(nombre: 'Otra', usuario: 'otra.lucia');

      expect(c.perfil!.desde, _hoy);
    });

    test('sin perfil no hay nada que editar', () async {
      final c = Cuenta();
      final r = await c.editar(nombre: 'Lu');

      expect(r.bien, isFalse);
    });
  });

  group('el avatar dibujado', () {
    test('el color sale del usuario y no cambia nunca', () {
      // Si cambiara en cada arranque, tu cara en la app sería otra cada
      // vez que abrís.
      final uno = Perfil(usuario: 'lucia', nombre: 'Lucía', desde: _hoy);
      final otroIgual = Perfil(usuario: 'lucia', nombre: 'Otro', desde: _hoy);
      final distinto = Perfil(usuario: 'sofia', nombre: 'Lucía', desde: _hoy);

      expect(uno.tono, otroIgual.tono);
      expect(uno.tono, isNot(distinto.tono));
      expect(uno.tono, inInclusiveRange(0, 1));
    });
  });

  group('sin servidor', () {
    test('la app lo sabe y lo dice', () {
      final c = Cuenta();
      expect(c.servidor.disponible, isFalse);
      expect(c.estaARescate, isFalse);
    });

    test('entrar explica que no hay dónde, en vez de fallar callado', () async {
      final c = Cuenta();
      final r = await c.entrar(correo: 'lucia@correo.com', clave: 'x');

      expect(r.bien, isFalse);
      expect(r.problema, contains('servidor'));
    });

    test('el perfil se crea igual: no todo necesita servidor', () async {
      final c = Cuenta();
      final r = await c.crear(usuario: 'lucia', nombre: 'Lucía', hoy: _hoy);

      expect(r.bien, isTrue);
      expect(c.hayPerfil, isTrue);
      // Pero no está a salvo, y la diferencia importa.
      expect(c.estaARescate, isFalse);
    });
  });

  group('salir', () {
    test('borra el perfil de este teléfono', () async {
      final c = Cuenta();
      await c.crear(usuario: 'lucia', nombre: 'Lucía', hoy: _hoy);
      await c.salir();

      expect(c.hayPerfil, isFalse);

      final otra = Cuenta();
      await otra.cargar();
      expect(otra.hayPerfil, isFalse);
    });
  });

  group('un perfil roto no rompe la app', () {
    test('si lo guardado no se entiende, se arranca sin perfil', () async {
      SharedPreferences.setMockInitialValues({
        'colibri.perfil.v1': 'esto no es json',
      });

      final c = Cuenta();
      await c.cargar();

      expect(c.hayPerfil, isFalse);
    });
  });

  group('la foto de perfil', () {
    test('se guarda y sobrevive a cerrar la app', () async {
      final c = Cuenta();
      await c.crear(
        usuario: 'lucia',
        nombre: 'Lucía',
        foto: 'unafotoenbase64',
        hoy: _hoy,
      );

      final otra = Cuenta();
      await otra.cargar();

      expect(otra.perfil!.foto, 'unafotoenbase64');
    });

    test('se puede cambiar por otra', () async {
      final c = Cuenta();
      await c.crear(
        usuario: 'lucia',
        nombre: 'Lucía',
        foto: 'vieja',
        hoy: _hoy,
      );

      await c.editar(foto: 'nueva');

      expect(c.perfil!.foto, 'nueva');
    });

    test('se puede sacar y volver a la inicial', () async {
      // `foto: null` no se distingue de «no me lo pasaste», así que sin
      // un pedido explícito no habría forma de borrarla.
      final c = Cuenta();
      await c.crear(usuario: 'lucia', nombre: 'Lucía', foto: 'algo', hoy: _hoy);

      await c.editar(sacarFoto: true);

      expect(c.perfil!.foto, isNull);

      final otra = Cuenta();
      await otra.cargar();
      expect(otra.perfil!.foto, isNull, reason: 'sacada también al guardar');
    });

    test('editar otra cosa no borra la foto sin querer', () async {
      final c = Cuenta();
      await c.crear(usuario: 'lucia', nombre: 'Lucía', foto: 'algo', hoy: _hoy);

      await c.editar(nombre: 'Lu', presentacion: 'Leo de noche');

      expect(c.perfil!.foto, 'algo');
    });

    test('un perfil sin foto no inventa ninguna', () async {
      final c = Cuenta();
      await c.crear(usuario: 'lucia', nombre: 'Lucía', hoy: _hoy);

      expect(c.perfil!.foto, isNull);
      expect(c.perfil!.inicial, 'L', reason: 'ahí va la inicial');
    });
  });
}
