import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import 'package:image/image.dart' as img;

import 'package:colibri/cuenta.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/crear_cuenta.dart';
import 'package:colibri/pantallas/vos.dart';
import 'package:colibri/widgets.dart';

/// Las pantallas de perfil y cuenta.
///
/// Lo que hay que garantizar acá es que **digan la verdad**: que no
/// prometan una cuenta que todavía no existe, y que no pidan una
/// contraseña que no tendríamos dónde guardar.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
    await cuenta.salir();
  });

  Future<void> abrir(WidgetTester tester, Widget pantalla) async {
    await tester.binding.setSurfaceSize(const Size(600, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: pantalla));
    await tester.pumpAndSettle();
  }

  group('armar el perfil', () {
    testWidgets('no deja guardar sin @usuario', (tester) async {
      await abrir(tester, const PantallaCrearCuenta());

      expect(
        tester.widget<BotonLleno>(find.byType(BotonLleno)).alTocar,
        isNull,
      );
    });

    testWidgets('no reta antes de que escribas nada', (tester) async {
      // Un formulario que te marca un error en un campo vacío que ni
      // tocaste es un formulario antipático.
      await abrir(tester, const PantallaCrearCuenta());

      expect(find.textContaining('al menos'), findsNothing);
      expect(find.textContaining('dirección de tu estante'), findsOneWidget);
    });

    testWidgets('dice qué está mal mientras escribís', (tester) async {
      await abrir(tester, const PantallaCrearCuenta());
      await tester.enterText(find.byType(TextField).first, 'lu');
      await tester.pump();

      expect(find.textContaining('al menos 3'), findsOneWidget);
    });

    testWidgets('muestra en qué te vas a convertir', (tester) async {
      await abrir(tester, const PantallaCrearCuenta());
      await tester.enterText(find.byType(TextField).first, '@Lu.Lectora');
      await tester.pump();

      expect(find.text('Vas a ser @lu.lectora.'), findsOneWidget);
    });

    testWidgets('guarda el perfil', (tester) async {
      // Empujada sobre otra pantalla y no sola: al guardar se cierra, y
      // cerrar la única ruta que hay es pedirle a Flutter algo que no
      // tiene sentido.
      await tester.binding.setSurfaceSize(const Size(600, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PantallaCrearCuenta()),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'lucia');
      await tester.pump();
      await tester.tap(find.byType(BotonLleno));
      await tester.pumpAndSettle();

      expect(cuenta.hayPerfil, isTrue);
      expect(cuenta.perfil!.usuario, 'lucia');
    });

    testWidgets('explica por qué no pide contraseña', (tester) async {
      // Es la parte que más importa de esta pantalla: que no parezca que
      // falta algo, sino que se entienda por qué todavía no va.
      await abrir(tester, const PantallaCrearCuenta());

      expect(find.text('¿Y LA CONTRASEÑA?'), findsOneWidget);
      expect(find.textContaining('no protegería nada'), findsOneWidget);
    });
  });

  group('entrar', () {
    testWidgets('dice que todavía no hay cuentas, en vez de fallar callada', (
      tester,
    ) async {
      await abrir(tester, const PantallaEntrar());

      expect(find.textContaining('Todavía no hay cuentas'), findsOneWidget);
      expect(
        tester.widget<BotonLleno>(find.byType(BotonLleno)).alTocar,
        isNull,
        reason: 'un botón que no puede funcionar no se puede tocar',
      );
    });
  });

  group('Vos', () {
    testWidgets('sin perfil invita a armarlo', (tester) async {
      await abrir(tester, const PantallaVos());

      expect(find.text('Todavía no tenés perfil.'), findsOneWidget);
      expect(find.text('Armar mi perfil'), findsOneWidget);
    });

    testWidgets('con perfil muestra quién sos y desde cuándo', (tester) async {
      await cuenta.crear(
        usuario: 'lucia',
        nombre: 'Lucía',
        presentacion: 'Leo de noche',
        hoy: DateTime(2026, 3, 12),
      );

      await abrir(tester, const PantallaVos());

      expect(find.text('Lucía'), findsOneWidget);
      expect(find.text('@lucia'), findsOneWidget);
      expect(find.text('Leo de noche'), findsOneWidget);
      expect(find.textContaining('Acá desde'), findsOneWidget);
      expect(find.byType(Avatar), findsOneWidget);
    });

    testWidgets('cuenta lo que leíste', (tester) async {
      final libro = Libro(
        id: '1',
        titulo: 'Cometierra',
        autor: 'Dolores Reyes',
        paginas: 176,
      );
      await biblioteca.agregar(libro);
      await biblioteca.cambiarEstado(libro, Estado.leido);
      libro.puntaje = 5;
      libro.animos.add('me destruyó');
      await biblioteca.actualizar();

      await cuenta.crear(usuario: 'lucia', nombre: 'Lucía');
      await abrir(tester, const PantallaVos());

      expect(find.text('1'), findsWidgets);
      expect(find.text('leídos'), findsOneWidget);
      expect(find.text('176'), findsOneWidget);
      expect(find.textContaining('me destruyó'), findsOneWidget);
    });

    testWidgets('avisa que todo vive en este teléfono', (tester) async {
      // Es la diferencia entre una app honesta y una que te hace creer
      // que tus cosas están a salvo.
      await cuenta.crear(usuario: 'lucia', nombre: 'Lucía');
      await abrir(tester, const PantallaVos());

      expect(find.text('TODO ESTO VIVE EN ESTE TELÉFONO'), findsOneWidget);
      expect(find.textContaining('Si perdés el teléfono'), findsOneWidget);
    });
  });

  group('el avatar', () {
    /// Una foto de verdad, chiquita, en el formato que se guarda.
    String unaFoto() {
      final i = img.Image(width: 8, height: 8);
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          i.setPixelRgb(x, y, 200, 40, 90);
        }
      }
      return base64Encode(img.encodeJpg(i));
    }

    testWidgets('sin foto muestra la inicial', (tester) async {
      await cuenta.crear(usuario: 'lucia', nombre: 'Lucía');
      await abrir(tester, const PantallaVos());

      expect(find.text('L'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('con foto la muestra en vez de la inicial', (tester) async {
      await cuenta.crear(usuario: 'lucia', nombre: 'Lucía', foto: unaFoto());
      await abrir(tester, const PantallaVos());

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('L'), findsNothing);
    });

    testWidgets('una foto rota vuelve a la inicial y no deja un hueco', (
      tester,
    ) async {
      // Lo guardado se puede corromper. Un cuadrado roto donde va tu cara
      // se ve peor que la inicial de siempre.
      await cuenta.crear(
        usuario: 'lucia',
        nombre: 'Lucía',
        foto: 'noesunafoto',
      );
      await abrir(tester, const PantallaVos());

      expect(tester.takeException(), isNull);
    });
  });

  group('elegir la foto', () {
    testWidgets('la invitación está arriba de todo, no escondida', (
      tester,
    ) async {
      // Es lo primero que alguien quiere tocar al armar un perfil. Al
      // final de la pantalla, la mitad de la gente ni se entera.
      await abrir(tester, const PantallaCrearCuenta());

      expect(find.text('Poner una foto'), findsOneWidget);
      expect(find.textContaining('va tu inicial'), findsOneWidget);
    });

    testWidgets('con foto puesta ofrece cambiarla y sacarla', (tester) async {
      await cuenta.crear(usuario: 'lucia', nombre: 'Lucía', foto: 'x');
      await abrir(tester, const PantallaCrearCuenta(editando: true));

      expect(find.text('Cambiarla'), findsOneWidget);
      expect(find.text('Sacarla'), findsOneWidget);
    });
  });

  group('la puerta para entrar a una cuenta que ya existe', () {
    /// Un servidor de mentira que dice que sí está.
    ///
    /// No hace falta que funcione: lo único que cambia la pantalla es si
    /// `disponible` es cierto.
    setUp(() => cuenta.servidor = const _ServidorDeMentira());
    tearDown(() => cuenta.servidor = const SinServidor());

    testWidgets('está en Vos cuando todavía no tenés perfil', (tester) async {
      // Estaba escondida adentro del texto que explica por qué no hay
      // contraseña, y ese texto solo aparece cuando NO hay servidor. O
      // sea que al conectar Supabase, la única forma de entrar a una
      // cuenta desapareció justo cuando empezó a servir.
      await abrir(tester, const PantallaVos());

      expect(find.text('Armar mi perfil'), findsOneWidget);
      expect(find.text('Ya tengo cuenta'), findsOneWidget);
    });

    testWidgets('y también desde el formulario', (tester) async {
      await abrir(tester, const PantallaCrearCuenta());

      expect(find.text('¿Ya tenés cuenta? Entrá'), findsOneWidget);
    });

    testWidgets('con servidor, el formulario pide correo y contraseña', (
      tester,
    ) async {
      await abrir(tester, const PantallaCrearCuenta());

      expect(find.text('TU CORREO'), findsOneWidget);
      expect(find.text('UNA CONTRASEÑA'), findsOneWidget);
      // Y ya no explica por qué no las pide, porque ahora las pide.
      expect(find.text('¿Y LA CONTRASEÑA?'), findsNothing);
    });

    testWidgets('sin @usuario válido no deja crear nada', (tester) async {
      await abrir(tester, const PantallaCrearCuenta());
      await tester.enterText(find.byType(TextField).first, 'lucia');
      await tester.pump();

      // Falta el correo y la contraseña.
      expect(
        tester.widget<BotonLleno>(find.byType(BotonLleno).first).alTocar,
        isNull,
      );
    });
  });

  group('entrar de verdad', () {
    // Este es el bug que se reportó: "apreté entrar y no pasó nada", una
    // y otra vez. La cuenta entraba —el servidor contestaba bien— pero la
    // pantalla no cerraba ni avisaba nada, así que no había manera de
    // saber que ya había funcionado.
    tearDown(() => cuenta.servidor = const SinServidor());

    testWidgets('si funciona, la pantalla se cierra y avisa', (tester) async {
      cuenta.servidor = const _ServidorDeMentira();

      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PantallaEntrar()),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'lucia@correo.com');
      await tester.enterText(find.byType(TextField).last, 'unaClave123');
      // find.text('Entrar') es ambiguo: también aparece en el título de
      // la barra. El botón es el único BotonLleno de la pantalla.
      await tester.tap(find.byType(BotonLleno));
      await tester.pump(); // arranca el pedido: el botón pasa a "Entrando…"

      expect(find.text('Entrando…'), findsOneWidget);

      await tester.pumpAndSettle(); // termina el pedido

      // La señal que faltaba: la pantalla de entrar ya no está.
      expect(find.byType(PantallaEntrar), findsNothing);
      expect(
        find.text('Sesión iniciada. Tu biblioteca se está subiendo.'),
        findsOneWidget,
      );

      // El aviso tiene su propio reloj para cerrarse solo, aparte del que
      // usa Flutter. Sin dejarlo terminar, la prueba se queda con un
      // temporizador pendiente y falla al cerrar, aunque la pantalla ya
      // haya hecho exactamente lo que tenía que hacer.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('mientras espera la respuesta, no deja apretar de nuevo', (
      tester,
    ) async {
      // Sin esto, cada toque de más durante la espera mandaba otro
      // pedido de entrar, y con conexión lenta alguien frustrada toca
      // varias veces antes de que llegue la primera respuesta.
      cuenta.servidor = const _ServidorDeMentira();
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PantallaEntrar())),
      );

      await tester.enterText(find.byType(TextField).first, 'lucia@correo.com');
      await tester.enterText(find.byType(TextField).last, 'unaClave123');
      await tester.tap(find.byType(BotonLleno));
      await tester.pump();

      expect(
        tester.widget<BotonLleno>(find.byType(BotonLleno)).alTocar,
        isNull,
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4)); // el reloj del aviso
    });

    testWidgets('si falla, se queda en la pantalla y avisa por qué', (
      tester,
    ) async {
      cuenta.servidor = const _ServidorDeMentira(
        fallaAlEntrar: 'Ese correo y esa contraseña no coinciden.',
      );
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PantallaEntrar())),
      );

      await tester.enterText(find.byType(TextField).first, 'lucia@correo.com');
      await tester.enterText(find.byType(TextField).last, 'malaClave');
      await tester.tap(find.byType(BotonLleno));
      await tester.pumpAndSettle();

      expect(find.byType(PantallaEntrar), findsOneWidget);
      expect(
        find.text('Ese correo y esa contraseña no coinciden.'),
        findsOneWidget,
      );
      // Y se puede volver a intentar: el botón no se queda trabado.
      expect(
        tester.widget<BotonLleno>(find.byType(BotonLleno)).alTocar,
        isNotNull,
      );
    });
  });
}

/// Un servidor que solo dice que existe, para las pruebas de pantalla.
///
/// [fallaAlEntrar] deja probar el otro camino de `_entrar()`: cuando el
/// correo o la contraseña no coinciden, sin tener que fallar contra la
/// base de verdad.
class _ServidorDeMentira implements ServidorDeCuentas {
  final String? fallaAlEntrar;
  const _ServidorDeMentira({this.fallaAlEntrar});

  @override
  bool get disponible => true;

  @override
  Future<Resultado> crear({
    required Perfil perfil,
    String? correo,
    String? clave,
  }) async => const Resultado.bien();

  @override
  Future<Resultado> entrar({
    required String correo,
    required String clave,
  }) async => fallaAlEntrar != null
      ? Resultado.mal(fallaAlEntrar)
      : const Resultado.bien();

  @override
  Future<void> salir() async {}

  @override
  Future<Perfil?> miPerfil() async => null;

  @override
  Future<bool> usuarioLibre(String usuario) async => true;

  @override
  Future<Resultado> guardarPerfil(Perfil perfil) async =>
      const Resultado.bien();
}
