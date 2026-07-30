import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// Ficha de un libro. Acá viven las dos funciones que diferencian a Colibrí:
/// las reseñas por capas de spoiler y la frase más subrayada.
class PantallaFicha extends StatefulWidget {
  final Libro libro;
  const PantallaFicha(this.libro, {super.key});

  @override
  State<PantallaFicha> createState() => _PantallaFichaState();
}

class _PantallaFichaState extends State<PantallaFicha> {
  late Libro l;

  @override
  void initState() {
    super.initState();
    l = biblioteca.buscarPorClave(widget.libro.clave) ?? widget.libro;
    l.paginas ??= 320; // la demo necesita un total para mostrar el avance
  }

  double get _avance {
    final total = l.paginas ?? 0;
    return total == 0 ? 0 : (l.paginaActual / total).clamp(0.0, 1.0);
  }

  Future<void> _guardar() async {
    if (biblioteca.tiene(l)) await biblioteca.actualizar();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: biblioteca,
      builder: (context, _) {
        final enBiblioteca = biblioteca.tiene(l);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Paleta.noche,
            foregroundColor: Paleta.lila,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tapa(l, ancho: 108, tamano: 'L'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.titulo, style: Tipo.titulo),
                        const SizedBox(height: 6),
                        Text(
                          [
                            l.autor,
                            if (l.editorial != null) l.editorial,
                            if (l.anio != null) '${l.anio}',
                          ].join(' · '),
                          style: Tipo.meta,
                        ),
                        const SizedBox(height: 12),
                        Estrellas(
                          l.puntaje,
                          tamano: 22,
                          alTocar: (p) {
                            l.puntaje = p;
                            _guardar();
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.puntaje == 0
                              ? 'tocá para puntuar'
                              : '${l.puntaje} de 5',
                          style: Tipo.meta.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (enBiblioteca) ...[
                _SelectorEstante(
                  l.estante,
                  alCambiar: (e) {
                    l.estante = e;
                    _guardar();
                  },
                ),
                const SizedBox(height: 20),
                if (l.estante == Estante.leyendo) _avanceLectura(),
                const SizedBox(height: 8),
                BotonContorno(
                  'Sacar de mi biblioteca',
                  alTocar: () async {
                    await biblioteca.quitar(l);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ] else
                BotonLleno(
                  'Agregar a mi biblioteca',
                  alTocar: () => biblioteca.agregar(l),
                ),

              const SizedBox(height: 32),
              const Rotulo('Cómo te deja'),
              const SizedBox(height: 10),
              const _Animos(),

              const SizedBox(height: 30),
              const Rotulo('Reseñas de la comunidad'),
              const SizedBox(height: 12),
              _Capas(avance: _avance, leyendo: l.estante == Estante.leyendo),

              const SizedBox(height: 30),
              const Rotulo('La frase más subrayada'),
              const SizedBox(height: 12),
              const _FraseSubrayada(),
            ],
          ),
        );
      },
    );
  }

  Widget _avanceLectura() {
    final total = l.paginas ?? 320;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Rotulo('Por dónde vas'),
            Text('página ${l.paginaActual} de $total',
                style: Tipo.meta.copyWith(fontSize: 11)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Paleta.lila,
            inactiveTrackColor: Paleta.linea,
            thumbColor: Paleta.lila,
            overlayColor: const Color(0x22B9A6E6),
            trackHeight: 4,
          ),
          child: Slider(
            value: l.paginaActual.toDouble().clamp(0, total.toDouble()),
            max: total.toDouble(),
            onChanged: (v) {
              setState(() => l.paginaActual = v.round());
            },
            onChangeEnd: (_) => _guardar(),
          ),
        ),
        Text(
          'Moviendo esto se abren las reseñas de más abajo.',
          style: Tipo.meta.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _SelectorEstante extends StatelessWidget {
  final Estante activo;
  final ValueChanged<Estante> alCambiar;

  const _SelectorEstante(this.activo, {required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: Estante.values.map((e) {
        final es = e == activo;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => alCambiar(e),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border.all(color: es ? Paleta.lila : Paleta.linea),
                  color: es ? const Color(0x22B9A6E6) : null,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  e.nombre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: es ? Paleta.lila : Paleta.bruma,
                    fontWeight: es ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Animos extends StatelessWidget {
  const _Animos();

  static const _etiquetas = [
    ('me destruyó', 312),
    ('no pude parar', 208),
    ('oscuro', 190),
    ('largo pero vale', 96),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: _etiquetas
          .map((e) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Paleta.linea),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text('${e.$1} · ${e.$2}',
                    style: Tipo.meta.copyWith(fontSize: 11.5)),
              ))
          .toList(),
    );
  }
}

/// Reseñas por capas. Solo se ve el tramo que corresponde a por dónde va
/// quien lee, y lo cerrado se explica en vez de esconderse.
class _Capas extends StatefulWidget {
  final double avance;
  final bool leyendo;

  const _Capas({required this.avance, required this.leyendo});

  @override
  State<_Capas> createState() => _CapasState();
}

class _CapasState extends State<_Capas> {
  int _elegida = 0;

  static const _nombres = ['Sin spoilers', 'Hasta la mitad', 'El final'];
  static const _umbrales = [0.0, 0.5, 0.95];
  static const _textos = [
    (
      'Empieza como una novela de terror y termina siendo sobre un padre y un '
          'hijo. Aguantá las primeras cien páginas, que después no la soltás.',
      'Caro Vidal',
      5,
    ),
    (
      'La mitad del medio es la mejor: cuando aparece la casa, el libro cambia '
          'de género y se vuelve otra cosa. Ahí entendí de qué iba todo.',
      'Juli Peralta',
      4,
    ),
    (
      'El final me dejó dos días sin poder empezar otro libro. No es un cierre, '
          'es una despedida, y por eso duele tanto.',
      'Mara Giménez',
      5,
    ),
  ];

  bool _abierta(int i) => widget.avance >= _umbrales[i];

  @override
  Widget build(BuildContext context) {
    if (!_abierta(_elegida)) _elegida = 0;
    final texto = _textos[_elegida];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final abierta = _abierta(i);
            final es = i == _elegida;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: abierta ? () => setState(() => _elegida = i) : null,
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: es ? Paleta.lila : null,
                      border: Border.all(
                          color: es ? Paleta.lila : Paleta.linea),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!abierta) ...[
                          const Icon(Icons.lock_outline_rounded,
                              size: 11, color: Paleta.bruma),
                          const SizedBox(width: 3),
                        ],
                        Flexible(
                          child: Text(
                            _nombres[i],
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: es
                                  ? Paleta.noche
                                  : (abierta ? Paleta.luz : Paleta.bruma),
                              fontWeight:
                                  es ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        Text('“${texto.$1}”', style: Tipo.lectura),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('${texto.$2}  ', style: Tipo.meta.copyWith(fontSize: 11.5)),
            Estrellas(texto.$3, tamano: 12),
          ],
        ),
        if (!_abierta(2)) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Paleta.linea),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 13, color: Paleta.bruma),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.leyendo
                        ? 'Los tramos cerrados se abren solos cuando llegues. '
                            'Moviendo la barra de arriba lo podés probar.'
                        : 'Poné el libro en “Leyendo” y anotá por dónde vas: '
                            'los otros tramos se abren solos.',
                    style: Tipo.meta.copyWith(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// La frase va en oro porque es un encuentro: otras personas marcaron
/// exactamente lo mismo que vos ibas a marcar.
class _FraseSubrayada extends StatelessWidget {
  const _FraseSubrayada();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: Paleta.oroTenue,
        border: Border(left: BorderSide(color: Paleta.oro, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“La oscuridad no se hereda: se elige, todos los días, en cosas '
            'muy pequeñas.”',
            style: Tipo.lectura,
          ),
          const SizedBox(height: 8),
          Text('subrayada por 43 personas',
              style: Tipo.meta.copyWith(color: Paleta.oro, fontSize: 11.5)),
        ],
      ),
    );
  }
}
