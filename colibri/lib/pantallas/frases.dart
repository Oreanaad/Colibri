import 'dart:async';
import 'package:flutter/material.dart';

import '../archivo/selector.dart';
import '../epub.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'compartir.dart';

/// Las dos formas de llegar a una frase.
///
/// No hay una sección para recorrer el libro entero, y es a propósito:
/// hay que escribir para encontrar. Así la app nunca muestra el libro
/// completo, que es la diferencia entre una herramienta para citar y un
/// lector de libros ajenos.
enum _Seccion { buscar, guardadas }

extension on _Seccion {
  String get nombre => switch (this) {
    _Seccion.buscar => 'Buscar',
    _Seccion.guardadas => 'Guardadas',
  };
}

/// Subrayar frases de un libro digital.
///
/// El EPUB se suma **una sola vez**: después queda guardado y se pueden
/// subrayar todas las frases que se quiera, sin volver a importar nada.
class PantallaFrases extends StatefulWidget {
  final Libro libro;
  const PantallaFrases(this.libro, {super.key});

  @override
  State<PantallaFrases> createState() => _PantallaFrasesState();
}

class _PantallaFrasesState extends State<PantallaFrases> {
  final _controlador = TextEditingController();
  Timer? _espera;

  Epub? _libroDigital;
  bool _cargando = true;
  bool _importando = false;
  List<Coincidencia> _resultados = const [];
  bool _busco = false;
  _Seccion _seccion = _Seccion.buscar;

  @override
  void initState() {
    super.initState();
    _cargarTexto();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _cargarTexto() async {
    final parrafos = await biblioteca.textoDe(widget.libro);
    if (!mounted) return;
    setState(() {
      _libroDigital = parrafos == null ? null : Epub(parrafos: parrafos);
      _cargando = false;
      if (_libroDigital != null && widget.libro.frases.isNotEmpty) {
        _seccion = _Seccion.guardadas;
      }
    });
  }

  /// Abre el archivo, le saca el texto y **descarta el archivo**.
  /// En ningún momento se copia ni se guarda el .epub.
  Future<void> _importar() async {
    setState(() => _importando = true);

    // Cada paso avisa qué falló. Un "no se pudo" a secas no le sirve a
    // nadie: ni a la lectora para arreglarlo, ni a nosotras para saber
    // qué pasó cuando alguien lo reporta.

    // --- 1. Elegir el archivo ---
    //
    // El selector vive en lib/archivo/: en la web es uno propio, porque
    // el de file_picker no anda en Safari de iPhone. Ahí está explicado.
    final ArchivoElegido? archivo;
    try {
      archivo = await elegirArchivo();
    } catch (e) {
      if (!mounted) return;
      setState(() => _importando = false);
      mostrarAviso(context, 'El teléfono no dejó abrir el explorador.');
      return;
    }

    if (archivo == null) {
      if (mounted) setState(() => _importando = false);
      return; // canceló, y eso no es un error
    }

    final bytes = archivo.bytes;
    if (bytes.isEmpty) {
      if (!mounted) return;
      setState(() => _importando = false);
      mostrarAviso(
        context,
        'El archivo llegó vacío. Si está en la nube, bajalo antes.',
      );
      return;
    }

    if (!archivo.esEpub) {
      if (!mounted) return;
      setState(() => _importando = false);
      mostrarAviso(
        context,
        archivo.esPdf
            ? 'Por ahora solo EPUB. El PDF viene más adelante.'
            : 'Ese archivo no es un EPUB.',
      );
      return;
    }

    // --- 2. Sacarle el texto ---
    final Epub? epub;
    try {
      epub = Epub.abrir(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importando = false);
      mostrarAviso(context, 'Ese EPUB tiene un formato que no supe leer.');
      return;
    }

    if (epub == null) {
      if (!mounted) return;
      setState(() => _importando = false);
      mostrarAviso(
        context,
        'Es un EPUB pero no le encontré texto. ¿Será uno escaneado?',
      );
      return;
    }

    // --- 3. Guardarlo ---
    //
    // Si no entra, el libro igual queda en memoria: se puede subrayar
    // ahora mismo, y recién al cerrar la app hay que volver a sumarlo.
    final guardado = await biblioteca.guardarTexto(widget.libro, epub.parrafos);

    if (!mounted) return;
    setState(() {
      _libroDigital = epub;
      _importando = false;
      _seccion = _Seccion.buscar;
    });

    mostrarAviso(
      context,
      guardado
          ? 'Listo: ${epub.parrafos.length} párrafos. El archivo no se guardó, '
                'y no hay que volver a sumarlo.'
          : 'Es muy grande para guardarlo en este teléfono. Podés subrayar '
                'ahora, pero al cerrar la app hay que sumarlo de nuevo.',
    );
  }

  void _alEscribir(String texto) {
    _espera?.cancel();
    if (texto.trim().length < 4) {
      setState(() {
        _resultados = const [];
        _busco = false;
      });
      return;
    }
    _espera = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _resultados = _libroDigital?.buscar(texto) ?? const [];
        _busco = true;
      });
    });
  }

  /// ¿Ya subrayó algo de este párrafo?
  ///
  /// No alcanza con comparar el párrafo entero: ahora una frase puede ser
  /// un tramo de adentro, así que preguntamos si el párrafo contiene lo
  /// guardado.
  bool _yaSubrayada(String parrafo) {
    final p = Epub.normalizar(parrafo);
    return widget.libro.frases.any((f) => p.contains(Epub.normalizar(f.texto)));
  }

  /// Guarda un pedazo de párrafo como frase.
  ///
  /// Recibe el texto ya recortado por la lectora: puede ser el párrafo
  /// entero o solo el tramo que marcó con el dedo.
  Future<void> subrayar(String texto, int indice) async {
    final total = _libroDigital?.parrafos.length ?? 1;
    final limpio = texto.trim();
    if (limpio.isEmpty) return;

    widget.libro.frases.insert(
      0,
      Frase(texto: limpio, posicion: total == 0 ? 0 : indice / total),
    );
    await biblioteca.actualizar();
    if (!mounted) return;
    setState(() {});
    mostrarAviso(context, 'Subrayada');
  }

  Future<void> _borrar(Frase f) async {
    setState(() => widget.libro.frases.remove(f));
    await biblioteca.actualizar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Paleta.noche,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: const Text(
          'Frases',
          style: TextStyle(color: Paleta.luz, fontSize: 17),
        ),
        actions: [
          if (_libroDigital != null)
            PopupMenuButton<String>(
              color: Paleta.nocheAlta,
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (_) async {
                await biblioteca.borrarTexto(widget.libro);
                if (!context.mounted) return;
                setState(() {
                  _libroDigital = null;
                  _seccion = _Seccion.buscar;
                });
                mostrarAviso(
                  context,
                  'Texto borrado. Tus frases guardadas siguen ahí.',
                );
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'borrar',
                  child: Text(
                    'Borrar el texto del libro',
                    style: TextStyle(color: Paleta.oro),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Paleta.lila),
                ),
              ),
            )
          : SafeArea(
              top: false,
              child: Columna(
                hijo: _libroDigital == null ? _sinLibro() : _conLibro(),
              ),
            ),
    );
  }

  // ---------- Todavía no importó nada ----------

  Widget _sinLibro() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (widget.libro.frases.isNotEmpty) ...[
          const Rotulo('Tus frases'),
          const SizedBox(height: 12),
          ...widget.libro.frases.map(
            (f) => _TarjetaFrase(
              f,
              libro: widget.libro,
              alBorrar: () => _borrar(f),
            ),
          ),
          const SizedBox(height: 28),
        ],
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Paleta.nocheAlta,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Lo leés en digital?', style: Tipo.subtitulo),
              const SizedBox(height: 8),
              Text(
                'Sumá tu EPUB una sola vez y después subrayá todas las frases '
                'que quieras: buscándolas por unas palabras, o recorriendo el '
                'libro y tocando el párrafo.',
                style: Tipo.meta,
              ),
              const SizedBox(height: 10),
              Text(
                'Si el libro lo tenés en Apple Books o en el Kindle, primero '
                'guardalo en Archivos: desde ahí sí se puede elegir.',
                style: Tipo.meta.copyWith(fontSize: 11.5, color: Paleta.lila),
              ),
              const SizedBox(height: 16),
              _importando
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Paleta.lila,
                            ),
                          ),
                        ),
                      ),
                    )
                  : BotonLleno('Elegir el archivo', alTocar: _importar),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _Promesa(),
      ],
    );
  }

  // ---------- Ya tiene el texto: no hay que volver a importarlo ----------

  Widget _conLibro() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: _Seccion.values.map((s) {
              final es = s == _seccion;
              final n = widget.libro.frases.length;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _seccion = s),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: es ? Paleta.lila : Paleta.linea,
                        ),
                        color: es ? const Color(0x22B9A6E6) : null,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        s == _Seccion.guardadas && n > 0
                            ? '${s.nombre} $n'
                            : s.nombre,
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
          ),
        ),
        Expanded(
          child: switch (_seccion) {
            _Seccion.buscar => _vistaBuscar(),
            _Seccion.guardadas => _vistaGuardadas(),
          },
        ),
      ],
    );
  }

  Widget _vistaBuscar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: TextField(
            controller: _controlador,
            onChanged: _alEscribir,
            style: const TextStyle(color: Paleta.luz, fontSize: 15),
            cursorColor: Paleta.lila,
            decoration: InputDecoration(
              hintText: 'Escribí lo que te acuerdes…',
              hintStyle: Tipo.meta,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Paleta.bruma,
                size: 20,
              ),
              isDense: true,
              filled: true,
              fillColor: Paleta.nocheAlta,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
          ),
        ),
        Expanded(child: _resultadosDeBusqueda()),
      ],
    );
  }

  Widget _resultadosDeBusqueda() {
    if (_busco && _resultados.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
        child: Text(
          'No aparece nada con esas palabras.\n\nProbá con menos, o fijate '
          'que sean tal cual están en el libro.',
          style: Tipo.meta,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_resultados.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 50, 32, 0),
        child: Text(
          'Escribí tres o cuatro palabras de una frase que te haya gustado. '
          'Sin acentos ni comas: no hace falta que sea exacto.',
          style: Tipo.meta,
          textAlign: TextAlign.center,
        ),
      );
    }

    final total = _libroDigital!.parrafos.length;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: _resultados.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final c = _resultados[i];
        return _Parrafo(
          // La clave hace que al cambiar la búsqueda cada tarjeta arranque
          // limpia y no se quede con la selección de la anterior.
          key: ValueKey('${c.indice}-${_controlador.text}'),
          texto: c.parrafo,
          buscado: _controlador.text,
          donde: _dondeCae(c.porcentaje(total)),
          yaHayAlgo: _yaSubrayada(c.parrafo),
          alSubrayar: (texto) => subrayar(texto, c.indice),
        );
      },
    );
  }

  Widget _vistaGuardadas() {
    if (widget.libro.frases.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 50, 32, 0),
        child: Text(
          'Todavía no subrayaste nada de este libro.',
          style: Tipo.meta,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Text(
          'Tocá una frase para compartirla.',
          style: Tipo.meta.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 14),
        ...widget.libro.frases.map(
          (f) =>
              _TarjetaFrase(f, libro: widget.libro, alBorrar: () => _borrar(f)),
        ),
      ],
    );
  }

  /// Dónde cae en el libro, dicho como lo diría una persona. Sin números
  /// de página, que cambian con cada edición.
  String _dondeCae(double p) {
    if (p < 0.15) return 'al principio';
    if (p < 0.45) return 'en el primer tercio';
    if (p < 0.7) return 'por la mitad';
    if (p < 0.9) return 'cerca del final';
    return 'en el final';
  }
}

/// Un párrafo encontrado, del que se subraya lo que la lectora quiera.
///
/// El texto es seleccionable: se puede marcar con el dedo de dónde a
/// dónde, y se guarda solo ese tramo. Si no marca nada, se guarda el
/// párrafo entero, que es lo que la mayoría va a querer.
class _Parrafo extends StatefulWidget {
  final String texto;
  final String buscado;
  final String donde;
  final bool yaHayAlgo;
  final ValueChanged<String> alSubrayar;

  const _Parrafo({
    super.key,
    required this.texto,
    required this.buscado,
    required this.donde,
    required this.yaHayAlgo,
    required this.alSubrayar,
  });

  @override
  State<_Parrafo> createState() => _ParrafoState();
}

class _ParrafoState extends State<_Parrafo> {
  /// Lo que la lectora marcó con el dedo, o null si no marcó nada.
  String? _elegido;

  void _alCambiarLaSeleccion(TextSelection s, SelectionChangedCause? _) {
    final hay = !s.isCollapsed && s.start >= 0 && s.end <= widget.texto.length;
    final tramo = hay ? widget.texto.substring(s.start, s.end).trim() : '';
    setState(() => _elegido = tramo.length >= 3 ? tramo : null);
  }

  @override
  Widget build(BuildContext context) {
    final parcial = _elegido != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Paleta.nocheAlta,
        border: Border.all(color: parcial ? Paleta.lila : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText.rich(
            _conResaltado(widget.texto, widget.buscado),
            onSelectionChanged: _alCambiarLaSeleccion,
            selectionColor: const Color(0x55B9A6E6),
            cursorColor: Paleta.lila,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                parcial ? Icons.content_cut_rounded : Icons.touch_app_outlined,
                size: 13,
                color: parcial ? Paleta.lila : Paleta.bruma,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  parcial
                      ? 'Vas a guardar ${_elegido!.length} caracteres'
                      : 'Marcá con el dedo de dónde a dónde, o guardalo entero',
                  style: Tipo.meta.copyWith(
                    fontSize: 11,
                    color: parcial ? Paleta.lila : Paleta.bruma,
                  ),
                ),
              ),
              Text(widget.donde, style: Tipo.meta.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: BotonContorno(
                  parcial ? 'Subrayar lo marcado' : 'Subrayar el párrafo',
                  alTocar: () => widget.alSubrayar(_elegido ?? widget.texto),
                ),
              ),
              if (widget.yaHayAlgo) ...[
                const SizedBox(width: 10),
                const Icon(Icons.bookmark_rounded, size: 17, color: Paleta.oro),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// El pedazo buscado va en lila, para encontrarlo de un vistazo.
  TextSpan _conResaltado(String texto, String buscado) {
    final aguja = Epub.normalizar(buscado);
    final donde = Epub.normalizar(texto).indexOf(aguja);

    if (donde == -1 || aguja.isEmpty) {
      return TextSpan(text: texto, style: Tipo.lectura);
    }

    // La normalización no cambia el largo del texto (solo reemplaza
    // letras por letras), así que las posiciones siguen sirviendo.
    final inicio = donde.clamp(0, texto.length);
    final fin = (donde + aguja.length).clamp(0, texto.length);

    return TextSpan(
      style: Tipo.lectura,
      children: [
        TextSpan(text: texto.substring(0, inicio)),
        TextSpan(
          text: texto.substring(inicio, fin),
          style: const TextStyle(
            color: Paleta.lila,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(text: texto.substring(fin)),
      ],
    );
  }
}

class _TarjetaFrase extends StatelessWidget {
  final Frase frase;
  final Libro libro;
  final VoidCallback alBorrar;

  const _TarjetaFrase(
    this.frase, {
    required this.libro,
    required this.alBorrar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        color: Paleta.oroTenue,
        border: Border(left: BorderSide(color: Paleta.oro, width: 3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PantallaCompartir(libro, frase)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('“${frase.texto}”', style: Tipo.lectura),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      fechaCorta(frase.guardada),
                      style: Tipo.meta.copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.ios_share_rounded,
                      size: 14,
                      color: Paleta.bruma,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: alBorrar,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: Paleta.bruma,
                      tooltip: 'Borrar la frase',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La promesa, escrita donde la persona la ve antes de decidir.
class _Promesa extends StatelessWidget {
  const _Promesa();

  @override
  Widget build(BuildContext context) {
    const puntos = [
      'El archivo no se guarda: se abre una vez, se lee, y se descarta.',
      'El texto queda solo en tu teléfono. No se sube a ningún lado.',
      'Nadie más puede ver ni bajar tu libro desde acá.',
      'Lo único que puede volverse público es la frase que elijas vos.',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Paleta.linea),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: Paleta.lila,
              ),
              const SizedBox(width: 8),
              Text(
                'Qué pasa con tu archivo',
                style: Tipo.cuerpo.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final p in puntos)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('— ', style: Tipo.meta.copyWith(color: Paleta.lila)),
                  Expanded(child: Text(p, style: Tipo.meta)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
