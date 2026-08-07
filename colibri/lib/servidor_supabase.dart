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
      final r = await _base.auth.signUp(
        email: correo,
        password: clave,
        // Sin esto, el enlace del correo apunta a lo que tenga
        // configurado el proyecto, que de fábrica es localhost.
        emailRedirectTo: urlDeLaApp.isEmpty ? null : urlDeLaApp,
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
  Future<Resultado> entrar({
    required String correo,
    required String clave,
  }) async {
    try {
      await _base.auth.signInWithPassword(email: correo, password: clave);
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
