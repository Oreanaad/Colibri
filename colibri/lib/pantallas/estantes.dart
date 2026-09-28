import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import '../archivo/selector.dart';
import '../foto.dart';
import '../lomo.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import '../vitrina.dart';
import 'ficha.dart';
import 'vitrina.dart';

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

          // Y que se pueden armar como un mueble.
          //
          // Sin esto, el armador de estantes era invisible: vive adentro de
          // un estante, así que quien no tiene ninguno no tiene forma de
          // enterarse de que existe. Una pantalla vacía es el único lugar
          // donde se puede contar para qué sirve llenarla.
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: Paleta.nocheAlta,
              border: Border.all(color: Paleta.linea),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  'Y después lo armás como un mueble',
                  style: Tipo.cuerpo.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cuántas repisas, de qué color el fondo, y qué le ponés '
                  'encima: luces, una planta, un gato dormido. Cada libro va '
                  'de lomo o de tapa, como en un estante de verdad.',
                  style: Tipo.meta,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                BotonLleno(
                  'Armar mi primer estante',
                  alTocar: () => pedirNombreDeEstante(context),
                ),
              ],
            ),
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
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PantallaEstante(nombre))),
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
                        for (var i = libros.length.clamp(0, 3) - 1; i >= 0; i--)
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

  /// Cómo está armado este estante, y si se está armando ahora.
  late Vitrina _vitrina = vitrinas.de(_nombre);
  bool _armando = false;

  @override
  void initState() {
    super.initState();
    // Lo automático: sacarle a cada tapa su color para pintarle el lomo.
    // Va acá y no en el widget del mueble porque acá se sabe qué libros
    // son, y porque una sola vez al entrar alcanza.
    _mirarLasTapas();
  }

  Future<void> _mirarLasTapas() async {
    final aprendio = await lomos.mirarLasTapas(biblioteca.enEstante(_nombre));
    if (aprendio && mounted) setState(() {});
  }

  Future<void> _guardarVitrina(Vitrina v) async {
    setState(() => _vitrina = v);
    await vitrinas.guardar(_nombre, v);
  }

  /// Qué hacer con un libro que se tocó mientras se arma.
  ///
  /// Antes el toque alternaba lomo y tapa, y alcanzaba porque eran dos.
  /// Con la foto son tres, y un toque que rota entre tres opciones obliga
  /// a tocar hasta tres veces sin saber qué viene.
  Future<void> _queHacerCon(Libro libro) => elegirComoSeVe(
    context,
    libro: libro,
    deTapa: _vitrina.deTapa.contains(libro.clave),
    alDarVuelta: () => _guardarVitrina(_vitrina.alternarPostura(libro.clave)),
    alSacarFoto: () => _fotoDelLomo(libro),
    alQuitarFoto: () async {
      await lomos.quitarFoto(libro.clave);
      if (mounted) setState(() {});
    },
  );

  /// La foto del canto del libro que tenés en la mano.
  ///
  /// # Por qué no se puede buscar sola
  ///
  /// Ningún catálogo publica fotos de lomos. Está comprobado contra Open
  /// Library, que es el que usa la app: `…/b/id/8231856-spine` contesta
  /// 404, igual que `-back`. Solo existe la tapa. Así que el lomo de
  /// verdad, con su tipografía y su editorial, solo puede entrar por acá.
  ///
  /// Lo que **sí** hace sola la app es sacarle el color a la tapa y
  /// pintarle el lomo con eso, que es lo más parecido sin la foto.
  Future<void> _fotoDelLomo(Libro libro) async {
    try {
      final archivo = await elegirArchivo(acepta: 'image/*');
      if (archivo == null) return;

      // En otro hilo: una foto de teléfono son doce megapíxeles, y
      // achicarla en el de la pantalla la congelaba un par de segundos.
      final achicada = await compute(FotoDeLomo.preparar, archivo.bytes);
      if (!mounted) return;

      if (achicada == null) {
        avisar(
          ScaffoldMessenger.of(context),
          'Ese archivo no es una foto. Probá con otra.',
        );
        return;
      }

      await lomos.guardarFoto(libro.clave, base64Encode(achicada));
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        avisar(ScaffoldMessenger.of(context), 'No se pudo abrir la foto.');
      }
    }
  }

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
    // La decoración se va con el estante: dejarla huérfana haría que un
    // estante nuevo con el mismo nombre apareciera ya decorado por otro.
    await vitrinas.olvidar(_nombre);
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
            backgroundColor: Colors.transparent,
            foregroundColor: Paleta.lila,
            elevation: 0,
            title: Text(
              _nombre,
              style: const TextStyle(color: Paleta.luz, fontSize: 17),
            ),
            actions: [
              if (libros.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() => _armando = !_armando),
                  icon: Icon(
                    _armando ? Icons.check_rounded : Icons.tune_rounded,
                  ),
                  color: _armando ? Paleta.oro : Paleta.lila,
                  tooltip: _armando ? 'Listo' : 'Armar el estante',
                ),
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
                      await vitrinas.renombrar(_nombre, nuevo);
                      if (!mounted) return;
                      setState(() => _nombre = nuevo);
                    }
                  } else {
                    await _confirmarBorrado();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'renombrar',
                    child: Text(
                      'Cambiarle el nombre',
                      style: TextStyle(color: Paleta.luz),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'borrar',
                    child: Text(
                      'Borrar el estante',
                      style: TextStyle(color: Paleta.oro),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Columna(
                  hijo: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      Text(
                        libros.length == 1
                            ? '1 libro'
                            : '${libros.length} libros',
                        style: Tipo.meta,
                      ),
                      const SizedBox(height: 16),
                      if (libros.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            'Este estante está vacío.\n\nAbrí cualquier libro '
                            'de tu biblioteca y sumalo desde ahí.',
                            style: Tipo.meta,
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        MuebleDeEstante(
                          libros: libros,
                          vitrina: _vitrina,
                          alTocar: (l) => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PantallaFicha(l)),
                          ),
                          // Mientras se arma, tocar un libro abre qué hacer
                          // con él en vez de abrirlo: es el momento de
                          // acomodar, no el de leer.
                          alCambiarPostura: _armando ? _queHacerCon : null,
                        ),
                    ],
                  ),
                ),
              ),

              if (_armando)
                Columna(
                  hijo: HojaDeArmar(
                    vitrina: _vitrina,
                    alCambiar: _guardarVitrina,
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
