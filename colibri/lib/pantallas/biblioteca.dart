import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'buscar.dart';
import 'ficha.dart';

class PantallaBiblioteca extends StatefulWidget {
  const PantallaBiblioteca({super.key});

  @override
  State<PantallaBiblioteca> createState() => _PantallaBibliotecaState();
}

class _PantallaBibliotecaState extends State<PantallaBiblioteca> {
  Estante _activo = Estante.leyendo;

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
        final libros = biblioteca.enEstante(_activo);
        final leyendo = biblioteca.leyendoAhora;

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
              _Pestanas(
                activo: _activo,
                alCambiar: (e) => setState(() => _activo = e),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  children: [
                    if (leyendo != null && _activo == Estante.leyendo) ...[
                      const Rotulo('Ahora mismo'),
                      const SizedBox(height: 10),
                      _TarjetaLeyendo(leyendo, alTocar: () => _abrir(leyendo)),
                      const SizedBox(height: 26),
                    ],
                    if (libros.isEmpty)
                      _Vacio(estante: _activo, alTocar: _irABuscar)
                    else ...[
                      Rotulo('${libros.length} ${_activo.nombre.toLowerCase()}'),
                      const SizedBox(height: 12),
                      _Grilla(libros, alTocar: _abrir),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pestanas extends StatelessWidget {
  final Estante activo;
  final ValueChanged<Estante> alCambiar;

  const _Pestanas({required this.activo, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Paleta.linea)),
      ),
      child: Row(
        children: Estante.values.map((e) {
          final es = e == activo;
          return Expanded(
            child: InkWell(
              onTap: () => alCambiar(e),
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
                  e.nombre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
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

class _Grilla extends StatelessWidget {
  final List<Libro> libros;
  final ValueChanged<Libro> alTocar;
  final Set<String> marcados;

  const _Grilla(this.libros, {required this.alTocar, this.marcados = const {}});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: libros.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
        childAspectRatio: 2 / 3,
      ),
      itemBuilder: (_, i) {
        final l = libros[i];
        return GestureDetector(
          onTap: () => alTocar(l),
          child: LayoutBuilder(
            builder: (_, c) => Tapa(
              l,
              ancho: c.maxWidth,
              marcada: marcados.contains(l.clave),
            ),
          ),
        );
      },
    );
  }
}

/// Grilla reutilizable para la pantalla de la otra persona.
class GrillaLibros extends StatelessWidget {
  final List<Libro> libros;
  final ValueChanged<Libro> alTocar;
  final Set<String> marcados;

  const GrillaLibros(this.libros,
      {super.key, required this.alTocar, this.marcados = const {}});

  @override
  Widget build(BuildContext context) =>
      _Grilla(libros, alTocar: alTocar, marcados: marcados);
}

class _Vacio extends StatelessWidget {
  final Estante estante;
  final VoidCallback alTocar;

  const _Vacio({required this.estante, required this.alTocar});

  String get _texto => switch (estante) {
        Estante.leyendo => 'No estás leyendo nada todavía.',
        Estante.leido => 'Todavía no marcaste ningún libro como leído.',
        Estante.pendiente => 'No tenés nada esperando.',
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
