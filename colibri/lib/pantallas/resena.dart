import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// Escribir la reseña de un libro.
///
/// Es pantalla completa y no un diálogo a propósito: una reseña puede ser
/// larga, y en un diálogo el teclado te tapa la mitad de lo que escribís.
class PantallaResena extends StatefulWidget {
  final Libro libro;
  const PantallaResena(this.libro, {super.key});

  @override
  State<PantallaResena> createState() => _PantallaResenaState();
}

class _PantallaResenaState extends State<PantallaResena> {
  late final TextEditingController _texto =
      TextEditingController(text: widget.libro.resena ?? '');
  late bool _conSpoilers = widget.libro.resenaConSpoilers;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final limpio = _texto.text.trim();
    widget.libro.resena = limpio.isEmpty ? null : limpio;
    widget.libro.resenaConSpoilers = limpio.isEmpty ? false : _conSpoilers;
    await biblioteca.actualizar();

    if (!mounted) return;
    Navigator.of(context).pop();
    mostrarAviso(
      context,
      limpio.isEmpty ? 'Reseña borrada' : 'Tu reseña quedó guardada',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Paleta.noche,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: const Text('Tu reseña',
            style: TextStyle(color: Paleta.luz, fontSize: 17)),
        actions: [
          TextButton(
            onPressed: _guardar,
            style: TextButton.styleFrom(foregroundColor: Paleta.lila),
            child: const Text('Guardar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.libro.titulo, style: Tipo.subtitulo),
              Text(widget.libro.autor, style: Tipo.meta),
              const SizedBox(height: 18),

              // La reseña se escribe con la letra de lectura, la misma con
              // la que después la va a leer otra persona.
              Expanded(
                child: TextField(
                  controller: _texto,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: Paleta.lila,
                  style: const TextStyle(
                    color: Paleta.luz,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '¿Qué te dejó?',
                    hintStyle: Tipo.meta.copyWith(fontSize: 16),
                    filled: true,
                    fillColor: Paleta.nocheAlta,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Paleta.linea),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Paleta.linea),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Paleta.lila),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _InterruptorSpoilers(
                valor: _conSpoilers,
                alCambiar: (v) => setState(() => _conSpoilers = v),
              ),
              const SizedBox(height: 14),
              BotonLleno('Guardar reseña', alTocar: _guardar),
            ],
          ),
        ),
      ),
    );
  }
}

/// El interruptor de spoilers, con la explicación al lado.
///
/// La marca la pone quien escribe, no un algoritmo: nadie sabe mejor que
/// vos si lo que contaste arruina el libro.
class _InterruptorSpoilers extends StatelessWidget {
  final bool valor;
  final ValueChanged<bool> alCambiar;

  const _InterruptorSpoilers({required this.valor, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => alCambiar(!valor),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          border: Border.all(color: valor ? Paleta.oro : Paleta.linea),
          color: valor ? Paleta.oroTenue : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tiene spoilers',
                    style: Tipo.cuerpo.copyWith(
                      fontWeight: FontWeight.w600,
                      color: valor ? Paleta.oro : Paleta.luz,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valor
                        ? 'Va a aparecer tapada. Quien no la quiera ver, no la ve.'
                        : 'Se va a mostrar directamente a cualquiera.',
                    style: Tipo.meta.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Switch(
              value: valor,
              onChanged: alCambiar,
              activeThumbColor: Paleta.oro,
              activeTrackColor: Paleta.oroBorde,
              inactiveThumbColor: Paleta.bruma,
              inactiveTrackColor: Paleta.linea,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cómo se ve una reseña ya escrita, dentro de la ficha del libro.
/// Si tiene spoilers, arranca tapada.
class ResenaPropia extends StatefulWidget {
  final Libro libro;
  const ResenaPropia(this.libro, {super.key});

  @override
  State<ResenaPropia> createState() => _ResenaPropiaState();
}

class _ResenaPropiaState extends State<ResenaPropia> {
  bool _destapada = false;

  void _editar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaResena(widget.libro)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.libro;

    if (!l.tieneResena) {
      return BotonContorno('Escribir mi reseña', alTocar: _editar);
    }

    final tapada = l.resenaConSpoilers && !_destapada;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Paleta.nocheAlta,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (l.resenaConSpoilers) ...[
            Row(
              children: [
                const Icon(Icons.visibility_off_outlined,
                    size: 14, color: Paleta.oro),
                const SizedBox(width: 6),
                Text('Con spoilers',
                    style: Tipo.meta
                        .copyWith(color: Paleta.oro, fontSize: 11.5)),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (tapada)
            InkWell(
              onTap: () => setState(() => _destapada = true),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  border: Border.all(color: Paleta.linea),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tocá para mostrarla',
                  textAlign: TextAlign.center,
                  style: Tipo.meta.copyWith(color: Paleta.lila),
                ),
              ),
            )
          else
            Text('“${l.resena}”', style: Tipo.lectura),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _editar,
                style: TextButton.styleFrom(
                  foregroundColor: Paleta.lila,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Editar', style: TextStyle(fontSize: 13)),
              ),
              if (l.resenaConSpoilers && _destapada) ...[
                const SizedBox(width: 18),
                TextButton(
                  onPressed: () => setState(() => _destapada = false),
                  style: TextButton.styleFrom(
                    foregroundColor: Paleta.bruma,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Tapar', style: TextStyle(fontSize: 13)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
