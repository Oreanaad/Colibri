import 'package:flutter/material.dart';
import '../cuenta.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'buscar.dart';
import 'estantes.dart';
import 'ficha.dart';
import 'vos.dart';

/// Las cuatro solapas de la biblioteca. Las tres primeras son estados de
/// lectura; la cuarta son los estantes que arma cada persona.
/// Las solapas de la biblioteca.
///
/// «Todos» va primera y es la que se abre por defecto: es tu estante
/// entero, que es lo que una espera ver al entrar a su biblioteca. Las
/// otras son formas de mirar una parte.
enum _Solapa { todos, leyendo, leidos, pendientes, estantes }

extension on _Solapa {
  String get nombre => switch (this) {
    _Solapa.todos => 'Todos',
    _Solapa.leyendo => 'Leyendo',
    _Solapa.leidos => 'Leídos',
    _Solapa.pendientes => 'Pendientes',
    _Solapa.estantes => 'Estantes',
  };

  /// Null en «Todos» y en «Estantes»: esas dos no filtran por estado.
  Estado? get estado => switch (this) {
    _Solapa.leyendo => Estado.leyendo,
    _Solapa.leidos => Estado.leido,
    _Solapa.pendientes => Estado.pendiente,
    _ => null,
  };
}

class PantallaBiblioteca extends StatefulWidget {
  const PantallaBiblioteca({super.key});

  @override
  State<PantallaBiblioteca> createState() => _PantallaBibliotecaState();
}

class _PantallaBibliotecaState extends State<PantallaBiblioteca> {
  late _Solapa _activa =
      _Solapa.values[sesion.solapa.clamp(0, _Solapa.values.length - 1)];

  final _buscador = TextEditingController();
  String _filtro = '';

  /// A partir de cuántos libros aparece el buscador.
  ///
  /// Con menos, los ves todos de un vistazo y un campo de búsqueda es
  /// una caja vacía que solo ocupa lugar.
  static const _desde = 8;

  bool get _buscando => _filtro.trim().length >= 2;

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  void _limpiar() {
    _buscador.clear();
    setState(() => _filtro = '');
  }

  void _irABuscar() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PantallaBuscar()));
  }

  void _abrir(Libro libro) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PantallaFicha(libro)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([biblioteca, cuenta]),
      builder: (context, _) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Logotipo(tamano: 22),
                    const Spacer(),

                    // Tu cara, arriba a la derecha, que es donde la busca
                    // todo el mundo. Sin perfil todavía es una silueta:
                    // así se ve que ese lugar existe y que falta algo.
                    IconButton(
                      onPressed: _irAVos,
                      icon: cuenta.perfil == null
                          ? const Icon(Icons.person_outline_rounded, size: 26)
                          : Avatar(cuenta.perfil!, tamano: 30),
                      color: Paleta.bruma,
                      tooltip: 'Vos',
                    ),
                    // Un más y no una lupa.
                    //
                    // Este botón trae libros de internet; la lupa está
                    // abajo y busca en los que ya tenés. Con dos lupas,
                    // una al lado de la otra, no hay forma de saber cuál
                    // hace qué.
                    IconButton(
                      onPressed: _irABuscar,
                      icon: const Icon(Icons.add_rounded),
                      color: Paleta.lila,
                      tooltip: 'Agregar un libro',
                    ),
                  ],
                ),
              ),
              if (biblioteca.todos.length >= _desde)
                Columna(
                  hijo: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: _Buscador(
                      controlador: _buscador,
                      cuantos: biblioteca.todos.length,
                      alEscribir: (v) => setState(() => _filtro = v),
                      alLimpiar: _buscando ? _limpiar : null,
                    ),
                  ),
                ),

              // Mientras se busca no hay solapas: la búsqueda mira toda
              // la biblioteca, y dejar una solapa marcada haría pensar
              // que solo busca ahí.
              if (!_buscando)
                _Solapas(
                  activa: _activa,
                  alCambiar: (s) {
                    setState(() => _activa = s);
                    sesion.anotar(solapa: s.index);
                  },
                ),

              Expanded(
                child: Columna(
                  hijo: _buscando
                      ? _resultados()
                      : switch (_activa) {
                          _Solapa.estantes => const VistaEstantes(),
                          _Solapa.todos => _todo(),
                          _ => _listaDeEstado(_activa.estado!),
                        },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _irAVos() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PantallaVos()));
  }

  Widget _resultados() {
    final encontrados = biblioteca.buscarEnMiBiblioteca(_filtro);

    if (encontrados.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 44, 32, 0),
        child: Column(
          children: [
            Text(
              'No tenés ningún libro que diga «${_filtro.trim()}».',
              style: Tipo.cuerpo,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Busca en el título, en la autoría y en los nombres de tus '
              'estantes.',
              style: Tipo.meta,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 260,
              child: BotonContorno('Buscarlo en internet', alTocar: _irABuscar),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Rotulo(
          encontrados.length == 1
              ? '1 libro en tu biblioteca'
              : '${encontrados.length} libros en tu biblioteca',
        ),
        const SizedBox(height: 12),
        GrillaLibros(encontrados, alTocar: _abrir),
      ],
    );
  }

  /// Tu estante entero, en un solo lugar.
  ///
  /// # Por qué en secciones y no todo mezclado
  ///
  /// Una grilla con los ciento veinte libros seguidos se ve linda y no
  /// dice nada: no hay forma de saber cuál estás leyendo y cuál esperás
  /// hace dos años. Con las secciones ves todo igual, bajando, y además
  /// sabés qué es cada cosa.
  ///
  /// # Por qué en ese orden
  ///
  /// Leyendo, pendientes, leídos. Es la línea del tiempo de un libro:
  /// lo que estás haciendo, lo que sigue, lo que quedó atrás.
  Widget _todo() {
    final leyendo = biblioteca.enEstado(Estado.leyendo);
    final pendientes = biblioteca.enEstado(Estado.pendiente);
    final leidos = biblioteca.enEstado(Estado.leido);
    final ahora = biblioteca.leyendoAhora;

    if (biblioteca.todos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [_Vacio(estado: Estado.pendiente, alTocar: _irABuscar)],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        if (ahora != null) ...[
          const Rotulo('Ahora mismo'),
          const SizedBox(height: 10),
          _TarjetaLeyendo(ahora, alTocar: () => _abrir(ahora)),
          const SizedBox(height: 26),
        ],
        ..._seccion('Leyendo', leyendo),
        ..._seccion('Pendientes', pendientes),
        ..._seccion('Leídos', leidos),
      ],
    );
  }

  List<Widget> _seccion(String titulo, List<Libro> libros) {
    if (libros.isEmpty) return const [];
    return [
      Rotulo('$titulo · ${libros.length}'),
      const SizedBox(height: 12),
      GrillaLibros(libros, alTocar: _abrir),
      const SizedBox(height: 26),
    ];
  }

  Widget _listaDeEstado(Estado estado) {
    final libros = biblioteca.enEstado(estado);
    final leyendo = biblioteca.leyendoAhora;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        if (leyendo != null && estado == Estado.leyendo) ...[
          const Rotulo('Ahora mismo'),
          const SizedBox(height: 10),
          _TarjetaLeyendo(leyendo, alTocar: () => _abrir(leyendo)),
          const SizedBox(height: 26),
        ],
        if (libros.isEmpty)
          _Vacio(estado: estado, alTocar: _irABuscar)
        else ...[
          Rotulo('${libros.length} ${estado.nombre.toLowerCase()}'),
          const SizedBox(height: 12),
          GrillaLibros(libros, alTocar: _abrir),
        ],
      ],
    );
  }
}

class _Solapas extends StatelessWidget {
  final _Solapa activa;
  final ValueChanged<_Solapa> alCambiar;

  const _Solapas({required this.activa, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Paleta.linea)),
      ),
      child: Row(
        children: _Solapa.values.map((s) {
          final es = s == activa;
          return Expanded(
            child: InkWell(
              onTap: () => alCambiar(s),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: es ? Paleta.lila : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                // Cinco solapas en un teléfono angosto no entran: en una
                // pantalla de 320 puntos le tocan 64 a cada una, y
                // «Pendientes» mide más que eso. Se achica sola en vez de
                // cortarse, porque una solapa que dice «Pendien…» es una
                // solapa que no se entiende.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    s.nombre,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: es ? FontWeight.w600 : FontWeight.w400,
                      color: es ? Paleta.lila : Paleta.bruma,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// El libro que tenés abierto ahora. Va primero porque es la razón por la
/// que alguien abre esta app un martes cualquiera.
class _TarjetaLeyendo extends StatelessWidget {
  final Libro libro;
  final VoidCallback alTocar;

  const _TarjetaLeyendo(this.libro, {required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final total = libro.paginas ?? 0;
    final avance = total > 0
        ? (libro.paginaActual / total).clamp(0.0, 1.0)
        : 0.0;

    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Paleta.nocheAlta,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tapa(libro, ancho: 62),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    libro.titulo,
                    style: Tipo.subtitulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(libro.autor, style: Tipo.meta, maxLines: 1),
                  const SizedBox(height: 14),
                  // La barra es lila, no dorada: el progreso es un dato tuyo,
                  // no un encuentro con nadie.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: avance,
                      minHeight: 5,
                      backgroundColor: Paleta.linea,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Paleta.lila,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    total > 0
                        ? 'página ${libro.paginaActual} de $total · ${(avance * 100).round()}%'
                        : 'tocá para anotar por dónde vas',
                    style: Tipo.meta.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final Estado estado;
  final VoidCallback alTocar;

  const _Vacio({required this.estado, required this.alTocar});

  String get _texto => switch (estado) {
    Estado.leyendo => 'No estás leyendo nada todavía.',
    Estado.leido => 'Todavía no marcaste ningún libro como leído.',
    Estado.pendiente => 'No tenés nada esperando.',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Logotipo(tamano: 32),
          const SizedBox(height: 18),
          Text(_texto, style: Tipo.meta, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
            width: 240,
            child: BotonLleno('Buscar un libro', alTocar: alTocar),
          ),
        ],
      ),
    );
  }
}

/// El buscador de la biblioteca.
///
/// Dice cuántos libros tenés en el propio texto de ayuda. Es la forma
/// más barata de que se entienda que busca en los tuyos y no en internet.
class _Buscador extends StatelessWidget {
  final TextEditingController controlador;
  final int cuantos;
  final ValueChanged<String> alEscribir;
  final VoidCallback? alLimpiar;

  const _Buscador({
    required this.controlador,
    required this.cuantos,
    required this.alEscribir,
    this.alLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      onChanged: alEscribir,
      style: const TextStyle(color: Paleta.luz, fontSize: 14),
      cursorColor: Paleta.lila,
      decoration: InputDecoration(
        hintText: 'Buscar en tus $cuantos libros',
        hintStyle: Tipo.meta,
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Paleta.bruma,
          size: 19,
        ),
        suffixIcon: alLimpiar == null
            ? null
            : IconButton(
                onPressed: alLimpiar,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: Paleta.bruma,
                tooltip: 'Limpiar',
              ),
        isDense: true,
        filled: true,
        fillColor: Paleta.nocheAlta,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Paleta.linea),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Paleta.linea),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Paleta.lila),
        ),
      ),
    );
  }
}
