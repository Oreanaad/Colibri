import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fanfic.dart';
import 'modelos.dart';

/// Subir tu biblioteca a Supabase.
///
/// # Lo que hace y lo que no
///
/// Sube. No hay "bajar" todavía: entrar en un teléfono nuevo te trae el
/// perfil, pero no tus libros. Traerlos es el paso que sigue a este, y
/// no está hecho a propósito de dejarlo afuera en vez de hacerlo mal.
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
/// libro. Si se pierde esa libreta —la app se reinstala, se borra el
/// almacenamiento— el próximo cambio crea una edición de más: la lectura
/// no se pierde, pero el catálogo le queda un fantasma. Es una limitación
/// conocida y no un bug que se nos escapó.
class Nube {
  static const _clave = 'colibri.nube.v1';

  SupabaseClient get _base => Supabase.instance.client;

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

  Future<void> subirLibro(Libro libro) async {
    final yo = _base.auth.currentUser;
    if (yo == null) return;

    try {
      final registro = await _leerRegistro(libro.clave);

      final String? edicionId;
      final String? fanficId;

      if (libro.origen == Origen.fanfic) {
        fanficId = await _idDeFanfic(libro);
        edicionId = null;
      } else {
        final obraId = await _idDeObra(libro, cargadaPor: yo.id);
        edicionId = await _idDeEdicion(
          libro,
          obraId: obraId,
          cargadaPor: yo.id,
          cacheado: registro?.edicionId,
        );
        fanficId = null;
      }

      final lectura = await _base
          .from('lecturas')
          .upsert(
            filaDeLectura(
              libro,
              perfilId: yo.id,
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

      await _reemplazarHijos(libro, lecturaId, perfilId: yo.id);
    } catch (_) {
      // Sin internet, o el servidor no contestó: la lectura queda igual
      // en el teléfono. Se va a volver a intentar la próxima vez que se
      // toque este libro, y no hay nada que romper acá adentro: el
      // guardado local ya pasó antes de que se llame a esto.
    }
  }

  Future<void> borrarLibro(String clave) async {
    final yo = _base.auth.currentUser;
    if (yo == null) return;

    try {
      final registro = await _leerRegistro(clave);
      if (registro == null) return; // nunca subido, nada que borrar

      // Se borra la lectura, nunca la obra ni la edición ni el fanfic:
      // esos son del catálogo compartido, y sacar tu lectura no puede
      // sacarle el libro a nadie más.
      final query = _base.from('lecturas').delete().eq('perfil_id', yo.id);
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

  // ---------- Los hijos: se borran y se vuelven a poner enteros ----------
  //
  // Ni las etiquetas, ni los personajes, ni las frases tienen una clave
  // propia que sobreviva entre sincronizaciones. Diferenciar «esta frase
  // es nueva, esta se borró, esta se editó» sería un mecanismo entero
  // para guardar unos pocos textos cortos. Se borra todo lo de esta
  // lectura y se vuelve a poner tal cual está ahora: más simple, y
  // imposible de dejar desincronizado.

  Future<void> _reemplazarHijos(
    Libro libro,
    String lecturaId, {
    required String perfilId,
  }) async {
    await _base.from('lectura_animos').delete().eq('lectura_id', lecturaId);
    if (libro.animos.isNotEmpty) {
      await _base.from('lectura_animos').insert([
        for (final a in libro.animos) {'lectura_id': lecturaId, 'animo': a},
      ]);
    }

    await _base.from('personajes').delete().eq('lectura_id', lecturaId);
    if (libro.personajes.isNotEmpty) {
      await _base.from('personajes').insert([
        for (final p in libro.personajes)
          {'lectura_id': lecturaId, 'nombre': p},
      ]);
    }

    await _base.from('frases').delete().eq('lectura_id', lecturaId);
    if (libro.frases.isNotEmpty) {
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
    } else {
      await _base.from('estante_lecturas').delete().eq('lectura_id', lecturaId);
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
  'tapa_url': libro.tapaUrl,
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
