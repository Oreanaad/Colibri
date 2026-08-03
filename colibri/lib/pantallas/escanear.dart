import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api.dart';
import '../isbn.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'cargar_libro.dart';
import 'ediciones.dart';
import 'ficha.dart';

/// Cargar libros apuntando la cámara a la contratapa.
///
/// # Está armada para fallar bien
///
/// Antes de escribirla medimos cuántas ediciones con ISBN tiene Open
/// Library de los libros que lee esta comunidad. De los clásicos en
/// castellano tiene unas cincuenta; de la narrativa latinoamericana de
/// ahora tiene **una**, y de los éxitos traducidos del inglés, dos.
/// Traducido: escanear *Pedro Páramo* casi siempre anda y escanear *Las
/// malas* casi nunca.
///
/// Con esos números, una pantalla pensada para el acierto sería una
/// pantalla que decepciona. Entonces no encontrar el libro no es un error
/// acá: es uno de los resultados posibles, aparece en la lista como
/// cualquier otro y trae a mano el camino que sí funciona, que es buscarlo
/// por el título.
///
/// # Por qué no pregunta antes de agregar
///
/// El momento en que esto sirve de verdad es sentada en el piso frente al
/// estante, cargando treinta libros de una. Confirmar cada uno convierte
/// diez minutos en media hora. Así que agrega solo, lo muestra en la lista
/// y deja deshacer cada uno: es más rápido y no se pierde nada.
class PantallaEscanear extends StatefulWidget {
  const PantallaEscanear({super.key});

  @override
  State<PantallaEscanear> createState() => _PantallaEscanearState();
}

class _PantallaEscanearState extends State<PantallaEscanear> {
  final _control = MobileScannerController(
    // Solo los formatos que llevan los libros. Restringirlos hace que la
    // cámara no se distraiga con los QR de los carteles.
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.normal,
  );

  final _leidos = <_Leido>[];

  /// La cámara lee el mismo código muchas veces por segundo mientras lo
  /// tenés enfrente. Sin esto, un libro entraría cien veces.
  final _yaVistos = <String>{};

  bool _linterna = false;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _alLeer(BarcodeCapture captura) {
    for (final codigo in captura.barcodes) {
      final crudo = codigo.rawValue;
      if (crudo != null) _procesar(crudo);
    }
  }

  Future<void> _procesar(String crudo) async {
    final codigo = Isbn.limpiar(crudo);
    if (codigo.isEmpty || !_yaVistos.add(codigo)) return;

    HapticFeedback.selectionClick();

    final problema = Isbn.porQueNoSirve(codigo);
    if (problema != null) {
      setState(
        () =>
            _leidos.insert(0, _Leido(codigo, _Que.noEsLibro, porQue: problema)),
      );
      return;
    }

    final fila = _Leido(codigo, _Que.buscando);
    setState(() => _leidos.insert(0, fila));

    final encontrado = await Api.porIsbn(codigo);
    if (!mounted) return;

    if (encontrado == null) {
      setState(() => fila.que = _Que.noEncontrado);
      return;
    }

    final guardado = biblioteca.buscarPorClave(encontrado.clave);
    if (guardado != null) {
      setState(() {
        fila.libro = guardado;
        fila.que = _Que.yaEstaba;
      });
      return;
    }

    await biblioteca.agregar(encontrado);
    if (!mounted) return;
    setState(() {
      fila.libro = encontrado;
      fila.que = _Que.agregado;
    });
  }

  /// Elegir cuál de todas las tapas es la del libro que tenés en la mano.
  ///
  /// # Por qué está acá y no escondida en la ficha
  ///
  /// El código de barras identifica **una edición concreta**, pero los
  /// catálogos casi siempre contestan con la obra: escaneás tu edición
  /// argentina en castellano y te sale la tapa verde en inglés. El libro
  /// está bien, la portada no es la tuya.
  ///
  /// Y el único momento en que se puede arreglar sin esfuerzo es este, con
  /// el libro todavía en la mano. Después habría que acordarse.
  Future<void> _elegirEdicion(_Leido fila) async {
    final libro = fila.libro;
    if (libro == null) return;

    final cambiado = await Navigator.of(
      context,
    ).push<Libro>(MaterialPageRoute(builder: (_) => PantallaEdiciones(libro)));

    if (cambiado != null && mounted) setState(() => fila.libro = cambiado);
  }

  /// Mover un libro recién escaneado a otro estante.
  ///
  /// Escaneando de a treinta, todos caen en pendientes, y está bien como
  /// punto de partida. Pero la mitad de esa pila son libros que ya leíste
  /// —por eso los tenés en el estante— y corregirlo después, uno por uno,
  /// desde la biblioteca, es más trabajo que escanearlos.
  Future<void> _cambiarEstante(_Leido fila) async {
    final libro = fila.libro;
    if (libro == null) return;

    final cambio = await dondeVa(context, libro);
    if (!cambio || !mounted) return;

    // Si lo sacó de la biblioteca desde la hoja, la fila se va con él y el
    // código vuelve a quedar libre para escanearlo de nuevo.
    if (!biblioteca.tiene(libro)) {
      _yaVistos.remove(fila.codigo);
      setState(() => _leidos.remove(fila));
    } else {
      setState(() {});
    }
  }

  Future<void> _deshacer(_Leido fila) async {
    final libro = fila.libro;
    if (libro == null) return;

    await biblioteca.quitar(libro);
    _yaVistos.remove(fila.codigo); // que se pueda volver a escanear
    if (mounted) setState(() => _leidos.remove(fila));
  }

  Future<void> _alternarLinterna() async {
    try {
      await _control.toggleTorch();
      if (mounted) setState(() => _linterna = !_linterna);
    } catch (_) {
      // Muchas cámaras no tienen luz, y las del navegador casi ninguna.
      if (mounted) mostrarAviso(context, 'Esta cámara no tiene luz');
    }
  }

  @override
  Widget build(BuildContext context) {
    final agregados = _leidos.where((l) => l.que == _Que.agregado).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: Text(
          agregados == 0
              ? 'Escanear'
              : (agregados == 1
                    ? '1 libro sumado'
                    : '$agregados libros sumados'),
          style: const TextStyle(color: Paleta.luz, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: _alternarLinterna,
            icon: Icon(
              _linterna ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            ),
            color: _linterna ? Paleta.oro : Paleta.bruma,
            tooltip: 'Luz',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Columna(
          hijo: Column(
            children: [
              _Camara(control: _control, alLeer: _alLeer),
              Expanded(
                child: _leidos.isEmpty
                    ? const _ComoSeUsa()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        itemCount: _leidos.length,
                        separatorBuilder: (_, _) => const Divider(
                          color: Paleta.linea,
                          height: 20,
                          thickness: 1,
                        ),
                        itemBuilder: (_, i) => _Fila(
                          _leidos[i],
                          alDeshacer: () => _deshacer(_leidos[i]),
                          alElegirEdicion: () => _elegirEdicion(_leidos[i]),
                          alCambiarEstante: () => _cambiarEstante(_leidos[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El visor.
///
/// Se separa en su propio widget a propósito: así, cuando entra un libro y
/// la lista de abajo se redibuja, la cámara no se redibuja con ella.
class _Camara extends StatelessWidget {
  final MobileScannerController control;
  final void Function(BarcodeCapture) alLeer;

  const _Camara({required this.control, required this.alLeer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: control,
                onDetect: alLeer,
                errorBuilder: (context, error) => _CamaraCaida(error),
                fit: BoxFit.cover,
              ),
              // El marco. No recorta ni limita nada: le dice a la persona
              // dónde poner el código, que es lo único que hace falta para
              // que apunte bien.
              IgnorePointer(
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.78,
                    heightFactor: 0.42,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Paleta.lila, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cuando la cámara no arranca.
///
/// Cada motivo tiene su propia explicación y su propia salida. Un
/// «no se pudo abrir la cámara» genérico deja a la persona probando de
/// nuevo lo mismo, que es lo único que seguro no va a funcionar.
class _CamaraCaida extends StatelessWidget {
  final MobileScannerException error;
  const _CamaraCaida(this.error);

  @override
  Widget build(BuildContext context) {
    final (titulo, explicacion) = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => (
        'No me diste permiso para la cámara',
        'Se pide desde los ajustes del teléfono, en los permisos de esta '
            'app. Si estás en el navegador, aparece un cartel arriba de todo.',
      ),
      MobileScannerErrorCode.unsupported => (
        'Este aparato no puede escanear',
        'Buscá el libro por el título: se llega al mismo lado.',
      ),
      _ => (
        'No pude abrir la cámara',
        'Si estás probando desde el navegador, la cámara solo funciona en '
            'una dirección segura (https) o en la propia computadora. Desde '
            'el teléfono por wifi no va a andar hasta que la app esté '
            'publicada.',
      ),
    };

    return ColoredBox(
      color: Paleta.nocheAlta,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined, color: Paleta.bruma),
            const SizedBox(height: 12),
            Text(titulo, style: Tipo.cuerpo, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(explicacion, style: Tipo.meta, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ComoSeUsa extends StatelessWidget {
  const _ComoSeUsa();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 20),
      child: Column(
        children: [
          Text(
            'Apuntá al código de barras de la contratapa.',
            style: Tipo.cuerpo,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Los que encuentre se suman solos a pendientes, y podés seguir '
            'con el siguiente sin tocar nada.\n\nVarios no van a aparecer: el '
            'catálogo abierto tiene pocas ediciones latinoamericanas. Cuando '
            'pase, te lo digo y lo buscás por el título.',
            style: Tipo.meta,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum _Que { buscando, agregado, yaEstaba, noEncontrado, noEsLibro }

class _Leido {
  final String codigo;
  _Que que;
  Libro? libro;
  final String? porQue;

  _Leido(this.codigo, this.que, {this.porQue});
}

class _Fila extends StatelessWidget {
  final _Leido leido;
  final VoidCallback alDeshacer;
  final VoidCallback alElegirEdicion;
  final VoidCallback alCambiarEstante;

  const _Fila(
    this.leido, {
    required this.alDeshacer,
    required this.alElegirEdicion,
    required this.alCambiarEstante,
  });

  @override
  Widget build(BuildContext context) {
    return switch (leido.que) {
      _Que.buscando => _Aviso(
        icono: const SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 2, color: Paleta.lila),
        ),
        texto: 'Buscando ${leido.codigo}…',
      ),

      _Que.noEsLibro => _Aviso(
        icono: const Icon(Icons.block_rounded, size: 16, color: Paleta.bruma),
        texto: leido.porQue ?? '',
      ),

      _Que.noEncontrado => _NoEsta(leido.codigo),

      _ => FilaEscaneada(
        libro: leido.libro!,
        yaEstaba: leido.que == _Que.yaEstaba,
        alDeshacer: alDeshacer,
        alElegirEdicion: alElegirEdicion,
        alCambiarEstante: alCambiarEstante,
      ),
    };
  }
}

class _Aviso extends StatelessWidget {
  final Widget icono;
  final String texto;
  const _Aviso({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 16, child: Center(child: icono)),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: Tipo.meta)),
      ],
    );
  }
}

/// Un libro que el escáner encontró.
///
/// Es pública y no recibe el estado interno de la pantalla, sino el libro
/// pelado, para poder dibujarla en una prueba. La razón es concreta:
/// alguien dijo «no veo el más» y no había forma de contestar sin
/// adivinar, porque la fila no se podía renderizar sin cámara.
class FilaEscaneada extends StatelessWidget {
  final Libro libro;

  /// Si el libro ya estaba en la biblioteca antes de escanearlo. Cambia
  /// qué se dice y si se ofrece deshacer: sacar de la biblioteca un libro
  /// que ya tenías no es «deshacer», es borrar algo que era tuyo.
  final bool yaEstaba;

  final VoidCallback alDeshacer;
  final VoidCallback alElegirEdicion;
  final VoidCallback alCambiarEstante;

  const FilaEscaneada({
    super.key,
    required this.libro,
    required this.yaEstaba,
    required this.alDeshacer,
    required this.alElegirEdicion,
    required this.alCambiarEstante,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PantallaFicha(libro))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tapa(libro, ancho: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  libro.titulo,
                  style: Tipo.cuerpo.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  yaEstaba ? '${libro.autor} · ya lo tenías' : libro.autor,
                  style: Tipo.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // El estante y la edición, en el mismo renglón.
                //
                // Escaneando de a treinta todo cae en pendientes, y está
                // bien como punto de partida. Pero la mitad de esa pila
                // son libros que ya leíste —por eso están en el estante— y
                // corregirlo después uno por uno desde la biblioteca es
                // más trabajo que escanearlos.
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChipDeEstante(libro.estado, alTocar: alCambiarEstante),

                    // El ofrecimiento va siempre, encuentre lo que
                    // encuentre. Si solo apareciera cuando la tapa
                    // «parece de otro idioma», habría que adivinar cuándo,
                    // y adivinar mal es peor que preguntar siempre.
                    InkWell(
                      onTap: alElegirEdicion,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '¿No es tu tapa?',
                          style: Tipo.meta.copyWith(
                            color: Paleta.lila,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!yaEstaba)
            IconButton(
              onPressed: alDeshacer,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: Paleta.bruma,
              tooltip: 'No era este',
            ),
        ],
      ),
    );
  }
}

/// El código se leyó bien, el libro existe, pero el catálogo no lo tiene.
///
/// Va en oro y no en lila, y no es decoración: en esta app el oro es lo que
/// pide algo de tu parte. Y trae las dos salidas que sirven, porque
/// mandarla de vuelta a escanear el mismo código sería mentirle.
class _NoEsta extends StatelessWidget {
  final String codigo;
  const _NoEsta(this.codigo);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Paleta.oroTenue,
        border: Border.all(color: Paleta.oroBorde),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ese libro no está en el catálogo',
            style: Tipo.cuerpo.copyWith(
              color: Paleta.oroTexto,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Código $codigo. Pasa seguido con las ediciones de acá.',
            style: Tipo.meta,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: BotonContorno(
                  'Por el título',
                  alTocar: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BotonContorno(
                  'Cargarlo a mano',
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PantallaCargarLibro(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
