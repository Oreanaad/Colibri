import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'buscar.dart';
import 'estantes.dart';
import 'ficha.dart';

/// Las cuatro solapas de la biblioteca. Las tres primeras son estados de
/// lectura; la cuarta son los estantes que arma cada persona.
enum _Solapa { leyendo, leidos, pendientes, estantes }

extension on _Solapa {
  String get nombre => switch (this) {
        _Solapa.leyendo => 'Leyendo',
        _Solapa.leidos => 'Leídos',
        _Solapa.pendientes => 'Pendientes',
        _Solapa.estantes => 'Estantes',
      };

  /// Null en la solapa de estantes: esa no filtra por estado.
  Estado? get estado => switch (this) {
        _Solapa.leyendo => Estado.leyendo,
        _Solapa.leidos => Estado.leido,
        _Solapa.pendientes => Estado.pendiente,
        _Solapa.estantes => null,
      };
}

class PantallaBiblioteca extends StatefulWidget {
  const PantallaBiblioteca({super.key});

  @override
  State<PantallaBiblioteca> createState() => _PantallaBibliotecaState();
}

class _PantallaBibliotecaState extends State<PantallaBiblioteca> {
  _Solapa _activa = _Solapa.leyendo;

  void _irABuscar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PantallaBuscar()),
    );
  }

  void _abrir(Libro libro) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaFicha(libro)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: biblioteca,
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
                    IconButton(
                      onPressed: _irABuscar,
                      icon: const Icon(Icons.search_rounded),
                      color: Paleta.lila,
                      tooltip: 'Buscar y agregar',
                    ),
                  ],
                ),
              ),
              _Solapas(
                activa: _activa,
                alCambiar: (s) => setState(() => _activa = s),
              ),
              Expanded(
                child: _activa == _Solapa.estantes
                    ? const VistaEstantes()
                    : _listaDeEstado(_activa.estado!),
              ),
            ],
          ),
        );
      },
    );
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
    final avance = total > 0 ? (libro.paginaActual / total).clamp(0.0, 1.0) : 0.0;

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
                  Text(libro.titulo,
                      style: Tipo.subtitulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
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
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Paleta.lila),
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
