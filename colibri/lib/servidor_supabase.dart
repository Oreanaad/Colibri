import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cuenta.dart';

/// La cuenta, contra Supabase.
///
/// # Qué es esto y qué no
///
/// Es la otra implementación de [ServidorDeCuentas]. Todo lo que la app
/// sabe de cuentas pasa por esa frontera, así que **este archivo es lo
/// único que cambió** para que las cuentas sean de verdad: ni una pantalla
/// se tocó.
///
/// # Dónde viven las claves
///
/// Igual que la de Google Books: entran al compilar, desde `claves.json`,
/// que está en el `.gitignore`. Sin ellas la app arranca igual, sin
/// servidor, y todo queda en el teléfono.
///
///     flutter run -d chrome --dart-define-from-file=claves.json
///
/// La clave pública **es pública a propósito**: viaja adentro de la app,
/// así que la tiene cualquiera que la instale. Lo que protege los datos
/// son las reglas de la base, que están escritas en `servidor/esquema.sql`
/// y probadas en `servidor/pruebas.sql`.

const urlSupabase = String.fromEnvironment('SUPABASE_URL');
const clavePublicaSupabase = String.fromEnvironment('SUPABASE_CLAVE');

/// A dónde vuelve alguien después de tocar el enlace del correo.
///
/// # Por qué hace falta decirlo
///
/// Supabase manda ese correo con una dirección de vuelta, y si no se le
/// pide una, usa la que tenga configurada el proyecto. Recién creado, esa
/// es `http://localhost:3000`: el correo llegaba con un enlace a la
/// computadora de quien lo abre, que no tiene nada corriendo ahí. Nadie
/// podía confirmar su cuenta.
///
/// Se pasa explícito en cada registro y no se confía en la configuración
/// del proyecto, por dos razones: el valor queda a la vista en el código
/// en vez de escondido en un panel, y así la app de pruebas y la
/// publicada pueden volver cada una a su propia dirección.
///
/// **Ojo**: Supabase solo acepta direcciones que estén en su lista de
/// permitidas. Poner esto sin agregarla allá no alcanza.
const urlDeLaApp = String.fromEnvironment('APP_URL');

/// El esquema con el que el teléfono sabe volver a Colibrí.
///
/// En la web, la dirección de vuelta es una dirección web y alcanza. En un
/// teléfono no: un enlace `https://` lo abre el navegador, y lo que pasa
/// es que la lectora toca el enlace del correo, se le abre Safari, y ahí
/// queda —confirmada, sí, pero en el navegador, mientras la app sigue
/// esperando en la pantalla de antes—.
///
/// `ar.colibri.colibri://` es un esquema propio: no lo entiende internet,
/// lo entiende el sistema operativo, que lo traduce a "abrí Colibrí". Está
/// declarado en `ios/Runner/Info.plist` y en el `AndroidManifest.xml`, y
/// tiene que estar además en la lista de Supabase. Si el esquema cambia,
/// son cuatro lugares: eso lo cuida `test/vuelta_test.dart`.
const esquemaPropio = 'ar.colibri.colibri';

/// A dónde se le pide a Supabase que vuelva, según dónde corra la app.
///
/// Devuelve vacío solo si no hay a dónde volver, y en ese caso no se le
/// pasa nada a Supabase y manda a lo que tenga configurado el proyecto.
String vueltaDelCorreo({required bool enLaWeb}) {
  if (!enLaWeb) return '$esquemaPropio://login-callback/';
  return urlDeLaApp;
}

bool get haySupabase =>
    urlSupabase.isNotEmpty && clavePublicaSupabase.isNotEmpty;

/// Se llama antes que nada en `main`. Si no hay claves, no hace nada.
Future<void> prepararSupabase() async {
  if (!haySupabase) return;
  // `publishableKey` y no `anonKey`: Supabase cambió el formato de las
  // claves públicas —ahora empiezan con `sb_publishable_`— y el parámetro
  // viejo quedó deprecado.
  await Supabase.initialize(
    url: urlSupabase,
    publishableKey: clavePublicaSupabase,
  );
}

class ServidorSupabase implements ServidorDeCuentas {
  const ServidorSupabase();

  SupabaseClient get _base => Supabase.instance.client;

  @override
  bool get disponible => true;

  @override
  Future<Resultado> crear({
    required Perfil perfil,
    String? correo,
    String? clave,
  }) async {
    if (correo == null || clave == null) {
      return const Resultado.mal('Hace falta un correo y una contraseña.');
    }

    try {
      // Sin esto, el enlace del correo apunta a lo que tenga configurado
      // el proyecto, que de fábrica es localhost. Y en el teléfono, una
      // dirección web abre el navegador en vez de la app: ver
      // [vueltaDelCorreo].
      final vuelta = vueltaDelCorreo(enLaWeb: kIsWeb);
      final r = await _base.auth.signUp(
        email: correo,
        password: clave,
        emailRedirectTo: vuelta.isEmpty ? null : vuelta,
      );

      // Sin sesión quiere decir que Supabase mandó un correo para
      // confirmar. No es un error: la cuenta existe, falta el paso de
      // demostrar que ese correo es tuyo. El perfil se sube al entrar.
      if (r.session == null) return const Resultado.confirmaTuCorreo();

      return await guardarPerfil(perfil);
    } on AuthException catch (e) {
      return Resultado.mal(mensajeDeAuth(e));
    } catch (_) {
      return const Resultado.mal(
        'No se pudo conectar. Fijate la conexión y probá de nuevo.',
      );
    }
  }

  @override
  /// Entrar con el correo **o** con el @usuario.
  ///
  /// # Cómo sabe cuál le escribieron
  ///
  /// Por la arroba. Un correo siempre tiene una; un @usuario nunca puede
  /// tenerla, porque el formato que admite la base es `[a-z0-9._]` y nada
  /// más. No hay forma de confundirlos, así que no hace falta un selector
  /// ni dos campos: se escribe lo que una se acuerde.
  ///
  /// # Por qué el usuario necesita una vuelta más
  ///
  /// Supabase autentica por correo. «@usuario» es una idea nuestra, que
  /// vive en `perfiles`, y traducirla al correo tiene que pasar **antes**
  /// de iniciar sesión: sin sesión, y contra `auth.users`, que la app no
  /// puede leer nunca. Eso lo hace una función del servidor,
  /// `correo_de_usuario`, que está en `servidor/entrar_con_usuario.sql`
  /// con la explicación de lo que expone.
  ///
  /// Si esa función no está instalada, esto no se rompe: avisa que por
  /// ahora hace falta el correo.
  Future<Resultado> entrar({
    required String correo,
    required String clave,
  }) async {
    final escrito = correo.trim();

    final String email;
    if (escrito.contains('@')) {
      email = escrito;
    } else {
      final encontrado = await _correoDe(escrito);
      if (encontrado == null) {
        // El mismo mensaje que una contraseña incorrecta, a propósito: si
        // dijera «ese usuario no existe», cualquiera podría averiguar qué
        // nombres están tomados probando de a uno.
        return const Resultado.mal('Usuario o contraseña incorrectos.');
      }
      email = encontrado;
    }

    try {
      await _base.auth.signInWithPassword(email: email, password: clave);
      return const Resultado.bien();
    } on AuthException catch (e) {
      return Resultado.mal(mensajeDeAuth(e));
    } catch (_) {
      return const Resultado.mal(
        'No se pudo conectar. Fijate la conexión y probá de nuevo.',
      );
    }
  }

  @override
  Future<void> salir() => _base.auth.signOut();

  /// Una columna de texto[] de Postgres, como lista de Dart.
  ///
  /// Devuelve una lista vacía y no null si la columna todavía no existe:
  /// así una app nueva contra una base a la que no le corrieron
  /// `perfil_completo.sql` muestra un perfil sin libros, en vez de romper.
  static List<String> _lista(Object? columna) => [
    if (columna is List)
      for (final x in columna)
        if (x is String) x,
  ];

  /// El correo de un @usuario, preguntándole al servidor.
  ///
  /// Devuelve null si no existe, si la función no está instalada, o si no
  /// hay internet. Los tres casos terminan en el mismo mensaje para quien
  /// mira, y eso es a propósito: distinguirlos serviría sobre todo para
  /// averiguar qué nombres existen.
  Future<String?> _correoDe(String usuario) async {
    if (usuario.isEmpty) return null;
    try {
      final r = await _base.rpc(
        'correo_de_usuario',
        params: {'nombre': usuario},
      );
      final correo = r as String?;
      return (correo == null || correo.isEmpty) ? null : correo;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Perfil?> miPerfil() async {
    final yo = _base.auth.currentUser;
    if (yo == null) return null;

    try {
      final fila = await _base
          .from('perfiles')
          .select()
          .eq('id', yo.id)
          .maybeSingle();
      if (fila == null) return null;

      return Perfil(
        usuario: fila['usuario'] as String,
        nombre: (fila['nombre'] as String?) ?? '',
        presentacion: (fila['presentacion'] as String?) ?? '',
        desde:
            DateTime.tryParse((fila['desde'] as String?) ?? '') ??
            DateTime.now(),
        foto: fila['foto'] as String?,
        libros: _lista(fila['libros']),
        insignias: _lista(fila['insignias']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Si ese @usuario ya lo tiene alguien.
  ///
  /// Contesta que está libre cuando no se puede saber —sin conexión, o
  /// sin cuenta abierta, porque la tabla de perfiles no se lee sin
  /// cuenta—. No es un agujero: quien decide de verdad es la base, que
  /// tiene el nombre marcado como único y rechaza el segundo.
  @override
  Future<bool> usuarioLibre(String usuario) async {
    try {
      final fila = await _base
          .from('perfiles')
          .select('usuario')
          .eq('usuario', usuario)
          .maybeSingle();
      return fila == null;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<Resultado> guardarPerfil(Perfil perfil) async {
    final yo = _base.auth.currentUser;
    if (yo == null) {
      return const Resultado.mal('Entrá a tu cuenta primero.');
    }

    try {
      await _base.from('perfiles').upsert({
        'id': yo.id,
        'usuario': perfil.usuario,
        'nombre': perfil.nombre,
        'presentacion': perfil.presentacion,
        // La foto, los libros y las insignias también.
        //
        // Antes no viajaban, y el resultado era que entrar desde otro
        // aparato traía el nombre y nada más: ni la cara, ni los tres
        // libros que elegiste, ni las insignias. Justo lo contrario de
        // para qué sirve tener cuenta.
        //
        // La foto va como texto en base64 y no en un depósito de
        // archivos aparte: son unos 39 KB en el peor caso medido, y una
        // tabla en vez de dos. La razón entera está en
        // `servidor/perfil_completo.sql`.
        'foto': perfil.foto,
        'libros': perfil.libros,
        'insignias': perfil.insignias,
      });
      return const Resultado.bien();
    } on PostgrestException catch (e) {
      return Resultado.mal(mensajeDeLaBase(e));
    } catch (_) {
      return const Resultado.mal('No se pudo guardar. Probá de nuevo.');
    }
  }

  /// Lo que dice Supabase, en palabras.
  ///
  /// Es pública para poder probarla: es un montón de casos escritos a
  /// mano contra códigos que decide otra empresa, o sea justo el tipo de
  /// cosa que se rompe en silencio cuando cambian uno.
  ///
  /// Sus mensajes vienen en inglés y escritos para quien programa:
  /// «Invalid login credentials» no le dice a nadie que se equivocó de
  /// contraseña. Se traducen los que la gente se va a encontrar de
  /// verdad; para el resto queda el mensaje original, que es mejor que un
  /// «algo salió mal» que no deja ni buscarlo.
  static String mensajeDeAuth(AuthException e) => switch (e.code) {
    'invalid_credentials' => 'Ese correo y esa contraseña no coinciden.',
    'email_not_confirmed' =>
      'Todavía no confirmaste el correo. Fijate en tu bandeja, y también '
          'en el correo no deseado.',
    'user_already_exists' ||
    'email_exists' => 'Ya hay una cuenta con ese correo. Probá entrando.',
    'weak_password' =>
      'Esa contraseña es muy corta. Tienen que ser al menos seis '
          'caracteres.',
    'over_email_send_rate_limit' =>
      'Se mandaron muchos correos seguidos. Esperá un minuto.',
    'validation_failed' => 'Fijate que el correo esté bien escrito.',
    _ => e.message,
  };

  /// Lo mismo, para los errores de la base.
  static String mensajeDeLaBase(PostgrestException e) {
    // 23505 es «ya existe uno igual». En perfiles solo puede ser el
    // @usuario, que es el único marcado como único.
    if (e.code == '23505') return 'Ese @usuario ya lo tiene otra persona.';
    // 23514 es «una regla de la base dijo que no».
    if (e.code == '23514') return 'Ese @usuario no cumple las reglas.';
    if (e.code == '42501') {
      return 'No tenés permiso para eso. Probá cerrando y volviendo a '
          'entrar.';
    }
    return e.message;
  }
}
