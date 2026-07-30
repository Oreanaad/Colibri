import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../epub.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'compartir.dart';

/// Buscar una frase adentro del libro digital y guardarla.
///
/// La lectora se acuerda de tres o cuatro palabras; escribe eso y la app
/// le devuelve el párrafo entero. Es lo mismo que tipear la frase a mano
/// mirando el libro, pero sin el trabajo de tipearla.
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
      _libroDigital =
          parrafos == null ? null : Epub(parrafos: parrafos);
      _cargando = false;
    });
  }

  /// Abre el archivo, le saca el texto y **descarta el archivo**.
  /// En ningún momento se copia ni se guarda el .epub.
  Future<void> _importar() async {
    setState(() => _importando = true);

    try {
      final elegido = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
        withData: true, // los bytes, en memoria y nada más
      );

      final bytes = elegido?.files.single.bytes;
      if (bytes == null) {
        if (mounted) setState(() => _importando = false);
        return;
      }

      final epub = Epub.abrir(bytes);
      if (epub == null) {
        if (!mounted) return;
        setState(() => _importando = false);
        mostrarAviso(context,
            'No se pudo leer ese archivo. ¿Seguro que es un EPUB con texto?');
        return;
      }

      await biblioteca.guardarTexto(widget.libro, epub.parrafos);
      if (!mounted) return;
      setState(() {
        _libroDigital = epub;
        _importando = false;
      });
      mostrarAviso(context,
          'Listo: ${epub.parrafos.length} párrafos. El archivo no se guardó.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _importando = false);
      mostrarAviso(context, 'No se pudo abrir el archivo.');
    }
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

  Future<void> _guardarFrase(Coincidencia c) async {
    widget.libro.frases.insert(
      0,
      Frase(
        texto: c.parrafo,
        posicion: c.porcentaje(_libroDigital!.parrafos.length),
      ),
    );
    await biblioteca.actualizar();
    if (!mounted) return;

    _controlador.clear();
    setState(() {
      _resultados = const [];
      _busco = false;
    });
    mostrarAviso(context, 'Frase guardada');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Paleta.noche,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: const Text('Frases',
            style: TextStyle(color: Paleta.luz, fontSize: 17)),
        actions: [
          if (_libroDigital != null)
            PopupMenuButton<String>(
              color: Paleta.nocheAlta,
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (_) async {
                await biblioteca.borrarTexto(widget.libro);
                if (!context.mounted) return;
                setState(() => _libroDigital = null);
                mostrarAviso(context,
                    'Texto borrado. Tus frases guardadas siguen ahí.');
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'borrar',
                  child: Text('Borrar el texto del libro',
                      style: TextStyle(color: Paleta.oro)),
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
              child: _libroDigital == null ? _sinLibro() : _conLibro(),
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
          ...widget.libro.frases.map((f) => _TarjetaFrase(
                f,
                libro: widget.libro,
                alBorrar: () => _borrar(f),
              )),
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
                'Sumá tu EPUB y después, cuando te guste una frase, escribí '
                'las palabras que te acuerdes y te aparece el párrafo entero.',
                style: Tipo.meta,
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Paleta.lila),
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

  // ---------- Ya tiene el texto ----------

  Widget _conLibro() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: TextField(
            controller: _controlador,
            onChanged: _alEscribir,
            autofocus: widget.libro.frases.isEmpty,
            style: const TextStyle(color: Paleta.luz, fontSize: 15),
            cursorColor: Paleta.lila,
            decoration: InputDecoration(
              hintText: 'Escribí lo que te acuerdes…',
              hintStyle: Tipo.meta,
              prefixIcon: const Icon(Icons.format_quote_rounded,
                  color: Paleta.bruma, size: 20),
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
        Expanded(child: _cuerpo()),
      ],
    );
  }

  Widget _cuerpo() {
    if (_busco && _resultados.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
        child: Text(
          'No aparece nada con esas palabras.\n\nProbá con menos, o fijate '
          'que sean tal cual están en el libro: si la frase se corta con '
          'una coma o un guion, ponelas sin eso.',
          style: Tipo.meta,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_resultados.isNotEmpty) {
      final total = _libroDigital!.parrafos.length;
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        itemCount: _resultados.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _Resultado(
          _resultados[i],
          buscado: _controlador.text,
          total: total,
          alGuardar: () => _guardarFrase(_resultados[i]),
        ),
      );
    }

    // Sin búsqueda activa: las frases ya guardadas.
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        if (widget.libro.frases.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Text(
              'El libro está listo: ${_libroDigital!.parrafos.length} '
              'párrafos.\n\nEscribí arriba tres o cuatro palabras de una '
              'frase que te haya gustado.',
              style: Tipo.meta,
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          Rotulo('${widget.libro.frases.length} '
              '${widget.libro.frases.length == 1 ? "frase" : "frases"}'),
          const SizedBox(height: 12),
          ...widget.libro.frases.map((f) => _TarjetaFrase(
                f,
                libro: widget.libro,
                alBorrar: () => _borrar(f),
              )),
        ],
      ],
    );
  }

  Future<void> _borrar(Frase f) async {
    setState(() => widget.libro.frases.remove(f));
    await biblioteca.actualizar();
  }
}

/// Un párrafo encontrado, con las palabras buscadas resaltadas.
class _Resultado extends StatelessWidget {
  final Coincidencia c;
  final String buscado;
  final int total;
  final VoidCallback alGuardar;

  const _Resultado(this.c,
      {required this.buscado, required this.total, required this.alGuardar});

  /// Dónde cae en el libro, dicho como lo diría una persona.
  String get _donde {
    final p = c.porcentaje(total);
    if (p < 0.15) return 'al principio';
    if (p < 0.45) return 'en el primer tercio';
    if (p < 0.7) return 'por la mitad';
    if (p < 0.9) return 'cerca del final';
    return 'en el final';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Paleta.nocheAlta,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TextoResaltado(c.parrafo, buscado: buscado),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(_donde, style: Tipo.meta.copyWith(fontSize: 11)),
              const Spacer(),
              TextButton.icon(
                onPressed: alGuardar,
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: const Text('Guardar', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: Paleta.lila,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pinta en lila el pedazo que se buscó, para que se vea de una.
class _TextoResaltado extends StatelessWidget {
  final String texto;
  final String buscado;

  const _TextoResaltado(this.texto, {required this.buscado});

  @override
  Widget build(BuildContext context) {
    final aguja = Epub.normalizar(buscado);
    final donde = Epub.normalizar(texto).indexOf(aguja);

    if (donde == -1 || aguja.isEmpty) {
      return Text(texto, style: Tipo.lectura);
    }

    // La normalización no cambia el largo del texto (solo reemplaza
    // letras por letras), así que las posiciones siguen sirviendo.
    final fin = (donde + aguja.length).clamp(0, texto.length);
    final inicio = donde.clamp(0, texto.length);

    return Text.rich(
      TextSpan(
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
      ),
    );
  }
}

class _TarjetaFrase extends StatelessWidget {
  final Frase frase;
  final Libro libro;
  final VoidCallback alBorrar;

  const _TarjetaFrase(this.frase,
      {required this.libro, required this.alBorrar});

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
            MaterialPageRoute(
              builder: (_) => PantallaCompartir(libro, frase),
            ),
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
                    Text(fechaCorta(frase.guardada),
                        style: Tipo.meta.copyWith(fontSize: 11)),
                    const SizedBox(width: 10),
                    const Icon(Icons.ios_share_rounded,
                        size: 14, color: Paleta.bruma),
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
              const Icon(Icons.lock_outline_rounded,
                  size: 15, color: Paleta.lila),
              const SizedBox(width: 8),
              Text('Qué pasa con tu archivo',
                  style: Tipo.cuerpo.copyWith(fontWeight: FontWeight.w600)),
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
