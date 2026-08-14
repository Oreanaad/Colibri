import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/cuenta.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/vos.dart';

/// Cerrar sesión, que antes no existía.
///
/// # Por qué hacía falta separarlo
///
/// Había un solo botón, «Borrar mi perfil», que hacía las dos cosas: cerrar
/// la sesión **y** borrar el perfil del teléfono. Y con servidor el nombre
/// mentía: «borrar» no borraba nada de la nube —la cuenta seguía ahí con
/// todo lo subido— pero quien lo tocaba no tenía forma de saberlo.
///
/// Son dos intenciones distintas: «me voy de esta cuenta en este aparato» y
/// «no quiero tener perfil». Merecen dos botones.
///
/// # Los libros
///
/// Se quedan en el teléfono, por la misma razón de siempre: los leíste vos,
/// no la cuenta. Pero eso tiene una consecuencia que no es obvia y que el
/// diálogo dice: si después entra otra persona en el mismo teléfono, esos
/// libros se le subirían **a su cuenta**. Por eso hay una segunda salida
/// que los saca, en vez de elegir por la lectora.
class _ServidorDePrueba implements ServidorDeCuentas {
  Perfil? enElServidor;
  bool cerroSesion = false;

  @override
  bool get disponible => true;

  @override
  Future<Resultado> entrar({
    required String correo,
    required String clave,
  }) async => const Resultado.bien();

  @override
  Future<Perfil?> miPerfil() async => enElServidor;

  @override
  Future<Resultado> guardarPerfil(Perfil perfil) async {
    enElServidor = perfil;
    return const Resultado.bien();
  }

  @override
  Future<Resultado> crear({
    required Perfil perfil,
    String? correo,
    String? clave,
  }) async {
    enElServidor = perfil;
    return const Resultado.bien();
  }

  @override
  Future<bool> usuarioLibre(String usuario) async => true;

  @override
  Future<void> salir() async => cerroSesion = true;
}

void main() {
  late _ServidorDePrueba servidor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    servidor = _ServidorDePrueba();
    cuenta.servidor = servidor;
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
    await cuenta.crear(usuario: 'lectora', nombre: 'Lectora');
    for (var i = 0; i < 3; i++) {
      await biblioteca.agregar(
        Libro(id: '$i', titulo: 'Libro $i', autor: 'Alguien'),
      );
    }
  });

  tearDown(() => cuenta.servidor = const SinServidor());

  Future<void> abrir(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: PantallaVos()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cerrar sesión'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('el botón', () {
    testWidgets('con cuenta están los dos, y dicen cosas distintas', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Cerrar sesión'), findsOneWidget);
      // Y el otro dice que es de **este teléfono**, porque con servidor no
      // borra la cuenta y decir «borrar mi perfil» a secas haría creer que sí.
      expect(find.text('Borrar el perfil de este teléfono'), findsOneWidget);
    });

    testWidgets('sin cuenta no hay sesión que cerrar', (tester) async {
      cuenta.servidor = const SinServidor();

      await tester.binding.setSurfaceSize(const Size(420, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: PantallaVos()));
      await tester.pumpAndSettle();

      expect(find.text('Cerrar sesión'), findsNothing);
      // Y ahí sí es «borrar mi perfil» a secas, porque este teléfono es el
      // único lugar donde existe.
      expect(find.text('Borrar mi perfil'), findsOneWidget);
    });
  });

  group('cerrar sesión', () {
    testWidgets('avisa qué se queda y qué no antes de hacer nada', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.textContaining('entrás de nuevo cuando quieras'), findsOne);
      expect(find.textContaining('Los 3 libros'), findsOneWidget);
      // Y todavía no pasó nada.
      expect(cuenta.hayPerfil, isTrue);
      expect(servidor.cerroSesion, isFalse);
    });

    testWidgets('cancelar no hace nada', (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(cuenta.hayPerfil, isTrue);
      expect(servidor.cerroSesion, isFalse);
      expect(biblioteca.todos, hasLength(3));
    });

    testWidgets('sale y deja los libros', (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión').last);
      await tester.pumpAndSettle();

      expect(servidor.cerroSesion, isTrue);
      expect(cuenta.hayPerfil, isFalse);
      expect(
        biblioteca.todos,
        hasLength(3),
        reason: 'los libros son tuyos, no de la cuenta',
      );

      await tester.pump(const Duration(seconds: 4)); // el aviso tiene reloj
    });

    testWidgets('la otra salida saca también los libros', (tester) async {
      // Para cuando le prestás el teléfono a alguien: si quedan, al entrar
      // con otra cuenta se le subirían a esa.
      await abrir(tester);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir y sacar los libros'));
      await tester.pumpAndSettle();

      expect(servidor.cerroSesion, isTrue);
      expect(cuenta.hayPerfil, isFalse);
      expect(biblioteca.todos, isEmpty);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('sin libros no se ofrece sacarlos', (tester) async {
      for (final l in [...biblioteca.todos]) {
        await biblioteca.quitar(l);
      }

      await abrir(tester);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Salir y sacar los libros'), findsNothing);
    });
  });
}
