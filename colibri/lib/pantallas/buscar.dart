import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../cuenta.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'cargar_libro.dart';
import 'destacados.dart';
import 'escanear.dart';
import 'exigir_cuenta.dart';
import 'importar.dart';
import 'ficha.dart';

/// Buscar y agregar. La búsqueda arranca sola mientras se escribe:
/// no hay botón de "buscar", porque la espera tiene que ser invisible.
class PantallaBuscar extends StatefulWidget {
  /// Sin sesión, esta misma pantalla es el modo "explorar": buscar y
  /// mirar libros sigue andando igual, pero agregar pide perfil primero.
  /// Cambia el título y agrega la aclaración; el resto de la pantalla no
  /// se entera, porque exigirCuenta() ya se llama siempre, con o sin
  /// sesión.
  final bool explorando;
  const PantallaBuscar({super.key, this.explorando = false});

  @override
  State<PantallaBuscar> createState() => _PantallaBuscarState();
}

class _PantallaBuscarState extends State<PantallaBuscar> {
  final _controlador = TextEditingController();
  Timer? _espera;
  List<Libro> _resultados = [];
  bool _buscando = false;
  bool _busco = false;
  String? _error;

  @override
  void dispose() {
    _espera?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  void _alEscribir(String texto) {
    _espera?.cancel();
    if (texto.trim().length < 3) {
      setState(() {
        _resultados = [];
        _busco = false;
      });
      return;
    }
    // Medio segundo de pausa antes de pedir: evita una consulta por letra.
    _espera = Timer(const Duration(milliseconds: 500), () => _buscar(texto));
  }

  Future<void> _buscar(String texto) async {
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final r = await Api.buscar(texto);
      if (!mounted) return;
      setState(() {
        _resultados = r;
        _buscando = false;
        _busco = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buscando = false;
        _busco = true;
        _error = 'No se pudo conectar. Fijate la conexión y probá de nuevo.';
      });
    }
  }

  /// La cámara vive en su propia pantalla y no acá.
  ///
  /// Escanear no es «buscar más rápido»: es otra postura, con el libro en
  /// la mano y sin teclado. Meterla en esta pantalla la habría dejado
  /// compitiendo con el campo de texto en cada renglón.
  Future<void> _escanear() async {
    if (!await exigirCuenta(context, motivo: 'escanear y agregar libros')) {
      return;
    }
    if (!mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PantallaEscanear()));
    // Al volver puede haber libros nuevos: los resultados que están en
    // pantalla tienen que mostrar el tilde de «ya lo tenés».
    if (mounted) setState(() {});
  }

  Future<void> _cargarAMano() async {
    if (!await exigirCuenta(context, motivo: 'cargar un libro')) return;
    if (!mounted) return;

    final cargado = await Navigator.of(context).push<Libro>(
      MaterialPageRoute(
        builder: (_) => PantallaCargarLibro(textoBuscado: _controlador.text),
      ),
    );
    // Si cargó uno, salimos de la búsqueda: ya consiguió lo que vino a
    // buscar y dejarla acá la obligaría a cerrar dos pantallas.
    //
    // Salvo en modo explorar: ahí esta pantalla no la empujó nadie, es
    // el contenido mismo de la solapa Biblioteca. No hay nada que cerrar
    // y no hay ninguna otra pantalla esperando abajo.
    if (cargado != null && mounted && !widget.explorando) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: Text(
          widget.explorando ? 'Explorar' : 'Agregar un libro',
          style: const TextStyle(color: Paleta.luz, fontSize: 17),
        ),
        actions: widget.explorando
            ? [
                // La misma hoja que aparece al intentar agregar, pero
                // pedida a mano: para quien prefiere entrar antes de
                // ponerse a buscar y no que la app se lo pregunte recién
                // cuando toque el más.
                IconButton(
                  onPressed: () =>
                      exigirCuenta(context, motivo: 'armar tu perfil'),
                  icon: const Icon(Icons.person_outline_rounded),
                  color: Paleta.lila,
                  tooltip: 'Iniciar sesión',
                ),
              ]
            : null,
      ),
      body: SafeArea(
        top: false,
        child: Columna(
          hijo: Column(
            children: [
              if (widget.explorando)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Text(
                    'Podés buscar y mirar libros sin cuenta. Para '
                    'agregarlos, escribir una reseña o ver tu propia '
                    'biblioteca hace falta tu perfil.',
                    style: Tipo.meta,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Expanded(child: _campo()),
                    const SizedBox(width: 10),
                    // Al lado de la barra y no arriba en una esquina.
                    //
                    // Arriba pasaba desapercibido: la vista va al campo de
                    // texto, que es donde parpadea el cursor, y lo de la
                    // esquina no existe. Acá está en el mismo renglón que
                    // lo que estás mirando, y del tamaño de un botón que
                    // se toca con el pulgar.
                    _BotonEscanear(alTocar: _escanear),
                  ],
                ),
              ),
              if (_buscando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(
                      backgroundColor: Paleta.linea,
                      valueColor: AlwaysStoppedAnimation<Color>(Paleta.lila),
                    ),
                  ),
                ),
              Expanded(child: _cuerpo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo() {
    return TextField(
      controller: _controlador,
      onChanged: _alEscribir,
      autofocus: true,
      style: const TextStyle(color: Paleta.luz, fontSize: 15),
      cursorColor: Paleta.lila,
      decoration: InputDecoration(
        hintText: 'Título, autora o ISBN',
        hintStyle: Tipo.meta,
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Paleta.bruma,
          size: 20,
        ),
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
    );
  }

  Widget _cuerpo() {
    if (_error != null) {
      return _Mensaje(_error!);
    }
    if (!_busco && _resultados.isEmpty) {
      return ListView(
        padding: widget.explorando
            ? const EdgeInsets.fromLTRB(20, 4, 20, 32)
            : EdgeInsets.zero,
        children: [
          const _Mensaje(
            'Escribí al menos tres letras, o apuntá al código de barras con '
            'el botón de al lado.',
          ),
          const SizedBox(height: 10),
          const Divider(color: Paleta.linea, indent: 40, endIndent: 40),
          const SizedBox(height: 22),
          const _TraerDeGoodreads(),

          // La biblioteca destacada va al final y solo en modo explorar.
          // En el modo normal —ya con perfil, agregando desde el más de
          // la biblioteca— esta pantalla se abre queriendo agregar un
          // libro puntual, y mostrar diez títulos para mirar sería puro
          // ruido delante de lo que se vino a hacer.
          if (widget.explorando) ...[
            const SizedBox(height: 34),
            const Divider(color: Paleta.linea),
            const SizedBox(height: 28),
            const BibliotecaDestacada(),
          ],
        ],
      );
    }
    if (_resultados.isEmpty) {
      return _NoApareceNada(buscado: _controlador.text, alCargar: _cargarAMano);
    }

    return AnimatedBuilder(
      animation: biblioteca,
      builder: (context, _) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        // Uno más que los resultados: el último renglón es «ninguno de
        // estos es el que tengo». Decía `_resultados.length` a secas, así
        // que ese renglón se dibujaba en una posición que la lista nunca
        // pedía y no apareció nunca desde que se escribió.
        itemCount: _resultados.length + 1,
        separatorBuilder: (_, _) =>
            const Divider(color: Paleta.linea, height: 22, thickness: 1),
        itemBuilder: (_, i) => i == _resultados.length
            ? _NingunoEsElQueTengo(alCargar: _cargarAMano)
            : FilaDeResultado(_resultados[i]),
      ),
    );
  }
}

/// Una fila de la lista de resultados.
///
/// Es pública para poder dibujarla en una prueba sin salir a internet.
/// Cuando alguien reportó que no veía el más, la única forma de contestar
/// sin adivinar fue esa: renderizar la fila y preguntarle a Flutter si el
/// botón está.
class FilaDeResultado extends StatelessWidget {
  final Libro libro;
  const FilaDeResultado(this.libro, {super.key});

  @override
  Widget build(BuildContext context) {
    // Sin perfil, nunca se muestra si el libro ya está en la biblioteca
    // de este teléfono. Eso también es "ver tu propia biblioteca" —un
    // vistazo chiquito, pero es tuyo— y explorar no debería filtrarlo
    // sin haber iniciado sesión.
    final guardado = cuenta.hayPerfil
        ? biblioteca.buscarPorClave(libro.clave)
        : null;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PantallaFicha(guardado ?? libro)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tapa(libro, ancho: 48),
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
                  [
                    libro.autor,
                    if (libro.editorial != null) libro.editorial,
                    if (libro.anio != null) '${libro.anio}',
                  ].join(' · '),
                  style: Tipo.meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Destino(libro, guardado: guardado),
        ],
      ),
    );
  }
}

/// El más, o el estante donde ya lo pusiste.
///
/// # Qué problema resuelve
///
/// Cargando veinte libros de una, lo que se pierde no es el libro: es
/// saber cuáles ya pusiste y dónde. Antes todos iban a pendientes y la
/// única forma de cambiarlo era cazar un aviso que se iba solo, y veinte
/// avisos hacen cola y se pisan.
///
/// Ahora el más pregunta antes, y después la fila queda diciendo dónde
/// quedó ese libro. **La fila es la confirmación**: por eso acá no hay
/// ningún aviso, y es a propósito.
Future<void> _agregar(BuildContext context, Libro libro) async {
  if (!await exigirCuenta(context, motivo: 'agregar un libro')) return;
  if (!context.mounted) return;
  await dondeVa(context, libro);
}

class _Destino extends StatelessWidget {
  final Libro libro;
  final Libro? guardado;

  const _Destino(this.libro, {required this.guardado});

  @override
  Widget build(BuildContext context) {
    final puesto = guardado;

    if (puesto == null) {
      return IconButton(
        onPressed: () => _agregar(context, libro),
        icon: const Icon(Icons.add_circle_outline, size: 26),
        color: Paleta.lila,
        tooltip: 'Agregar',
      );
    }

    return ChipDeEstante(
      puesto.estado,
      alTocar: () => dondeVa(context, puesto),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final String texto;
  const _Mensaje(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      child: Text(texto, style: Tipo.meta, textAlign: TextAlign.center),
    );
  }
}

/// Cuando la búsqueda no encontró nada.
///
/// Es el momento más importante de esta pantalla: acá es donde entra a la
/// app todo lo que las bases abiertas no tienen.
class _NoApareceNada extends StatelessWidget {
  final String buscado;
  final VoidCallback alCargar;

  const _NoApareceNada({required this.buscado, required this.alCargar});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 32),
      children: [
        Text(
          'No apareció nada con «$buscado».',
          style: Tipo.cuerpo,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Pasa seguido con editoriales independientes y con narrativa '
          'latinoamericana reciente: las bases abiertas son flojas justo '
          'ahí. Cargalo vos y queda para siempre.',
          style: Tipo.meta,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        BotonLleno('Cargarlo yo', alTocar: alCargar),
      ],
    );
  }
}

/// Al final de los resultados, por si ninguno era.
/// La invitación a traer la biblioteca de Goodreads.
///
/// Va en la pantalla de agregar un libro, debajo del cartel de que hay que
/// escribir. Es el momento exacto en que aparece: alguien acaba de abrir
/// «agregar un libro» con la biblioteca vacía, y va a cargar el primero de
/// doscientos a mano.
class _TraerDeGoodreads extends StatelessWidget {
  const _TraerDeGoodreads();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Column(
        children: [
          Text(
            '¿Tenías tu biblioteca en Goodreads?',
            style: Tipo.cuerpo,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Se traen todos de una, con puntaje, estantes y reseñas.',
            style: Tipo.meta,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 260,
            child: BotonContorno(
              'Traerla',
              alTocar: () async {
                if (!await exigirCuenta(
                  context,
                  motivo: 'traer tu biblioteca de Goodreads',
                )) {
                  return;
                }
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PantallaImportar()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NingunoEsElQueTengo extends StatelessWidget {
  final VoidCallback alCargar;
  const _NingunoEsElQueTengo({required this.alCargar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        children: [
          Text(
            '¿Ninguno es el que tenés en la mano?',
            style: Tipo.meta,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          BotonContorno('Cargalo vos, son 30 segundos', alTocar: alCargar),
        ],
      ),
    );
  }
}

/// El botón de escanear, al lado del campo.
///
/// Del mismo alto que la barra de búsqueda a propósito: en un renglón, dos
/// cosas de distinto alto se leen como que una es más importante, y acá las
/// dos hacen lo mismo por caminos distintos —una escribiendo, la otra
/// apuntando.
class _BotonEscanear extends StatelessWidget {
  final VoidCallback alTocar;
  const _BotonEscanear({required this.alTocar});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Escanear el código de barras',
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Paleta.nocheAlta,
            border: Border.all(color: Paleta.linea),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.qr_code_scanner_rounded,
            color: Paleta.lila,
            size: 22,
          ),
        ),
      ),
    );
  }
}
