import 'package:flutter/material.dart';

import '../cuenta.dart';
import '../modelos.dart';
import '../nube.dart';
import '../tema.dart';
import '../widgets.dart';
import '../insignias.dart';
import 'crear_cuenta.dart';
import 'elegir_perfil.dart';
import 'ficha.dart';

/// Vos: tu perfil y lo que leíste.
///
/// # Por qué el perfil y los números van juntos
///
/// Porque son la misma cosa. Un perfil de lectora no es una foto y una
/// frase: es lo que leíste. Cuando exista la comunidad, esta es la
/// pantalla que va a ver quien entre a tu estante, y separarla en «datos»
/// y «estadísticas» sería partir en dos algo que se lee de un tirón.
///
/// # Qué se cuenta y qué no
///
/// Se cuentan cosas que se pueden mirar sin sentirse mal: cuánto leíste,
/// cuánto lloraste, qué etiquetas usás. **No hay rachas ni metas anuales**
/// —eso convierte leer en una tarea— y no hay nada que se pueda perder por
/// dejar de entrar una semana.
class PantallaVos extends StatelessWidget {
  const PantallaVos({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([cuenta, biblioteca]),
      builder: (context, _) {
        final perfil = cuenta.perfil;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Paleta.lila,
            elevation: 0,
            title: const Text(
              'Vos',
              style: TextStyle(color: Paleta.luz, fontSize: 17),
            ),
            actions: [
              if (perfil != null)
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PantallaCrearCuenta(editando: true),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  color: Paleta.lila,
                  tooltip: 'Editar',
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Columna(
              hijo: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: perfil == null
                    ? const [_SinPerfil()]
                    : [
                        _Encabezado(perfil),
                        const SizedBox(height: 24),
                        _Insignias(perfil.insignias),
                        _LibrosQueSos(perfil.libros),
                        const SizedBox(height: 24),
                        const _Numeros(),
                        const SizedBox(height: 28),
                        const _ComoTeDejan(),
                        const SizedBox(height: 28),
                        const _EstadoDeLaCuenta(),
                      ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SinPerfil extends StatelessWidget {
  const _SinPerfil();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 40, 8, 0),
      child: Column(
        children: [
          Text(
            'Todavía no tenés perfil.',
            style: Tipo.titulo,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Es un nombre, un @usuario, una foto y los libros que sos: lo '
            'que va a ver quien entre a tu estante.',
            style: Tipo.meta,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          BotonLleno(
            'Armar mi perfil',
            alTocar: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaCrearCuenta()),
            ),
          ),

          // La segunda puerta, y va acá porque es donde alguien la busca.
          //
          // Estaba escondida adentro del texto que explica por qué no hay
          // contraseña, y ese texto solo se muestra cuando **no** hay
          // servidor. O sea que el día que conectamos Supabase, la única
          // forma de entrar a una cuenta que ya existe desapareció justo
          // cuando empezó a servir para algo.
          if (cuenta.servidor.disponible) ...[
            const SizedBox(height: 12),
            BotonContorno(
              'Ya tengo cuenta',
              alTocar: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PantallaEntrar())),
            ),
            const SizedBox(height: 14),
            Text(
              'Si ya usaste Colibrí en otro teléfono, entrá y traés todo.',
              style: Tipo.meta.copyWith(fontSize: 11.5),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final Perfil perfil;
  const _Encabezado(this.perfil);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(perfil, tamano: 62),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(perfil.comoSeLlama, style: Tipo.titulo),
              const SizedBox(height: 2),
              Text('@${perfil.usuario}', style: Tipo.meta),
              if (perfil.presentacion.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(perfil.presentacion, style: Tipo.cuerpo),
              ],
              const SizedBox(height: 10),
              Text('Acá desde ${fechaCorta(perfil.desde)}', style: Tipo.meta),
            ],
          ),
        ),
      ],
    );
  }
}

/// Las insignias puestas, arriba de todo.
///
/// Van antes que los números porque contestan otra cosa: los números
/// dicen cuánto leíste, la insignia dice de qué lado estás. Lo segundo se
/// mira primero.
class _Insignias extends StatelessWidget {
  final List<String> claves;
  const _Insignias(this.claves);

  @override
  Widget build(BuildContext context) {
    final puestas = claves
        .map(Insignia.porClave)
        .whereType<Insignia>()
        .toList();
    if (puestas.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(
        spacing: 7,
        runSpacing: 8,
        children: [for (final i in puestas) ChapaDeInsignia(i)],
      ),
    );
  }
}

/// Los tres libros que te representan.
class _LibrosQueSos extends StatelessWidget {
  final List<String> claves;
  const _LibrosQueSos(this.claves);

  @override
  Widget build(BuildContext context) {
    if (claves.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Rotulo('Los libros que soy'),
        const SizedBox(height: 12),
        TusLibros(
          claves,
          alTocar: (libro) => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => PantallaFicha(libro))),
        ),
      ],
    );
  }
}

/// Lo que leíste, en números.
class _Numeros extends StatelessWidget {
  const _Numeros();

  @override
  Widget build(BuildContext context) {
    final leidos = biblioteca.enEstado(Estado.leido);
    final paginas = leidos.fold<int>(0, (s, l) => s + (l.paginas ?? 0));
    final puntuados = leidos.where((l) => l.puntaje > 0).toList();
    final frases = biblioteca.todos.fold<int>(0, (s, l) => s + l.frases.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Rotulo('Lo que leíste'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Dato('${leidos.length}', 'leídos'),
            _Dato('${biblioteca.enEstado(Estado.leyendo).length}', 'leyendo'),
            _Dato(
              '${biblioteca.enEstado(Estado.pendiente).length}',
              'esperando',
            ),
            if (biblioteca.fanfics.isNotEmpty)
              _Dato('${biblioteca.fanfics.length}', 'fanfics'),
            if (paginas > 0) _Dato('$paginas', 'páginas'),
            if (frases > 0) _Dato('$frases', 'frases guardadas'),
            if (puntuados.isNotEmpty)
              _Dato(
                (puntuados.fold<int>(0, (s, l) => s + l.puntaje) /
                        puntuados.length)
                    .toStringAsFixed(1),
                'estrellas en promedio',
              ),
          ],
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  final String numero;
  final String que;
  const _Dato(this.numero, this.que);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Paleta.nocheAlta,
        border: Border.all(color: Paleta.linea),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            numero,
            style: const TextStyle(
              color: Paleta.oro,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(que, style: Tipo.meta.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// Las etiquetas que más usás.
///
/// Es lo que más dice de alguien como lectora, más que la cantidad: no es
/// lo mismo quien pone «me destruyó» en la mitad de sus libros que quien
/// pone «me dio paz».
class _ComoTeDejan extends StatelessWidget {
  const _ComoTeDejan();

  @override
  Widget build(BuildContext context) {
    // Se llama «veces» y no «cuenta» a propósito: hay una `cuenta` global
    // —la del perfil— y una variable local con ese nombre la tapa. Hoy no
    // rompe nada, pero el día que alguien quiera mostrar el @usuario acá
    // adentro recibiría este mapa y no entendería por qué.
    final veces = <String, int>{};
    for (final libro in biblioteca.todos) {
      for (final animo in libro.animos) {
        veces[animo] = (veces[animo] ?? 0) + 1;
      }
    }
    if (veces.isEmpty) return const SizedBox.shrink();

    final ordenadas = veces.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Rotulo('Cómo te dejan los libros'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 8,
          children: [
            for (final e in ordenadas.take(6))
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x22B9A6E6),
                  border: Border.all(color: Paleta.lila),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '${e.key} · ${e.value}',
                  style: const TextStyle(fontSize: 13, color: Paleta.lila),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Dónde vive todo esto, dicho sin vueltas.
/// Traer la biblioteca de la nube, a mano.
///
/// # Por qué hace falta un botón si ya se hace solo
///
/// Al entrar se sincroniza sin que nadie lo pida, pero eso pasa una vez y
/// puede fallar: justo en ese momento no había señal, o el servidor no
/// contestó. Sin un botón, la única forma de reintentar sería salir y
/// volver a entrar, y quien acaba de reinstalar la app y ve su biblioteca
/// vacía no tiene por qué adivinar eso.
///
/// Y con la firma gratis de Apple —siete días— reinstalar no es algo raro
/// que pasa una vez: es todas las semanas.
class _TraerMisLibros extends StatefulWidget {
  const _TraerMisLibros();

  @override
  State<_TraerMisLibros> createState() => _TraerMisLibrosState();
}

class _TraerMisLibrosState extends State<_TraerMisLibros> {
  bool _trayendo = false;

  Future<void> _traer() async {
    if (_trayendo) return; // dos toques no son dos sincronizaciones
    setState(() => _trayendo = true);

    final cuenta = await nube.sincronizar(biblioteca);
    if (!mounted) return;

    setState(() => _trayendo = false);
    avisar(ScaffoldMessenger.of(context), switch (cuenta.bajados) {
      0 => 'Ya tenías todo lo que hay en tu cuenta.',
      1 => 'Volvió 1 libro.',
      final n => 'Volvieron $n libros.',
    });
  }

  @override
  Widget build(BuildContext context) => BotonContorno(
    _trayendo ? 'Trayendo…' : 'Traer mis libros',
    alTocar: _trayendo ? null : _traer,
  );
}

class _EstadoDeLaCuenta extends StatelessWidget {
  const _EstadoDeLaCuenta();

  @override
  Widget build(BuildContext context) {
    final aSalvo = cuenta.estaARescate;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: aSalvo ? Paleta.nocheAlta : Paleta.oroTenue,
        border: Border.all(color: aSalvo ? Paleta.linea : Paleta.oroBorde),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Rotulo(aSalvo ? 'Tu cuenta' : 'Todo esto vive en este teléfono'),
          const SizedBox(height: 8),
          Text(
            aSalvo
                ? 'Tu biblioteca está guardada en tu cuenta. Si cambiás de '
                      'teléfono, entrás y está todo.'
                : 'Colibrí todavía no tiene servidor, así que tu biblioteca y '
                      'tu perfil están solo acá. Si perdés el teléfono, se '
                      'pierden.\n\nEso es lo que van a arreglar las cuentas, y '
                      'es lo próximo que se construye.',
            style: Tipo.meta.copyWith(color: aSalvo ? null : Paleta.oroTexto),
          ),
          const SizedBox(height: 12),
          if (aSalvo) ...[const _TraerMisLibros(), const SizedBox(height: 10)],
          BotonContorno(
            'Borrar mi perfil',
            alTocar: () => _confirmarSalir(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarSalir(BuildContext context) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Paleta.nocheAlta,
        title: Text('¿Borrar tu perfil?', style: Tipo.subtitulo),
        content: Text(
          'Se borra el nombre, el @usuario y la presentación.\n\n'
          'Tus libros no se tocan: los leíste vos, no la cuenta.',
          style: Tipo.meta,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Paleta.bruma),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Paleta.lila),
            child: const Text('Borrarlo'),
          ),
        ],
      ),
    );

    if (seguro == true) await cuenta.salir();
  }
}
