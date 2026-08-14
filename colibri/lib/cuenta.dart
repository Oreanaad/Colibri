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

import 'insignias.dart';

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

  /// Los libros que te representan: hasta [maximoDeLibros] claves de tu
  /// biblioteca.
  ///
  /// # Por qué se eligen de tu biblioteca y no se escriben
  ///
  /// Porque así se ven las tapas. En un perfil de lectora, tres tapas
  /// dicen más que tres renglones de presentación, y se reconocen de
  /// lejos: alguien que entra a tu estante y ve esas tapas ya sabe algo
  /// de vos antes de leer una palabra.
  ///
  /// Y de paso: escribiéndolos, el mismo libro sería cien títulos
  /// distintos y no se podría juntar a quienes eligieron el mismo. Con la
  /// clave, sí. Ahí está la mitad de la comunidad que todavía no existe.
  ///
  /// Se guardan las claves y no los libros porque los libros ya están
  /// guardados: duplicarlos sería tener dos verdades que se pueden
  /// separar.
  final List<String> libros;

  /// A qué casa, facción o cabaña perteneces. Ver [Insignia].
  ///
  /// Una por saga, y la lista puede estar vacía: no todo el mundo quiere
  /// declarar de qué lado está.
  final List<String> insignias;

  /// No es `const` porque el tope de libros se calcula acá, y una cuenta
  /// no se puede hacer en tiempo de compilación. Vale la pena: el tope en
  /// el constructor es el único lugar donde no se puede esquivar.
  Perfil({
    required this.usuario,
    required this.nombre,
    this.presentacion = '',
    required this.desde,
    this.foto,
    List<String>? libros,
    List<String>? insignias,
  }) : // El tope se recorta acá, en el constructor, y no al copiar.
       //
       // Estaba en `copiarCon` y no alcanzaba: crear un perfil arma uno
       // nuevo directamente y se salteaba el tope. Lo encontró una prueba
       // que le pasó cinco libros y recibió cinco. En el constructor no
       // hay forma de esquivarlo, porque no hay otra manera de armar un
       // perfil.
       libros = (libros ?? const []).take(maximoDeLibros).toList(),
       insignias = insignias ?? const [];

  /// Tres y no uno: casi nadie tiene *un* libro, tiene dos que compiten y
  /// uno que no puede explicar. Y tres tapas juntas se leen como una
  /// frase; una sola se lee como una consigna.
  ///
  /// Tres y no cinco: a partir de ahí deja de ser una elección y pasa a
  /// ser una lista, y una lista no dice nada de nadie.
  static const maximoDeLibros = 3;

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
    List<String>? libros,
    List<String>? insignias,
  }) => Perfil(
    usuario: usuario ?? this.usuario,
    nombre: nombre ?? this.nombre,
    presentacion: presentacion ?? this.presentacion,
    desde: desde,
    foto: sacarFoto ? null : (foto ?? this.foto),
    libros: libros ?? this.libros,
    insignias: insignias ?? this.insignias,
  );

  Map<String, dynamic> aJson() => {
    'usuario': usuario,
    'nombre': nombre,
    'presentacion': presentacion,
    'desde': desde.toIso8601String(),
    'foto': foto,
    'libros': libros,
    'insignias': insignias,
  };

  factory Perfil.desdeJson(Map<String, dynamic> j) => Perfil(
    usuario: (j['usuario'] as String?) ?? '',
    nombre: (j['nombre'] as String?) ?? '',
    presentacion: (j['presentacion'] as String?) ?? '',
    desde:
        DateTime.tryParse((j['desde'] as String?) ?? '') ??
        DateTime(2026, 1, 1),
    foto: j['foto'] as String?,
    libros: (j['libros'] as List?)?.cast<String>() ?? const [],
    insignias: (j['insignias'] as List?)?.cast<String>() ?? const [],
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
    List<String>? libros,
    List<String>? insignias,
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
      libros: libros,
      insignias: insignias,
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
    List<String>? libros,
    List<String>? insignias,
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
      libros: libros,
      insignias: insignias,
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

  /// Entrar a una cuenta que ya existe, y dejar el perfil en su lugar.
  ///
  /// # Por qué esto no puede ser solo «iniciar sesión»
  ///
  /// Antes lo era, y pasaba esto: al entrar, la app arranca a subir la
  /// biblioteca. Cada libro crea una fila en `obras` y otra en `ediciones`,
  /// y `ediciones` tiene una clave ajena que `obras` no tiene:
  ///
  ///     cargada_por uuid references perfiles(id)
  ///
  /// Si todavía no hay una fila tuya en `perfiles`, la obra entra y **la
  /// edición rebota**. Sin edición no hay lectura, y sin lectura tu libro
  /// no existe del otro lado. Se vio en los datos de verdad: catorce obras
  /// creadas en nueve segundos, cero ediciones, y catorce obras huérfanas
  /// que quedaron ahí.
  ///
  /// Y no se notaba, porque [Nube.subirLibro] se traga los errores a
  /// propósito —para que quedarse sin señal no te rompa la app— así que el
  /// fallo era silencioso de punta a punta.
  ///
  /// Ahora, apenas hay sesión, se resuelve el perfil **antes** de que
  /// alguien pueda subir nada:
  ///
  /// - Si hay uno del otro lado, se adopta: es el caso de entrar desde un
  ///   teléfono nuevo, donde este aparato no sabe nada de vos.
  /// - Si no lo hay pero sí hay uno local, se sube. Es el caso de haber
  ///   armado el perfil sin cuenta y registrarse después.
  ///
  /// En los dos casos, cuando esto termina la fila existe.
  Future<Resultado> entrar({
    required String correo,
    required String clave,
  }) async {
    final r = await servidor.entrar(correo: correo, clave: clave);
    if (!r.bien) return r;

    await asegurarElPerfil();
    return r;
  }

  /// Deja tu fila de `perfiles` existiendo, venga de donde venga.
  ///
  /// Aparte de [entrar] y pública porque hace falta en más de un momento:
  /// también al volver a abrir la app con una sesión que quedó guardada,
  /// donde nadie llama a `entrar` y sin embargo se va a subir.
  Future<void> asegurarElPerfil() async {
    if (!servidor.disponible) return;

    final delServidor = await servidor.miPerfil();
    final local = _perfil;

    // No hay nada del otro lado. Si hay uno acá, se sube: es de alguien
    // que armó su perfil sin cuenta y se registró después.
    if (delServidor == null) {
      if (local != null) await servidor.guardarPerfil(local);
      return;
    }

    // Hay perfil arriba. **Se junta con el de acá, no se reemplaza.**
    //
    // # El bug que esto arregla, y que era una pérdida de datos
    //
    // Antes se adoptaba el de arriba entero. Suena razonable hasta que se
    // mira un caso de verdad: una cuenta creada cuando la tabla todavía no
    // guardaba la foto, los tres libros ni las insignias. Ese perfil existe
    // del otro lado y tiene esos tres campos vacíos.
    //
    // Adoptarlo **le borraba a la lectora sus tres libros y sus insignias
    // del teléfono**, que eran el único lugar donde estaban. Y como del
    // otro lado ya había una fila, tampoco se subían nunca: quedaban
    // borrados de los dos lados.
    //
    // # La regla
    //
    // La identidad la manda el servidor —el @usuario y el nombre son los
    // que elegiste, no los que tenga este aparato—. Lo demás se queda con
    // lo que exista: si arriba hay, gana arriba; si arriba está vacío y acá
    // hay algo, se conserva **y se sube**.
    //
    // Vacío no es lo mismo que «lo borré»: borrar los tres libros a
    // propósito pasa por editar el perfil, que sí sube la lista vacía.
    final juntos = delServidor.copiarCon(
      foto: delServidor.foto ?? local?.foto,
      libros: delServidor.libros.isNotEmpty
          ? delServidor.libros
          : (local?.libros ?? const []),
      insignias: delServidor.insignias.isNotEmpty
          ? delServidor.insignias
          : (local?.insignias ?? const []),
    );

    await _guardar(juntos);

    // Y si de acá salió algo que arriba no estaba, se manda. Sin esto, lo
    // que tenías en el teléfono se quedaría en el teléfono para siempre:
    // ninguna otra parte de la app vuelve a subir el perfil sola.
    final faltaArriba =
        (delServidor.foto == null && juntos.foto != null) ||
        (delServidor.libros.isEmpty && juntos.libros.isNotEmpty) ||
        (delServidor.insignias.isEmpty && juntos.insignias.isNotEmpty);

    if (faltaArriba) await servidor.guardarPerfil(juntos);
  }

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
