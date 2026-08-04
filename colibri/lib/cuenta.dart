/// Quién sos en Colibrí.
///
/// # Lo que hay hoy y lo que falta
///
/// Hoy Colibrí no tiene servidor: **todo vive en tu teléfono**. Eso alcanza
/// para tener perfil —un nombre, un @usuario, una presentación— y es lo
/// que va a mostrarse cuando alguien entre a tu estante.
///
/// Lo que **no** alcanza es para tener cuenta de verdad. Una cuenta sirve
/// para dos cosas: que tu biblioteca sobreviva a perder el teléfono, y que
/// tu @usuario sea tuyo y de nadie más. Las dos necesitan que haya algo
/// del otro lado.
///
/// # Por qué no se pide contraseña
///
/// Podríamos pedirla y guardarla acá, y funcionaría de mentira: la única
/// forma de guardar una contraseña con seguridad es no guardarla, sino
/// guardar una huella suya en un servidor preparado para eso. Guardarla en
/// el teléfono sería peor que no tener contraseña, porque **la gente
/// repite contraseñas** y estaríamos dejando la de su correo tirada en un
/// archivo del teléfono.
///
/// Así que hasta que haya servidor no se pide, y la pantalla lo dice.
///
/// # La frontera
///
/// [ServidorDeCuentas] es lo que un servidor tiene que saber hacer.
/// [SinServidor] es la implementación de hoy. Cuando exista uno de verdad,
/// se escribe otra implementación y **no se toca ninguna pantalla**.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las reglas de un @usuario.
///
/// Es el único dato que después no se va a poder cambiar a la ligera,
/// porque va a ser la dirección de tu estante. Por eso tiene reglas y por
/// eso se validan acá y no en un formulario suelto: el día que haya
/// servidor, las mismas reglas tienen que correr de los dos lados.
class Usuario {
  static const largoMinimo = 3;
  static const largoMaximo = 20;

  /// Nombres que no puede tomar nadie, porque van a hacer falta.
  ///
  /// Si alguien se queda con «ayuda», el día que exista una cuenta de
  /// ayuda no se le puede pedir que la devuelva.
  static const reservados = {
    'admin',
    'administrador',
    'colibri',
    'oficial',
    'ayuda',
    'soporte',
    'staff',
    'moderacion',
    'root',
    'api',
    'yo',
    'vos',
    'nuevo',
    'null',
  };

  /// Lo deja como se va a guardar: en minúsculas y sin la arroba.
  ///
  /// La arroba se saca porque la gente la escribe o no la escribe, y sería
  /// absurdo que @lucia y lucia fueran dos personas distintas.
  static String limpiar(String crudo) {
    var t = crudo.trim().toLowerCase();
    while (t.startsWith('@')) {
      t = t.substring(1);
    }
    return t;
  }

  /// Qué está mal, en palabras, o null si está bien.
  ///
  /// Devuelve el motivo y no un `false` a secas porque «ese usuario no
  /// sirve» no le dice a nadie qué arreglar.
  static String? queEstaMal(String crudo) {
    final u = limpiar(crudo);

    if (u.isEmpty) return 'Elegí un nombre de usuario.';
    if (u.length < largoMinimo) {
      return 'Tiene que tener al menos $largoMinimo letras.';
    }
    if (u.length > largoMaximo) {
      return 'No puede pasar de $largoMaximo caracteres.';
    }
    if (!RegExp(r'^[a-z]').hasMatch(u)) {
      return 'Tiene que empezar con una letra.';
    }
    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(u)) {
      return 'Solo letras sin acento, números, puntos y guiones bajos.';
    }
    if (RegExp(r'[._]$').hasMatch(u)) {
      return 'No puede terminar en punto ni en guión bajo.';
    }
    if (RegExp(r'[._]{2}').hasMatch(u)) {
      return 'No puede llevar dos puntos ni dos guiones seguidos.';
    }
    if (reservados.contains(u)) {
      return 'Ese nombre está reservado. Probá con otro.';
    }
    return null;
  }

  static bool sirve(String crudo) => queEstaMal(crudo) == null;
}

/// Los datos de una persona, como se ven desde afuera.
class Perfil {
  final String usuario;
  final String nombre;
  final String presentacion;

  /// Desde cuándo. Se muestra en el perfil y no es un dato de sistema:
  /// «acá desde marzo» dice algo, y da gusto verlo crecer.
  final DateTime desde;

  /// La foto, ya achicada a 256 y guardada como texto.
  ///
  /// Se guarda adentro del perfil y no en un archivo aparte porque son
  /// unos veinte kilobytes: menos que una tapa de libro. Un archivo
  /// suelto traería que se pueda perder, que quede huérfano al borrar el
  /// perfil, y una ruta más que puede estar mal.
  ///
  /// Null cuando no pusiste ninguna, y ahí se dibuja la inicial.
  final String? foto;

  const Perfil({
    required this.usuario,
    required this.nombre,
    this.presentacion = '',
    required this.desde,
    this.foto,
  });

  /// El nombre que se muestra cuando no pusiste ninguno.
  String get comoSeLlama => nombre.trim().isEmpty ? '@$usuario' : nombre;

  /// La letra del avatar dibujado.
  String get inicial =>
      (nombre.trim().isEmpty ? usuario : nombre.trim())[0].toUpperCase();

  /// Un número estable entre 0 y 1, sacado del @usuario.
  ///
  /// Sirve para darle un color propio al avatar sin guardar ninguna
  /// imagen. Estable a propósito: si cambiara en cada arranque, tu cara en
  /// la app sería otra cada vez que abrís.
  double get tono {
    var suma = 0;
    for (final c in usuario.codeUnits) {
      suma = (suma * 31 + c) % 100000;
    }
    return suma / 100000;
  }

  /// [sacarFoto] existe porque `foto: null` no se puede distinguir de «no
  /// me lo pasaste»: sin esto, no habría forma de borrar la foto.
  Perfil copiarCon({
    String? usuario,
    String? nombre,
    String? presentacion,
    String? foto,
    bool sacarFoto = false,
  }) => Perfil(
    usuario: usuario ?? this.usuario,
    nombre: nombre ?? this.nombre,
    presentacion: presentacion ?? this.presentacion,
    desde: desde,
    foto: sacarFoto ? null : (foto ?? this.foto),
  );

  Map<String, dynamic> aJson() => {
    'usuario': usuario,
    'nombre': nombre,
    'presentacion': presentacion,
    'desde': desde.toIso8601String(),
    'foto': foto,
  };

  factory Perfil.desdeJson(Map<String, dynamic> j) => Perfil(
    usuario: (j['usuario'] as String?) ?? '',
    nombre: (j['nombre'] as String?) ?? '',
    presentacion: (j['presentacion'] as String?) ?? '',
    desde:
        DateTime.tryParse((j['desde'] as String?) ?? '') ??
        DateTime(2026, 1, 1),
    foto: j['foto'] as String?,
  );
}

/// Qué salió de intentar algo con la cuenta.
class Resultado {
  final bool bien;
  final String? problema;

  /// La cuenta se creó, pero hay que confirmar el correo antes de entrar.
  ///
  /// Es un tercer estado y no un error: nada falló. Sin distinguirlo, la
  /// app tendría que elegir entre mentir —«listo»— o asustar —«falló»— y
  /// ninguna de las dos es lo que pasó.
  final bool faltaConfirmar;

  const Resultado.bien() : bien = true, problema = null, faltaConfirmar = false;
  const Resultado.mal(this.problema) : bien = false, faltaConfirmar = false;
  const Resultado.confirmaTuCorreo()
    : bien = true,
      problema = null,
      faltaConfirmar = true;
}

/// Lo que un servidor de cuentas tiene que saber hacer.
///
/// Existe antes de que exista el servidor, y a propósito: escribir las
/// pantallas contra esta frontera es lo que hace que el día que aparezca
/// —Supabase o lo que sea— no haya que tocar ninguna pantalla, solo
/// escribir otra implementación de estos cinco métodos.
abstract class ServidorDeCuentas {
  /// Si es falso, la app funciona igual pero todo queda en el teléfono.
  bool get disponible;

  Future<Resultado> crear({
    required Perfil perfil,
    String? correo,
    String? clave,
  });

  Future<Resultado> entrar({required String correo, required String clave});

  Future<void> salir();

  /// El perfil que hay del otro lado, si hay cuenta abierta.
  ///
  /// Sirve para cuando alguien entra desde un teléfono nuevo: la cuenta
  /// existe, el perfil está en el servidor, y este teléfono no sabe nada.
  Future<Perfil?> miPerfil();

  /// Si ese @usuario está libre. Sin servidor no hay forma de saberlo:
  /// contesta que sí y lo aclara, porque prometer lo que no se puede
  /// cumplir es peor que avisar.
  Future<bool> usuarioLibre(String usuario);

  Future<Resultado> guardarPerfil(Perfil perfil);
}

/// La implementación de hoy: no hay servidor, y se dice.
class SinServidor implements ServidorDeCuentas {
  const SinServidor();

  @override
  bool get disponible => false;

  @override
  Future<Resultado> crear({
    required Perfil perfil,
    String? correo,
    String? clave,
  }) async => const Resultado.bien();

  @override
  Future<Perfil?> miPerfil() async => null;

  @override
  Future<Resultado> entrar({
    required String correo,
    required String clave,
  }) async => const Resultado.mal(
    'Todavía no hay dónde entrar: las cuentas viven en un servidor y '
    'Colibrí todavía no tiene uno. Tu perfil está en este teléfono.',
  );

  @override
  Future<void> salir() async {}

  @override
  Future<bool> usuarioLibre(String usuario) async => true;

  @override
  Future<Resultado> guardarPerfil(Perfil perfil) async =>
      const Resultado.bien();
}

/// Tu perfil, guardado.
class Cuenta extends ChangeNotifier {
  static const _clave = 'colibri.perfil.v1';

  /// No es `final`: la app arranca sin servidor y le enchufa el de verdad
  /// si hay claves. Así el resto del código nunca se entera de cuál es.
  ServidorDeCuentas servidor;

  Cuenta({this.servidor = const SinServidor()});

  Perfil? _perfil;
  Perfil? get perfil => _perfil;

  bool get hayPerfil => _perfil != null;

  /// Si tu biblioteca sobreviviría a perder el teléfono.
  bool get estaARescate => servidor.disponible && hayPerfil;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null) return;
    try {
      _perfil = Perfil.desdeJson(jsonDecode(crudo) as Map<String, dynamic>);
    } catch (_) {
      // Formato roto: se arranca sin perfil, que es un estado válido.
    }
    notifyListeners();
  }

  /// Crear el perfil por primera vez.
  ///
  /// [hoy] existe para que las pruebas no dependan del día en que corran.
  Future<Resultado> crear({
    required String usuario,
    required String nombre,
    String presentacion = '',
    String? foto,
    String? correo,
    String? clave,
    DateTime? hoy,
  }) async {
    final limpio = Usuario.limpiar(usuario);
    final problema = Usuario.queEstaMal(limpio);
    if (problema != null) return Resultado.mal(problema);

    if (!await servidor.usuarioLibre(limpio)) {
      return const Resultado.mal('Ese nombre ya lo tiene otra persona.');
    }

    final perfil = Perfil(
      usuario: limpio,
      nombre: nombre.trim(),
      presentacion: presentacion.trim(),
      desde: hoy ?? DateTime.now(),
      foto: foto,
    );

    final r = await servidor.crear(
      perfil: perfil,
      correo: correo,
      clave: clave,
    );
    if (!r.bien) return r;

    // Se guarda igual aunque falte confirmar el correo: el perfil ya es
    // tuyo y la app tiene que servir mientras tanto. Cuando confirmes y
    // entres, se sube.
    await _guardar(perfil);
    return r;
  }

  Future<Resultado> editar({
    String? nombre,
    String? presentacion,
    String? usuario,
    String? foto,
    bool sacarFoto = false,
  }) async {
    final actual = _perfil;
    if (actual == null) {
      return const Resultado.mal('Todavía no tenés perfil.');
    }

    var nuevo = actual.copiarCon(
      nombre: nombre?.trim(),
      presentacion: presentacion?.trim(),
      foto: foto,
      sacarFoto: sacarFoto,
    );

    if (usuario != null) {
      final limpio = Usuario.limpiar(usuario);
      if (limpio != actual.usuario) {
        final problema = Usuario.queEstaMal(limpio);
        if (problema != null) return Resultado.mal(problema);
        if (!await servidor.usuarioLibre(limpio)) {
          return const Resultado.mal('Ese nombre ya lo tiene otra persona.');
        }
        nuevo = nuevo.copiarCon(usuario: limpio);
      }
    }

    final r = await servidor.guardarPerfil(nuevo);
    if (!r.bien) return r;

    await _guardar(nuevo);
    return const Resultado.bien();
  }

  Future<Resultado> entrar({required String correo, required String clave}) =>
      servidor.entrar(correo: correo, clave: clave);

  /// Borra el perfil de este teléfono.
  ///
  /// **No toca la biblioteca**, y eso es a propósito: los libros que
  /// leíste son tuyos y no de la cuenta. Sin servidor, borrar el perfil y
  /// borrar los libros sería lo mismo, y no lo es.
  Future<void> salir() async {
    await servidor.salir();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave);
    _perfil = null;
    notifyListeners();
  }

  Future<void> _guardar(Perfil perfil) async {
    _perfil = perfil;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(perfil.aJson()));
    notifyListeners();
  }
}

/// Una sola para toda la app, como la biblioteca.
final cuenta = Cuenta();
