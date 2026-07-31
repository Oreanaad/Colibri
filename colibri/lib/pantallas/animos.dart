import 'package:flutter/material.dart';

import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// Elegir cómo te dejó un libro.
///
/// Aparece sola al marcar un libro como leído, que es el único momento en
/// que el libro está fresco. Si la función viviera escondida en la ficha,
/// la usaría una de cada veinte personas, y con eso no se junta nada.
///
/// Se puede saltear siempre: nunca bloquea nada.
Future<void> preguntarComoTeDejo(BuildContext context, Libro libro) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Paleta.nocheAlta,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _HojaDeAnimos(libro),
  );
}

class _HojaDeAnimos extends StatefulWidget {
  final Libro libro;
  const _HojaDeAnimos(this.libro);

  @override
  State<_HojaDeAnimos> createState() => _HojaDeAnimosState();
}

class _HojaDeAnimosState extends State<_HojaDeAnimos> {
  late final _elegidas = <String>{...widget.libro.animos};

  Future<void> _guardar() async {
    widget.libro.animos
      ..clear()
      ..addAll(_elegidas);
    await biblioteca.actualizar();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Columna(
          hijo: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Paleta.linea,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Rotulo('Terminaste'),
                const SizedBox(height: 6),
                Text(widget.libro.titulo, style: Tipo.titulo),
                const SizedBox(height: 10),
                Text(
                  '¿Cómo te dejó? Elegí hasta ${Animos.maximo}.',
                  style: Tipo.meta,
                ),
                const SizedBox(height: 16),

                ChipsDeAnimo(
                  elegidas: _elegidas,
                  alAlternar: (a) => setState(() {
                    if (!_elegidas.remove(a) &&
                        _elegidas.length < Animos.maximo) {
                      _elegidas.add(a);
                    }
                  }),
                ),

                const SizedBox(height: 14),
                Text(
                  _elegidas.isEmpty
                      ? 'Podés saltearlo, pero es el único momento en que el '
                            'libro está fresco.'
                      : 'Elegiste ${_elegidas.length} de ${Animos.maximo}. '
                            'Tocá una para cambiarla.',
                  style: Tipo.meta.copyWith(fontSize: 11.5),
                ),
                const SizedBox(height: 18),
                BotonLleno(
                  _elegidas.isEmpty ? 'Ahora no' : 'Listo',
                  alTocar: _guardar,
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => _proponer(context),
                    style: TextButton.styleFrom(foregroundColor: Paleta.bruma),
                    child: const Text(
                      '¿Falta una? Contame cuál',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Los chips de las doce etiquetas.
///
/// Sin números al lado, y eso es a propósito: **primero elegís, después
/// ves lo que dijeron los demás.** Si vieras que trescientas personas
/// pusieron «me destruyó» antes de elegir, ibas a poner «me destruyó»
/// aunque a vos te haya dado risa. Lo que se contamina no se limpia
/// después.
class ChipsDeAnimo extends StatelessWidget {
  final Set<String> elegidas;
  final ValueChanged<String> alAlternar;

  const ChipsDeAnimo({
    super.key,
    required this.elegidas,
    required this.alAlternar,
  });

  @override
  Widget build(BuildContext context) {
    final lleno = elegidas.length >= Animos.maximo;

    return Wrap(
      spacing: 7,
      runSpacing: 8,
      children: Animos.todas.map((a) {
        final puesta = elegidas.contains(a);
        // Cuando ya elegiste tres, las demás se apagan en vez de
        // desaparecer: se ve que están y por qué no se pueden tocar.
        final apagada = lleno && !puesta;

        return InkWell(
          onTap: apagada ? null : () => alAlternar(a),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: puesta ? const Color(0x22B9A6E6) : null,
              border: Border.all(
                color: puesta
                    ? Paleta.lila
                    : (apagada ? const Color(0x22332A57) : Paleta.linea),
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              a,
              style: TextStyle(
                fontSize: 13,
                color: puesta
                    ? Paleta.lila
                    : (apagada ? const Color(0x55B9A6E6) : Paleta.bruma),
                fontWeight: puesta ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Recoge las etiquetas que la gente pide.
///
/// No se publican: quedan guardadas para leerlas. Cuando una misma
/// propuesta aparezca muchas veces, se suma a la lista oficial. Así las
/// palabras terminan siendo de la comunidad, pero entran de a una y
/// cuando ya hay gente que las usa.
Future<void> _proponer(BuildContext context) async {
  final controlador = TextEditingController();

  final propuesta = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Paleta.nocheAlta,
      title: Text('¿Qué etiqueta falta?', style: Tipo.subtitulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Con tus palabras. Si la piden muchas personas, se suma a la '
            'lista para todas.',
            style: Tipo.meta,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controlador,
            autofocus: true,
            style: const TextStyle(color: Paleta.luz),
            cursorColor: Paleta.lila,
            decoration: const InputDecoration(
              hintText: 'me dejó vacía',
              hintStyle: TextStyle(color: Paleta.bruma),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Paleta.linea),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Paleta.lila),
              ),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: Paleta.bruma),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controlador.text),
          style: TextButton.styleFrom(foregroundColor: Paleta.lila),
          child: const Text('Mandar'),
        ),
      ],
    ),
  );

  controlador.dispose();
  if (propuesta == null || propuesta.trim().isEmpty) return;

  await biblioteca.proponerAnimo(propuesta);
  if (context.mounted) {
    mostrarAviso(context, 'Anotada. Gracias.');
  }
}
