import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'ficha.dart';

/// Pide un nombre de estante. Devuelve el nombre creado, o null si la
/// persona canceló o el nombre ya existía.
///
/// Vive suelta y no dentro de una pantalla porque se usa desde dos
/// lugares: la lista de estantes y la ficha de un libro.
Future<String?> pedirNombreDeEstante(
  BuildContext context, {
  String? nombreActual,
}) async {
  final controlador = TextEditingController(text: nombreActual ?? '');
  final esNuevo = nombreActual == null;

  final nombre = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Paleta.nocheAlta,
      title: Text(
        esNuevo ? 'Nuevo estante' : 'Cambiarle el nombre',
        style: Tipo.subtitulo,
      ),
      content: TextField(
        controller: controlador,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(color: Paleta.luz),
        cursorColor: Paleta.lila,
        decoration: const InputDecoration(
          hintText: 'los que me rompieron',
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: Paleta.bruma),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controlador.text),
          style: TextButton.styleFrom(foregroundColor: Paleta.lila),
          child: Text(esNuevo ? 'Crear' : 'Guardar'),
        ),
      ],
    ),
  );

  controlador.dispose();
  if (nombre == null) return null;

  if (esNuevo) return biblioteca.crearEstante(nombre);
  await biblioteca.renombrarEstante(nombreActual, nombre);
  return nombre.trim();
}

/// La solapa "Estantes": la lista de los que armaste vos.
class VistaEstantes extends StatelessWidget {
  const VistaEstantes({super.key});

  @override
  Widget build(BuildContext context) {
    final estantes = biblioteca.estantes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        if (estantes.isEmpty)
          const _SinEstantes()
        else
          ...estantes.map((nombre) => _FilaEstante(nombre)),
        const SizedBox(height: 18),
        BotonContorno(
          'Crear un estante',
          alTocar: () => pedirNombreDeEstante(context),
        ),
      ],
    );
  }
}

class _SinEstantes extends StatelessWidget {
  const _SinEstantes();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 8),
      child: Column(
        children: [
          Text(
            'Todavía no armaste ningún estante.',
            style: Tipo.cuerpo,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Son tuyos y los inventás vos: «los que me rompieron», '
            '«terror latinoamericano», «para prestarle a mi vieja». '
            'Un libro puede estar en varios a la vez.',
            style: Tipo.meta,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FilaEstante extends StatelessWidget {
  final String nombre;
  const _FilaEstante(this.nombre);

  @override
  Widget build(BuildContext context) {
    final libros = biblioteca.enEstante(nombre);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PantallaEstante(nombre)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Tres tapas asomando, como los lomos de un estante de verdad.
            SizedBox(
              width: 74,
              height: 66,
              child: libros.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Paleta.linea),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                  : Stack(
                      children: [
                        for (var i = libros.length.clamp(0, 3) - 1;
                            i >= 0;
                            i--)
                          Positioned(
                            left: i * 20.0,
                            child: Tapa(libros[i], ancho: 44),
                          ),
                      ],
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: Tipo.subtitulo),
                  const SizedBox(height: 3),
                  Text(
                    libros.length == 1 ? '1 libro' : '${libros.length} libros',
                    style: Tipo.meta,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Paleta.bruma),
          ],
        ),
      ),
    );
  }
}

/// Los libros de un estante propio.
class PantallaEstante extends StatefulWidget {
  final String nombre;
  const PantallaEstante(this.nombre, {super.key});

  @override
  State<PantallaEstante> createState() => _PantallaEstanteState();
}

class _PantallaEstanteState extends State<PantallaEstante> {
  late String _nombre = widget.nombre;

  Future<void> _confirmarBorrado() async {
    final borrar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Paleta.nocheAlta,
        title: Text('¿Borrar «$_nombre»?', style: Tipo.subtitulo),
        content: Text(
          'Se borra el estante, no los libros: siguen en tu biblioteca.',
          style: Tipo.meta,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Paleta.bruma),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Paleta.oro),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (borrar != true) return;
    await biblioteca.borrarEstante(_nombre);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: biblioteca,
      builder: (context, _) {
        final libros = biblioteca.enEstante(_nombre);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Paleta.noche,
            foregroundColor: Paleta.lila,
            elevation: 0,
            title: Text(_nombre,
                style: const TextStyle(color: Paleta.luz, fontSize: 17)),
            actions: [
              PopupMenuButton<String>(
                color: Paleta.nocheAlta,
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (opcion) async {
                  if (opcion == 'renombrar') {
                    final nuevo = await pedirNombreDeEstante(
                      context,
                      nombreActual: _nombre,
                    );
                    if (nuevo != null && mounted) {
                      setState(() => _nombre = nuevo);
                    }
                  } else {
                    await _confirmarBorrado();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'renombrar',
                    child: Text('Cambiarle el nombre',
                        style: TextStyle(color: Paleta.luz)),
                  ),
                  const PopupMenuItem(
                    value: 'borrar',
                    child: Text('Borrar el estante',
                        style: TextStyle(color: Paleta.oro)),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                libros.length == 1 ? '1 libro' : '${libros.length} libros',
                style: Tipo.meta,
              ),
              const SizedBox(height: 16),
              if (libros.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    'Este estante está vacío.\n\nAbrí cualquier libro de tu '
                    'biblioteca y sumalo desde ahí.',
                    style: Tipo.meta,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                GrillaLibros(
                  libros,
                  alTocar: (l) => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PantallaFicha(l)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Los chips de la ficha de un libro: en qué estantes está y cuáles no.
class ChipsDeEstantes extends StatelessWidget {
  final Libro libro;
  const ChipsDeEstantes(this.libro, {super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final nombre in biblioteca.estantes)
          _Chip(
            texto: nombre,
            activo: libro.estantes.contains(nombre),
            alTocar: () => biblioteca.alternarEstante(libro, nombre),
          ),
        _Chip(
          texto: '+ Nuevo estante',
          activo: false,
          punteado: true,
          alTocar: () async {
            final nombre = await pedirNombreDeEstante(context);
            if (nombre != null) {
              await biblioteca.alternarEstante(libro, nombre);
            }
          },
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final bool activo;
  final bool punteado;
  final VoidCallback alTocar;

  const _Chip({
    required this.texto,
    required this.activo,
    required this.alTocar,
    this.punteado = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? const Color(0x22B9A6E6) : null,
          border: Border.all(
            color: activo
                ? Paleta.lila
                : (punteado ? Paleta.bruma : Paleta.linea),
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activo) ...[
              const Icon(Icons.check_rounded, size: 13, color: Paleta.lila),
              const SizedBox(width: 5),
            ],
            Text(
              texto,
              style: TextStyle(
                fontSize: 12.5,
                color: activo ? Paleta.lila : Paleta.bruma,
                fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
