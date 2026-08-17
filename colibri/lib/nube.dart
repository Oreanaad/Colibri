import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart';
import 'fanfic.dart';
import 'modelos.dart';

/// Tu biblioteca, de ida y de vuelta con Supabase.
///
/// # Las dos direcciones
///
/// Sube sola, libro por libro, a medida que cambian ([conectar]). Y baja
/// cuando entrás, o cuando lo pedís desde tu perfil ([bajarTodo]). Durante
/// un tiempo solo subía, y eso hacía que la nube fuera un pozo: entrar en
/// un teléfono nuevo te traía el perfil y una biblioteca vacía.
///
/// # Por qué Biblioteca no sabe que esto existe
///
/// [Biblioteca] tiene dos enganches, `alGuardarUnLibro` y
/// `alQuitarUnLibro`, que por defecto no hacen nada. Acá se registran.
/// Así la biblioteca sigue siendo lo que siempre fue —local, probable sin
/// cuenta ni internet— y quien quiere sincronizar se cuelga de afuera.
///
/// # Por qué el catálogo solo se inserta y nunca se corrige
///
/// La base lo dice en sus propias reglas: nadie edita ni borra `obras`,
/// `ediciones` ni `fanfics` desde la app. Corregir una ficha ajena es
/// moderación, y la moderación no puede ser un botón que tiene todo el
/// mundo. Por eso acá nunca hay un `update` a esas tres tablas: se busca
/// primero, y si no existe, se inserta. Si dos personas cargan el mismo
/// libro a la vez, gana quien llegó primero y la otra reutiliza esa fila.
///
/// # La libreta de direcciones
///
/// Una edición sin ISBN no tiene ninguna clave natural para encontrarla
/// de nuevo. Sin algo que la recuerde, cada vez que tocaras una estrella
/// de un libro cargado a mano se crearía **una edición nueva**. Por eso
/// se guarda, en este teléfono, qué fila de la nube le corresponde a cada
/// libro.
///
/// Perder esa libreta —reinstalar la app, borrar el almacenamiento— dejaba
/// un fantasma en el catálogo al primer cambio. Ahora [bajarTodo] la
/// reconstruye, porque cada lectura viene con el id de su edición: era una
/// limitación conocida y dejó de serlo cuando se pudo bajar.
class Nube {
  static const _clave = 'colibri.nube.v1';

  SupabaseClient get _base => Supabase.instance.client;

  /// Quién está en sesión, o `null` si no hay a quién preguntarle.
  ///
  /// # Por qué no alcanza con `_base.auth.currentUser`
  ///
  /// Porque `Supabase.instance` **tira** si la app arrancó sin claves, y
  /// ese acceso estaba afuera del `try` de cada método: en vez de no
  /// hacer nada, se caía. En la app no se notaba porque `main` solo
  /// engancha la nube cuando hay claves, así que el camino era
  /// inalcanzable; pero era una trampa esperando a que alguien llamara a
  /// estos métodos desde otro lado, y hacía que la clase no se pudiera
  /// probar sin un servidor de verdad.
  ///
  /// Sin servidor y sin sesión son el mismo caso desde acá: no hay dónde
  /// guardar nada, y la biblioteca sigue viviendo en el teléfono.
  String? get _quienSoy {
    try {
      return _base.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Cuelga esta nube de una biblioteca. A partir de acá, cada cambio
  /// intenta subirse solo.
  void conectar(Biblioteca biblioteca) {
    biblioteca.alGuardarUnLibro = subirLibro;
    biblioteca.alQuitarUnLibro = borrarLibro;
  }

  /// Sube toda la biblioteca de una vez.
  ///
  /// Se llama una sola vez, justo después de crear la cuenta o de entrar
  /// a una que ya existía: es la diferencia entre que tu biblioteca suba
  /// al toque y que quede esperando a que edites un libro para que se
  /// entere de que existe.
  ///
  /// De a uno y no todos a la vez, a propósito: mandar doscientos libros
  /// en paralelo satura la conexión y hace que empiecen a fallar por
  /// timeout, que es peor que tardar un poco más.
  Future<void> subirTodo(Biblioteca biblioteca) async {
    for (final libro in biblioteca.todos) {
      await subirLibro(libro);
    }
  }

  /// Poner las dos puntas de acuerdo: bajar lo que falta acá y subir lo
  /// que falta allá.
  ///
  /// # El orden importa, y el segundo paso mira una lista de antes
  ///
  /// Se baja primero. Si se subiera primero, en un teléfono recién
  /// reinstalado no habría nada que subir y después la bajada traería todo
  /// igual, así que da lo mismo; pero al revés no: bajar primero deja la
  /// biblioteca completa antes de decidir qué mandar.
  ///
  /// Y se manda **solo lo que ya estaba en el teléfono**, no todo. Un
  /// libro que acaba de bajar ya está en la nube por definición: subirlo
  /// de nuevo son seis pedidos para dejar todo exactamente como estaba.
  /// Con doscientos libros, más de mil pedidos desde un teléfono para
  /// nada. Por eso se anotan las claves antes de bajar.
  ///
  /// # Por qué devuelve también cuántos fallaron
  ///
  /// Porque [subirLibro] se traga los errores —para que quedarse sin señal
  /// no te rompa la app— y eso hizo que un fallo real pasara sin que nadie
  /// se enterara: al entrar en la web, catorce libros crearon su obra y
  /// rebotaron al crear la edición, y la única señal fue una biblioteca
  /// vacía del otro lado. Tragarse el error está bien; no contarlo, no.
  Future<({int bajados, int subidos, int fallaron})> sincronizar(
    Biblioteca biblioteca,
  ) async {
    final yaEstaban = {for (final l in biblioteca.todos) l.clave};

    final bajados = await bajarTodo(biblioteca);

    var subidos = 0;
    var fallaron = 0;
    for (final libro in biblioteca.todos) {
      if (!yaEstaban.contains(libro.clave)) continue;
      if (await subirLibro(libro)) {
        subidos++;
      } else {
        fallaron++;
      }
    }

    return (bajados: bajados, subidos: subidos, fallaron: fallaron);
  }

  /// Sube un libro. Devuelve si de verdad llegó.
  ///
  /// Devuelve algo aunque el enganche de [Biblioteca] no lo mire: quien
  /// sincroniza necesita saber cuántos llegaron para poder decirlo, y
  /// contar las llamadas en vez de los resultados sería contar mal. Esta
  /// función se traga los errores a propósito —abajo se explica por qué—
  /// así que desde afuera no habría otra forma de enterarse.
  Future<bool> subirLibro(Libro libro) async {
    final yo = _quienSoy;
    if (yo == null) return false;

    try {
      final registro = await _leerRegistro(libro.clave);

      final String? edicionId;
      final String? fanficId;

      if (libro.origen == Origen.fanfic) {
        fanficId = await _idDeFanfic(libro);
        edicionId = null;
      } else {
        final obraId = await _idDeObra(libro, cargadaPor: yo);
        edicionId = await _idDeEdicion(
          libro,
          obraId: obraId,
          cargadaPor: yo,
          cacheado: registro?.edicionId,
        );
        fanficId = null;
      }

      final lectura = await _base
          .from('lecturas')
          .upsert(
            filaDeLectura(
              libro,
              perfilId: yo,
              edicionId: edicionId,
              fanficId: fanficId,
            ),
            onConflict: edicionId != null
                ? 'perfil_id,edicion_id'
                : 'perfil_id,fanfic_id',
          )
          .select('id')
          .single();
      final lecturaId = lectura['id'] as String;

      await _guardarRegistro(
        libro.clave,
        _Registro(edicionId: edicionId, fanficId: fanficId),
      );

      await _reemplazarHijos(libro, lecturaId, perfilId: yo);
      return true;
    } catch (_) {
      // Sin internet, o el servidor no contestó: la lectura queda igual
      // en el teléfono. Se va a volver a intentar la próxima vez que se
      // toque este libro, y no hay nada que romper acá adentro: el
      // guardado local ya pasó antes de que se llame a esto.
      return false;
    }
  }

  /// Las reseñas que escribieron otras lectoras de este libro.
  ///
  /// # Por qué de la obra y no de la edición
  ///
  /// Porque una reseña es del libro, no del ejemplar. Si alguien leyó la
  /// edición de Salamandra y vos tenés la de bolsillo, su reseña te sirve
  /// igual: es la misma novela. Filtrando por edición, la ficha de tu
  /// ejemplar quedaría vacía aunque veinte personas hubieran escrito sobre
  /// el mismo libro.
  ///
  /// # Por qué por la clave y no por el id
  ///
  /// La app no sabe qué uuid tiene esta obra en la nube —eso vive en la
  /// libreta, y solo para los libros que ya subiste—. Pero **sí puede
  /// calcular su clave**: [Libro.claveDeObra] es título más apellido
  /// normalizados, y es exactamente lo que la tabla `obras` guarda en su
  /// columna `clave`, que además es única.
  ///
  /// Eso hace que esto ande incluso para un libro que vos nunca subiste:
  /// abrís algo que encontraste buscando y ves lo que escribió otra
  /// persona, sin haberlo agregado a tu biblioteca.
  ///
  /// # Lo que hace la base y no hace este código
  ///
  /// No hay ningún filtro acá de «solo los perfiles públicos». La regla de
  /// `lecturas` en `servidor/esquema.sql` ya lo hace: una lectura se ve si
  /// es tuya, o si hay sesión y el perfil es público. Escribirlo también
  /// acá sería tener la misma decisión en dos lugares, y el día que
  /// cambien uno solo, el que manda es el de la base.
  ///
  /// Devuelve vacío sin sesión: es lo que contesta el servidor, y está bien
  /// que la comunidad sea de quien está adentro.
  Future<List<ResenaAjena>> resenasDe(Libro libro) async {
    if (_quienSoy == null) return const [];

    try {
      final List<dynamic> filas;

      if (libro.origen == Origen.fanfic) {
        // Un fanfic se identifica por su dirección, no por su título: el
        // mismo fic cargado por cuatro mil personas tendría cuatro mil
        // títulos y una sola dirección. Ver [Fanfic.identidad].
        final identidad = libro.enlace == null
            ? null
            : Fanfic.identidad(libro.enlace!);
        // Sin dirección reconocible no hay con qué juntar a dos personas
        // que leyeron el mismo fic, y adivinar por título sería juntar
        // fics distintos.
        if (identidad == null) return const [];

        filas = await _base
            .from('lecturas')
            .select(resenasDeUnFanfic)
            .eq('fanfics.identidad', identidad)
            .not('resena', 'is', null);
      } else {
        filas = await _base
            .from('lecturas')
            .select(resenasDeUnLibro)
            .eq('ediciones.obras.clave', libro.claveDeObra)
            .not('resena', 'is', null);
      }

      return resenasDeFilas(filas, yo: _quienSoy);
    } catch (_) {
      return const [];
    }
  }

  /// Traer de la nube los libros que este teléfono no tiene.
  ///
  /// # Por qué esto importa más que parecía
  ///
  /// Sin esto, la nube era un pozo: todo entraba y nada salía. Entrar con
  /// tu cuenta en un teléfono nuevo te traía el perfil y una biblioteca
  /// vacía, y reinstalar la app era perder todo aunque estuviera guardado
  /// del otro lado. Con la firma gratis de Apple, que dura siete días,
  /// reinstalar no es un accidente raro: es todas las semanas.
  ///
  /// # Lo que hace con lo que ya está
  ///
  /// **No pisa nada.** Un libro que ya está en el teléfono se saltea, con
  /// lo que tenga puesto. La razón es que no se puede saber cuál de las
  /// dos versiones es la más nueva: la base guarda cuándo se actualizó la
  /// lectura, pero el teléfono no guarda nada equivalente, así que
  /// comparar sería inventar. Ante la duda gana lo que está a la vista,
  /// que es lo que la lectora acaba de escribir.
  ///
  /// Es la misma regla que [Biblioteca.agregarVarios] ya usaba para
  /// Goodreads, y por eso se usa esa y no un bucle de `agregar`.
  ///
  /// # De paso arregla la libreta
  ///
  /// La libreta —qué fila de la nube es cada libro— vivía solo en este
  /// teléfono, y el comentario de arriba de [Nube] decía que perderla
  /// dejaba un fantasma en el catálogo la próxima vez que se editara algo.
  /// Bajando se puede reconstruir, porque cada lectura viene con el id de
  /// su edición o de su fanfic. Así que reinstalar ya no deja fantasmas.
  ///
  /// Devuelve cuántos entraron.
  Future<int> bajarTodo(Biblioteca biblioteca) async {
    final yo = _quienSoy;
    if (yo == null) return 0;

    final List<dynamic> filas;
    try {
      filas = await _base
          .from('lecturas')
          .select(todoLoDeUnaLectura)
          .eq('perfil_id', yo);
    } catch (_) {
      // Sin internet o el servidor no contestó. La biblioteca local queda
      // como estaba, que es lo correcto: no bajar nada no rompe nada.
      return 0;
    }

    final libros = <Libro>[];
    final direcciones = <String, _Registro>{};

    for (final cruda in filas) {
      final fila = (cruda as Map).cast<String, dynamic>();
      final libro = libroDeFila(fila);
      if (libro == null) continue;
      libros.add(libro);
      direcciones[libro.clave] = _Registro(
        edicionId: fila['edicion_id'] as String?,
        fanficId: fila['fanfic_id'] as String?,
      );
    }

    // Los estantes tienen que existir en la lista aparte, no solo dentro
    // de los libros: sin esto un estante bajado no aparece como solapa.
    for (final libro in libros) {
      for (final estante in libro.estantes) {
        await biblioteca.crearEstante(estante); // ignora los repetidos
      }
    }

    // Sin el enganche mientras entran. Si no, cada libro que acaba de
    // bajar se sube de nuevo al instante: con doscientos libros son más
    // de mil pedidos para dejar la nube exactamente como estaba.
    final enganche = biblioteca.alGuardarUnLibro;
    biblioteca.alGuardarUnLibro = null;
    final int cuantos;
    try {
      cuantos = await biblioteca.agregarVarios(libros);
    } finally {
      biblioteca.alGuardarUnLibro = enganche;
    }

    // La libreta se guarda para todos los que bajaron, no solo para los
    // que entraron: si un libro ya estaba en el teléfono pero la libreta
    // se había perdido, esta es justo la ocasión de recuperar su
    // dirección, y es el caso que dejaba fantasmas.
    for (final entrada in direcciones.entries) {
      await _guardarRegistro(entrada.key, entrada.value);
    }

    return cuantos;
  }

  Future<void> borrarLibro(String clave) async {
    final yo = _quienSoy;
    if (yo == null) return;

    try {
      final registro = await _leerRegistro(clave);
      if (registro == null) return; // nunca subido, nada que borrar

      // Se borra la lectura, nunca la obra ni la edición ni el fanfic:
      // esos son del catálogo compartido, y sacar tu lectura no puede
      // sacarle el libro a nadie más.
      final query = _base.from('lecturas').delete().eq('perfil_id', yo);
      if (registro.edicionId != null) {
        await query.eq('edicion_id', registro.edicionId!);
      } else if (registro.fanficId != null) {
        await query.eq('fanfic_id', registro.fanficId!);
      }

      await _olvidarRegistro(clave);
    } catch (_) {
      // Igual que al subir: si no se pudo, se queda como estaba en la
      // nube. No hay forma de que esto le arruine algo al teléfono.
    }
  }

  // ---------- El catálogo: buscar primero, insertar si no está ----------

  Future<String> _idDeObra(Libro libro, {required String cargadaPor}) async {
    final existente = await _base
        .from('obras')
        .select('id')
        .eq('clave', libro.claveDeObra)
        .maybeSingle();
    if (existente != null) return existente['id'] as String;

    try {
      final creada = await _base
          .from('obras')
          .insert(filaDeObra(libro))
          .select('id')
          .single();
      return creada['id'] as String;
    } on PostgrestException catch (e) {
      // 23505: alguien cargó la misma obra entre el select y el insert.
      // No es un error, es la carrera que se esperaba: se vuelve a
      // preguntar y se usa la de esa otra persona.
      if (e.code == '23505') return _idDeObra(libro, cargadaPor: cargadaPor);
      rethrow;
    }
  }

  Future<String> _idDeEdicion(
    Libro libro, {
    required String obraId,
    required String cargadaPor,
    String? cacheado,
  }) async {
    if (libro.isbn != null) {
      final existente = await _base
          .from('ediciones')
          .select('id')
          .eq('isbn', libro.isbn!)
          .maybeSingle();
      if (existente != null) return existente['id'] as String;
    } else if (cacheado != null) {
      // Sin ISBN no hay forma de volver a encontrarla preguntando: si ya
      // la creamos una vez, se reutiliza la que quedó anotada acá, sin
      // tocarla. No se puede corregir de todos modos.
      return cacheado;
    }

    try {
      final creada = await _base
          .from('ediciones')
          .insert(filaDeEdicion(libro, obraId: obraId, cargadaPor: cargadaPor))
          .select('id')
          .single();
      return creada['id'] as String;
    } on PostgrestException catch (e) {
      if (e.code == '23505' && libro.isbn != null) {
        return _idDeEdicion(
          libro,
          obraId: obraId,
          cargadaPor: cargadaPor,
          cacheado: cacheado,
        );
      }
      rethrow;
    }
  }

  Future<String> _idDeFanfic(Libro libro) async {
    final identidad = Fanfic.identidad(libro.enlace ?? '');
    if (identidad == null) {
      throw StateError('Un fanfic sin enlace válido no se puede subir.');
    }

    final existente = await _base
        .from('fanfics')
        .select('id')
        .eq('identidad', identidad)
        .maybeSingle();
    if (existente != null) return existente['id'] as String;

    try {
      final creado = await _base
          .from('fanfics')
          .insert(filaDeFanfic(libro))
          .select('id')
          .single();
      return creado['id'] as String;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return _idDeFanfic(libro);
      rethrow;
    }
  }

  // ---------- Los hijos de una lectura ----------
  //
  // Los ánimos, los personajes, las frases y los estantes son filas aparte
  // que apuntan a la lectura. Se sincronizan borrando y volviendo a
  // insertar, que es la forma más simple de dejarlos iguales a lo que tiene
  // el teléfono, y es imposible de dejar desincronizado.
  //
  // # Salvo cuando el teléfono no sabe nada
  //
  // Y ahí estaba un bug que **borraba frases guardadas**.
  //
  // Visto en los datos: la nube tenía una frase de Fourth Wing, subida
  // desde el teléfono. En la PC ese mismo libro estaba sin frases —nunca se
  // marcó ninguna ahí— y al sincronizar desde la PC, el `delete` se llevó
  // la frase y el `insert` no puso nada. La frase que alguien había marcado
  // leyendo desapareció del servidor, sin ningún error.
  //
  // Una lista vacía no dice «las borré»: dice **«este aparato no sabe nada
  // de esto»**. Son dos cosas distintas y tratarlas igual cuesta datos.
  //
  // Así que si la lista local está vacía, no se toca lo que hay del otro
  // lado. Es la misma regla que ya usa [bajarTodo] para no pisar un libro
  // que ya está en el teléfono: ante la duda, no se destruye.
  //
  // # Lo que esto todavía no resuelve
  //
  // Borrar la última frase de un libro **no la borra de la nube**: desde
  // afuera se ve igual que «este aparato no la tiene». Para distinguirlos
  // haría falta recordar qué frases subió cada aparato, y es un diseño
  // aparte. Entre una frase que sobrevive de más y una frase que se pierde,
  // esta app prefiere la primera: es de lo que se trata.

  Future<void> _reemplazarHijos(
    Libro libro,
    String lecturaId, {
    required String perfilId,
  }) async {
    // La nota privada, en su propia tabla.
    //
    // No es un capricho de esquema: `servidor/esquema.sql` lo explica en
    // su encabezado —Postgres protege filas, no columnas—. Si la nota
    // fuera una columna de `lecturas`, el permiso que deja a otra persona
    // ver tu estante dejaría ver también tus notas.
    if (libro.tieneNota) {
      await _base.from('notas').upsert({
        'lectura_id': lecturaId,
        'texto': libro.nota,
      }, onConflict: 'lectura_id');
    }
    // Sin `else` que borre: la misma razón que las frases. Un aparato sin
    // la nota no sabe si no existe o si nunca la vio.

    if (libro.animos.isNotEmpty) {
      await _base.from('lectura_animos').delete().eq('lectura_id', lecturaId);
      await _base.from('lectura_animos').insert([
        for (final a in libro.animos) {'lectura_id': lecturaId, 'animo': a},
      ]);
    }

    if (libro.personajes.isNotEmpty) {
      await _base.from('personajes').delete().eq('lectura_id', lecturaId);
      await _base.from('personajes').insert([
        for (final p in libro.personajes)
          {'lectura_id': lecturaId, 'nombre': p},
      ]);
    }

    if (libro.frases.isNotEmpty) {
      await _base.from('frases').delete().eq('lectura_id', lecturaId);
      await _base.from('frases').insert([
        for (final f in libro.frases)
          {
            'lectura_id': lecturaId,
            'texto': f.texto,
            'pagina': paginaDeFrase(f, libro),
          },
      ]);
    }

    if (libro.estantes.isNotEmpty) {
      final ids = <String>[];
      for (final nombre in libro.estantes) {
        final fila = await _base
            .from('estantes')
            .upsert({
              'perfil_id': perfilId,
              'nombre': nombre,
            }, onConflict: 'perfil_id,nombre')
            .select('id')
            .single();
        ids.add(fila['id'] as String);
      }
      await _base.from('estante_lecturas').delete().eq('lectura_id', lecturaId);
      await _base.from('estante_lecturas').insert([
        for (final id in ids) {'estante_id': id, 'lectura_id': lecturaId},
      ]);
    }
  }

  // ---------- La libreta: qué fila de la nube es cada libro ----------

  Future<Map<String, dynamic>> _libreta() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null) return {};
    try {
      return jsonDecode(crudo) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<_Registro?> _leerRegistro(String claveLibro) async {
    final libreta = await _libreta();
    final fila = libreta[claveLibro];
    if (fila == null) return null;
    return _Registro(
      edicionId: fila['edicionId'] as String?,
      fanficId: fila['fanficId'] as String?,
    );
  }

  Future<void> _guardarRegistro(String claveLibro, _Registro registro) async {
    final prefs = await SharedPreferences.getInstance();
    final libreta = await _libreta();
    libreta[claveLibro] = {
      'edicionId': registro.edicionId,
      'fanficId': registro.fanficId,
    };
    await prefs.setString(_clave, jsonEncode(libreta));
  }

  Future<void> _olvidarRegistro(String claveLibro) async {
    final prefs = await SharedPreferences.getInstance();
    final libreta = await _libreta();
    libreta.remove(claveLibro);
    await prefs.setString(_clave, jsonEncode(libreta));
  }
}

class _Registro {
  final String? edicionId;
  final String? fanficId;
  const _Registro({this.edicionId, this.fanficId});
}

/// Una sola nube para toda la app, como `cuenta` y `biblioteca`.
final nube = Nube();

// ============================================================
// Lo que se manda, aparte de lo que lo manda.
//
// Estas siete funciones son puras: arman un mapa a partir de un Libro y
// nada más, sin tocar la red. Es lo que permite probarlas sin depender de
// Supabase ni de una conexión — lo mismo que ya se hizo con los mensajes
// de error en servidor_supabase.dart.
// ============================================================

Map<String, dynamic> filaDeObra(Libro libro) => {
  'titulo': libro.titulo,
  'autor': libro.autor,
  'clave': libro.claveDeObra,
};

Map<String, dynamic> filaDeEdicion(
  Libro libro, {
  required String obraId,
  required String cargadaPor,
}) => {
  'obra_id': obraId,
  'titulo': libro.titulo,
  'editorial': libro.editorial,
  'anio': libro.anio,
  'paginas': libro.paginas,
  // La dirección resuelta y no `libro.tapaUrl` a secas. Los libros que
  // vienen de Open Library —o sea casi todos— no traen una dirección:
  // traen un número de tapa, y la dirección se arma con él. Mandando el
  // campo crudo se subía `null`, y la tapa se perdía en el viaje: al
  // bajar la biblioteca en otro teléfono, esos libros salían con la tapa
  // dibujada en vez de la de verdad. Ver [Api.tapaDe].
  'tapa_url': Api.tapaDe(libro),
  'isbn': libro.isbn,
  'origen': libro.origen == Origen.propio ? 'propio' : 'catalogo',
  'cargada_por': cargadaPor,
};

Map<String, dynamic> filaDeFanfic(Libro libro) => {
  'identidad': Fanfic.identidad(libro.enlace!),
  'enlace': libro.enlace,
  'titulo': libro.titulo,
  'autoria': libro.autor,
  'fandom': libro.fandom,
  'capitulos': libro.paginas,
};

Map<String, dynamic> filaDeLectura(
  Libro libro, {
  required String perfilId,
  String? edicionId,
  String? fanficId,
}) => {
  'perfil_id': perfilId,
  if (edicionId != null) 'edicion_id': edicionId,
  if (fanficId != null) 'fanfic_id': fanficId,
  'estado': libro.estado.name,
  'puntaje': libro.puntaje,
  'lagrimas': libro.lagrimas,
  'romantico': libro.romantico,
  'picante': libro.picante,
  'pagina_actual': libro.paginaActual,
  if (libro.empezado != null) 'empezado': _yyyyMMdd(libro.empezado!),
  if (libro.terminado != null) 'terminado': _yyyyMMdd(libro.terminado!),
  'resena': libro.resena,
  'resena_con_spoilers': libro.resenaConSpoilers,
};

/// Una reseña escrita por otra persona.
///
/// Es su propio tipo y no un [Libro] con la reseña adentro, porque no es un
/// libro: es lo que alguien dijo de uno. Mezclarlas obligaría a inventar un
/// libro falso alrededor de cada reseña.
class ResenaAjena {
  final String texto;
  final bool conSpoilers;
  final String usuario;
  final String nombre;

  /// De 0 a 5, o 0 si no puntuó.
  final int puntaje;

  /// Cuándo lo terminó, si lo anotó. Sirve para ordenar: la reseña de
  /// alguien que acabó el libro anteayer es más útil que una de 2019.
  final DateTime? terminado;

  /// Si es tuya. Se marca para que no parezca que hay una desconocida
  /// diciendo exactamente lo que vos escribiste.
  final bool esTuya;

  const ResenaAjena({
    required this.texto,
    required this.conSpoilers,
    required this.usuario,
    required this.nombre,
    this.puntaje = 0,
    this.terminado,
    this.esTuya = false,
  });

  /// Cómo se firma: el nombre si lo puso, el @usuario si no.
  String get comoSeLlama => nombre.trim().isEmpty ? '@$usuario' : nombre;
}

/// Lo que se le pide al servidor de cada reseña ajena.
///
/// # Por qué son dos consultas y no una
///
/// La primera versión pedía `ediciones!inner` **y** `fanfics!inner` en el
/// mismo select, y habría devuelto **cero reseñas siempre**. `!inner` es un
/// inner join: exige que haya coincidencia. Y `lecturas` tiene este check:
///
///     constraint una_cosa_por_lectura
///       check (num_nonnulls(edicion_id, fanfic_id) = 1)
///
/// O sea que ninguna fila tiene las dos cosas, nunca. Pedir las dos con
/// inner es pedir algo que la base prohíbe.
///
/// No lo atrapó ninguna prueba y no lo habría atrapado el servidor: la
/// consulta es válida, contesta 200, y devuelve una lista vacía —que es
/// exactamente lo que devuelve cuando de verdad no hay reseñas—. Se vio
/// leyendo el check del esquema.
///
/// # Por qué `!inner` en las que sí van
///
/// Sin eso, PostgREST devuelve también las lecturas cuyo perfil no se puede
/// ver, con el embebido en null, y habría que filtrarlas acá.
const _comunes =
    'resena,resena_con_spoilers,puntaje,terminado,perfil_id,'
    'perfiles!inner(usuario,nombre)';

/// Para un libro: se cruza hasta la clave de la obra.
///
/// Una reseña es del libro y no del ejemplar. Si alguien leyó la edición de
/// Salamandra y vos tenés la de bolsillo, su reseña te sirve igual.
const resenasDeUnLibro = '$_comunes,ediciones!inner(obras!inner(clave))';

/// Para un fanfic: por su dirección, que es su identidad.
const resenasDeUnFanfic = '$_comunes,fanfics!inner(identidad)';

/// Las filas del servidor, convertidas en reseñas.
///
/// Pura, así que se prueba con las respuestas que da el servidor sin
/// necesitar internet — lo mismo que [libroDeFila].
///
/// # El orden
///
/// Las que tienen fecha de terminado primero, de la más reciente a la más
/// vieja, y las que no la tienen al final. Quien acabó el libro anteayer
/// tiene más fresco lo que sintió que quien lo terminó en 2019.
///
/// **La tuya va primera de todas.** No por vanidad: es lo que hace que se
/// entienda de un vistazo que una de esas voces sos vos, en vez de leerla
/// creyendo que es de otra persona.
List<ResenaAjena> resenasDeFilas(List<dynamic> filas, {String? yo}) {
  final salida = <ResenaAjena>[];

  for (final cruda in filas) {
    if (cruda is! Map) continue;
    final f = cruda.cast<String, dynamic>();

    final texto = (f['resena'] as String?)?.trim();
    if (texto == null || texto.isEmpty) continue;

    final perfil = (f['perfiles'] as Map?)?.cast<String, dynamic>();
    if (perfil == null) continue;

    salida.add(
      ResenaAjena(
        texto: texto,
        conSpoilers: (f['resena_con_spoilers'] as bool?) ?? false,
        usuario: (perfil['usuario'] as String?) ?? '',
        nombre: (perfil['nombre'] as String?) ?? '',
        puntaje: (f['puntaje'] as int?) ?? 0,
        terminado: DateTime.tryParse((f['terminado'] as String?) ?? ''),
        esTuya: yo != null && f['perfil_id'] == yo,
      ),
    );
  }

  salida.sort((a, b) {
    if (a.esTuya != b.esTuya) return a.esTuya ? -1 : 1;
    final ta = a.terminado;
    final tb = b.terminado;
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1; // sin fecha, al final
    if (tb == null) return -1;
    return tb.compareTo(ta);
  });

  return salida;
}

/// Todo lo que hace falta de una lectura, en un solo pedido.
///
/// # Por qué una sola consulta y no siete
///
/// Una lectura son ocho tablas: la lectura, su edición, la obra de esa
/// edición —o el fanfic, si es uno—, los ánimos, los personajes, las
/// frases, y los estantes por el medio. Pidiéndolas de a una serían ocho
/// viajes por libro: con doscientos libros, mil seiscientos pedidos desde
/// un teléfono. Así es uno.
///
/// Los nombres entre paréntesis no son inventados: PostgREST los resuelve
/// siguiendo las claves ajenas que ya están declaradas en el esquema. Si
/// alguno estuviera mal escrito, la respuesta sería un 400 diciendo cuál,
/// y eso es justo lo que prueba `servidor/probar_bajada.sh`.
const todoLoDeUnaLectura =
    '*,'
    'ediciones(*,obras(titulo,autor)),'
    'fanfics(*),'
    'lectura_animos(animo),'
    'personajes(nombre),'
    'frases(texto,pagina,creada),'
    'notas(texto),'
    'estante_lecturas(estantes(nombre))';

/// Una lectura de la nube, convertida en un [Libro] de la app.
///
/// Es lo inverso de [filaDeLectura] y compañía, y como ellas es pura: se
/// le da el mapa que devolvió PostgREST y devuelve el libro, sin tocar la
/// red. Por eso se puede probar de verdad, con las respuestas que da el
/// servidor, en vez de solo esperar que ande.
///
/// Devuelve `null` si la fila no tiene ni edición ni fanfic. La base no
/// deja que eso pase —hay un `check` que lo prohíbe— pero la app no tiene
/// por qué caerse si algún día pasa.
Libro? libroDeFila(Map<String, dynamic> fila) {
  final edicion = (fila['ediciones'] as Map?)?.cast<String, dynamic>();
  final fanfic = (fila['fanfics'] as Map?)?.cast<String, dynamic>();
  if (edicion == null && fanfic == null) return null;

  final paginas = (edicion?['paginas'] ?? fanfic?['capitulos']) as int?;

  return Libro(
    // El id que tenía en el teléfono de antes no viajó, así que se usa el
    // de la nube. No se pierde nada por eso: lo único que lo usaba era
    // pedirle a Open Library las otras ediciones, y [Api.ediciones] ya
    // sabe arreglárselas cuando el id no es uno de Open Library —busca la
    // obra por título y autoría—, porque hacía falta para los libros que
    // vienen de Google.
    id: (edicion?['id'] ?? fanfic?['id']) as String,
    titulo: (edicion?['titulo'] ?? fanfic?['titulo']) as String,
    autor:
        ((edicion?['obras'] as Map?)?['autor'] ?? fanfic?['autoria'] ?? '')
            as String,
    tapaUrl: edicion?['tapa_url'] as String?,
    isbn: edicion?['isbn'] as String?,
    enlace: fanfic?['enlace'] as String?,
    fandom: fanfic?['fandom'] as String?,
    editorial: edicion?['editorial'] as String?,
    anio: edicion?['anio'] as int?,
    paginas: paginas,
    origen: fanfic != null
        ? Origen.fanfic
        : edicion?['origen'] == 'propio'
        ? Origen.propio
        : Origen.catalogo,
    estado: _estadoDe(fila['estado'] as String?),
    puntaje: (fila['puntaje'] as int?) ?? 0,
    lagrimas: (fila['lagrimas'] as int?) ?? 0,
    romantico: (fila['romantico'] as int?) ?? 0,
    picante: (fila['picante'] as int?) ?? 0,
    paginaActual: (fila['pagina_actual'] as int?) ?? 0,
    empezado: DateTime.tryParse((fila['empezado'] as String?) ?? ''),
    terminado: DateTime.tryParse((fila['terminado'] as String?) ?? ''),
    resena: fila['resena'] as String?,
    resenaConSpoilers: (fila['resena_con_spoilers'] as bool?) ?? false,
    nota: _notaDe(fila['notas']),
    animos: _lista(fila['lectura_animos'], 'animo'),
    personajes: _lista(fila['personajes'], 'nombre'),
    frases: _frasesDe(fila['frases'], paginas: paginas),
    estantes: _estantesDe(fila['estante_lecturas']),
  );
}

/// La nota privada, que viene embebida como una fila o como null.
///
/// PostgREST devuelve un objeto y no una lista porque `notas` tiene el
/// `lectura_id` como clave primaria: hay una nota por lectura, o ninguna.
String? _notaDe(Object? embebido) {
  if (embebido is Map) return embebido['texto'] as String?;
  // Por si alguna vez viene como lista de una: no cuesta nada aguantarlo.
  if (embebido is List && embebido.isNotEmpty && embebido.first is Map) {
    return (embebido.first as Map)['texto'] as String?;
  }
  return null;
}

Estado _estadoDe(String? nombre) => Estado.values.firstWhere(
  (e) => e.name == nombre,
  orElse: () => Estado.pendiente,
);

/// Los valores de una columna, de una lista de filas embebidas.
List<String> _lista(Object? filas, String columna) => [
  if (filas is List)
    for (final f in filas)
      if (f is Map && f[columna] is String) f[columna] as String,
];

/// Las frases, con la posición reconstruida.
///
/// La app guarda dónde estaba la frase como una fracción de 0 a 1 y la
/// base guarda un número de página: ver [paginaDeFrase], que hace el
/// camino de ida. La vuelta divide por las páginas **de esta** edición, y
/// solo si se conocen las dos cosas. Si no, la frase igual vuelve: el
/// texto es lo que importa, la posición es el adorno.
List<Frase> _frasesDe(Object? filas, {int? paginas}) => [
  if (filas is List)
    for (final f in filas)
      if (f is Map && f['texto'] is String)
        Frase(
          texto: f['texto'] as String,
          guardada: DateTime.tryParse((f['creada'] as String?) ?? ''),
          posicion: (f['pagina'] is int && paginas != null && paginas > 0)
              ? ((f['pagina'] as int) / paginas).clamp(0.0, 1.0)
              : null,
        ),
];

/// Los estantes vienen con una tabla del medio, así que hay dos niveles.
Set<String> _estantesDe(Object? filas) => {
  if (filas is List)
    for (final f in filas)
      if (f is Map && f['estantes'] is Map)
        if ((f['estantes'] as Map)['nombre'] is String)
          (f['estantes'] as Map)['nombre'] as String,
};

String _yyyyMMdd(DateTime d) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${dos(d.month)}-${dos(d.day)}';
}

/// En qué página estaba la frase, si se puede saber.
///
/// La app guarda la posición como una fracción de 0 a 1 —"cerca del
/// final"— porque las páginas cambian con cada edición. La base guarda un
/// número de página, que es lo que espera quien mire el catálogo desde
/// afuera. Se convierte acá, con la cantidad de páginas *de esta*
/// edición, y solo si las dos cosas se conocen.
int? paginaDeFrase(Frase frase, Libro libro) {
  final posicion = frase.posicion;
  final paginas = libro.paginas;
  if (posicion == null || paginas == null || paginas <= 0) return null;
  return (posicion * paginas).round();
}
