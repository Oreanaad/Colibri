import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/cuenta.dart';

/// Que la fila de `perfiles` exista antes de que se suba un solo libro.
///
/// # El bug, visto en los datos de verdad
///
/// Al entrar con la cuenta en otro aparato, la app arranca a subir la
/// biblioteca. Cada libro crea una fila en `obras` y otra en `ediciones`, y
/// `ediciones` tiene una clave ajena que `obras` no tiene:
///
///     cargada_por uuid references perfiles(id)
///
/// Sin fila en `perfiles`, la obra entra y **la edición rebota**. Sin
/// edición no hay lectura, y sin lectura el libro no existe del otro lado.
///
/// En la base había catorce obras creadas en nueve segundos y **cero**
/// ediciones de esas catorce, más cuatro ediciones creadas media hora
/// después —de a una, cuando el perfil ya existía— que sí funcionaron. El
/// patrón no era de datos, era de orden.
///
/// Y no se notaba, porque `Nube.subirLibro` se traga los errores a
/// propósito, para que quedarse sin señal no rompa la app. Tragárselo está
/// bien; no contarlo, no: `sincronizar` ahora devuelve cuántos fallaron.
///
/// # Qué se prueba acá
///
/// El orden, con un servidor de mentira que anota qué se le pidió y cuándo.
/// La clave ajena la garantiza Postgres; lo que la app tiene que garantizar
/// es no empezar a subir antes de tiempo.
class _ServidorDePrueba implements ServidorDeCuentas {
  /// El perfil que hay «del otro lado», o null si la cuenta no tiene.
  Perfil? enElServidor;

  final List<String> loQueSePidio = [];

  @override
  bool get disponible => true;

  @override
  Future<Resultado> entrar({
    required String correo,
    required String clave,
  }) async {
    loQueSePidio.add('entrar');
    return const Resultado.bien();
  }

  @override
  Future<Perfil?> miPerfil() async {
    loQueSePidio.add('miPerfil');
    return enElServidor;
  }

  @override
  Future<Resultado> guardarPerfil(Perfil perfil) async {
    loQueSePidio.add('guardarPerfil');
    enElServidor = perfil;
    return const Resultado.bien();
  }

  @override
  Future<Resultado> crear({
    required Perfil perfil,
    String? correo,
    String? clave,
  }) async {
    loQueSePidio.add('crear');
    enElServidor = perfil;
    return const Resultado.bien();
  }

  @override
  Future<bool> usuarioLibre(String usuario) async => true;

  @override
  Future<void> salir() async {}
}

void main() {
  late _ServidorDePrueba servidor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    servidor = _ServidorDePrueba();
    cuenta.servidor = servidor;
    await cuenta.salir();
  });

  tearDown(() => cuenta.servidor = const SinServidor());

  group('al entrar', () {
    test('el perfil se resuelve, no se deja para después', () {
      // La prueba de fondo: entrar tiene que dejar tocada la tabla de
      // perfiles, de una forma o de la otra, antes de devolver.
      return cuenta
          .entrar(correo: 'lectora@correo.com', clave: 'unaClave123')
          .then((_) {
            expect(servidor.loQueSePidio.first, 'entrar');
            expect(
              servidor.loQueSePidio,
              contains('miPerfil'),
              reason: 'sin esto, la subida arranca sin fila en perfiles',
            );
          });
    });

    test('si hay perfil del otro lado, se adopta', () async {
      // El caso de entrar desde un teléfono nuevo: la cuenta existe, el
      // perfil está en el servidor, y este aparato no sabe nada.
      servidor.enElServidor = Perfil(
        usuario: 'oreanaad',
        nombre: 'Oreana',
        desde: DateTime(2026, 1, 1),
      );

      await cuenta.entrar(correo: 'a@b.com', clave: 'unaClave123');

      expect(cuenta.perfil?.usuario, 'oreanaad');
      expect(cuenta.perfil?.nombre, 'Oreana');
    });

    test('lo de arriba manda sobre lo que tenga este aparato', () async {
      // Si entraste desde otro teléfono, tu @usuario es el que ya elegiste,
      // no el que quedó escrito acá.
      await cuenta.crear(usuario: 'viejo', nombre: 'Nombre viejo');
      servidor.enElServidor = Perfil(
        usuario: 'oreanaad',
        nombre: 'Oreana',
        desde: DateTime(2026, 1, 1),
      );

      await cuenta.entrar(correo: 'a@b.com', clave: 'unaClave123');

      expect(cuenta.perfil?.usuario, 'oreanaad');
    });

    test('si no hay perfil del otro lado pero sí acá, se sube', () async {
      // El caso de haber armado el perfil sin cuenta y registrarse después.
      await cuenta.crear(usuario: 'lectora', nombre: 'Lectora');
      servidor.enElServidor = null;
      servidor.loQueSePidio.clear();

      await cuenta.entrar(correo: 'a@b.com', clave: 'unaClave123');

      expect(servidor.loQueSePidio, contains('guardarPerfil'));
      expect(
        servidor.enElServidor?.usuario,
        'lectora',
        reason: 'cuando entrar termina, la fila tiene que existir',
      );
    });

    test('la foto de arriba gana si hay', () async {
      await cuenta.crear(usuario: 'lectora', nombre: 'L', foto: 'la de acá');
      servidor.enElServidor = Perfil(
        usuario: 'lectora',
        nombre: 'L',
        desde: DateTime(2026, 1, 1),
        foto: 'la de arriba',
      );

      await cuenta.entrar(correo: 'a@b.com', clave: 'unaClave123');

      expect(cuenta.perfil?.foto, 'la de arriba');
    });

    test('sin foto arriba, se conserva la de este aparato', () async {
      // Cubre dos casos de verdad: una cuenta creada antes de que las
      // fotos viajaran, y una base a la que todavía no le corrieron
      // perfil_completo.sql. En los dos, quedarse sin cara sería una
      // pérdida y no una sincronización.
      await cuenta.crear(usuario: 'lectora', nombre: 'L', foto: 'unaFoto');
      servidor.enElServidor = Perfil(
        usuario: 'lectora',
        nombre: 'L',
        desde: DateTime(2026, 1, 1),
      );

      await cuenta.entrar(correo: 'a@b.com', clave: 'unaClave123');

      expect(cuenta.perfil?.foto, 'unaFoto');
    });

    test('los libros y las insignias vuelven del servidor', () async {
      // Lo que faltaba: entrar desde otro aparato traía el nombre y nada
      // más, porque la tabla no tenía dónde guardar esto.
      servidor.enElServidor = Perfil(
        usuario: 'lectora',
        nombre: 'L',
        desde: DateTime(2026, 1, 1),
        libros: ['uno|autor', 'dos|autor'],
        insignias: ['hp.slytherin'],
      );

      await cuenta.entrar(correo: 'a@b.com', clave: 'unaClave123');

      expect(cuenta.perfil?.libros, ['uno|autor', 'dos|autor']);
      expect(cuenta.perfil?.insignias, ['hp.slytherin']);
    });

    test('lo de acá NO se borra si arriba está vacío', () async {
      // El bug, y era pérdida de datos:
      //
      // Una cuenta creada cuando la tabla todavía no guardaba la foto, los
      // tres libros ni las insignias tiene esa fila del otro lado con esos
      // campos vacíos. Adoptarla entera **le borraba a la lectora sus tres
      // libros y sus insignias del teléfono**, que era el único lugar donde
      // estaban. Y como arriba ya había una fila, tampoco se subían nunca:
      // quedaban borrados de los dos lados.
      await cuenta.crear(
        usuario: 'lectora',
        nombre: 'L',
        foto: 'mi cara',
        libros: ['uno|a', 'dos|b'],
        insignias: ['hp.slytherin'],
      );
      servidor.enElServidor = Perfil(
        usuario: 'lectora',
        nombre: 'L',
        desde: DateTime(2026, 1, 1),
      );
      servidor.loQueSePidio.clear();

      await cuenta.entrar(correo: 'a@b.com', clave: 'unaClave123');

      expect(cuenta.perfil?.foto, 'mi cara');
      expect(cuenta.perfil?.libros, ['uno|a', 'dos|b']);
      expect(cuenta.perfil?.insignias, ['hp.slytherin']);

      // Y además se sube, que es la otra mitad: sin esto se quedaría en
      // este teléfono para siempre, porque ninguna otra parte de la app
      // vuelve a subir el perfil sola.
      expect(servidor.loQueSePidio, contains('guardarPerfil'));
      expect(servidor.enElServidor?.libros, ['uno|a', 'dos|b']);
      expect(servidor.enElServidor?.foto, 'mi cara');
    });

    test('lo de arriba gana cuando arriba tiene algo', () async {
      // La otra mitad de la regla: si de verdad hay libros del otro lado,
      // esos mandan. Es el caso de entrar desde un teléfono nuevo.
      await cuenta.crear(usuario: 'lectora', nombre: 'L', libros: ['viejo|x']);
      servidor.enElServidor = Perfil(
        usuario: 'lectora',
        nombre: 'L',
        desde: DateTime(2026, 1, 1),
        libros: ['nuevo|y'],
      );

      await cuenta.entrar(correo: 'a@b.com', clave: 'unaClave123');

      expect(cuenta.perfil?.libros, ['nuevo|y']);
    });

    test('si no falta nada arriba, no se sube de más', () async {
      // Un pedido de red por cada arranque de la app, para mandar lo mismo
      // que ya está, es un pedido al pedo.
      await cuenta.crear(usuario: 'lectora', nombre: 'L', libros: ['uno|a']);
      servidor.enElServidor = Perfil(
        usuario: 'lectora',
        nombre: 'L',
        desde: DateTime(2026, 1, 1),
        libros: ['uno|a'],
        foto: 'una cara',
        insignias: ['hp.slytherin'],
      );
      servidor.loQueSePidio.clear();

      await cuenta.asegurarElPerfil();

      expect(servidor.loQueSePidio, isNot(contains('guardarPerfil')));
    });

    test('si la contraseña está mal, no se toca ningún perfil', () async {
      cuenta.servidor = _ServidorQueRechaza();

      final r = await cuenta.entrar(correo: 'a@b.com', clave: 'mala');

      expect(r.bien, isFalse);
      expect(cuenta.perfil, isNull);
    });
  });

  group('sin servidor', () {
    test('asegurarElPerfil no hace nada ni se cae', () async {
      cuenta.servidor = const SinServidor();
      await cuenta.asegurarElPerfil();
      expect(cuenta.perfil, isNull);
    });
  });
}

class _ServidorQueRechaza extends _ServidorDePrueba {
  @override
  Future<Resultado> entrar({
    required String correo,
    required String clave,
  }) async => const Resultado.mal('Correo o contraseña incorrectos.');
}
