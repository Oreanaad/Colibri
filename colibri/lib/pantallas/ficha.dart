import 'package:flutter/material.dart';
import '../cuenta.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'animos.dart';
import 'cargar_libro.dart' show CampoDeTexto;
import 'ediciones.dart';
import 'estantes.dart';
import 'exigir_cuenta.dart';
import 'frases.dart';
import 'nota.dart';
import 'resena.dart';

/// Ficha de un libro: todo lo tuyo sobre él, y lo que dice la comunidad.
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

    // Acá había un `l.paginas ??= 320`, con el comentario «la demo necesita
    // un total para mostrar el avance». No era para mostrar: **le escribía
    // 320 páginas al libro**, y quedaba guardado. Cada libro que se abría
    // sin páginas anotadas se llevaba un total inventado, y después el
    // porcentaje de avance y las estadísticas del perfil contaban con él
    // como si fuera un dato.
    //
    // Ahora, sin total, no se muestra la barra y se ofrece escribirlo. Ver
    // [editarPaginas].

    // Queda anotado que estabas acá, para que recargar no te devuelva a
    // la biblioteca.
    sesion.anotar(libro: l.clave);
  }

  @override
  void dispose() {
    // Al cerrar la ficha se limpia, así la próxima vez abrís donde
    // corresponde y no en un libro que ya dejaste.
    if (sesion.libro == l.clave) sesion.anotar(cerrarLibro: true);
    super.dispose();
  }

  double get _avance {
    final total = l.paginas ?? 0;
    return total == 0 ? 0 : (l.paginaActual / total).clamp(0.0, 1.0);
  }

  Future<void> _guardar() async {
    if (biblioteca.tiene(l)) await biblioteca.actualizar([l]);
    setState(() {});
  }

  Future<void> _agregar() async {
    if (!await exigirCuenta(
      context,
      motivo: 'agregar libros a tu biblioteca',
    )) {
      return;
    }
    if (!mounted) return;

    await biblioteca.agregar(l);
    if (!mounted) return;
    mostrarAviso(
      context,
      '«${l.titulo}» se sumó a ${l.estado.nombre}',
      accion: 'Cambiar',
      alAccionar: () => elegirEstado(context, l),
    );
  }

  /// Ir a elegir en qué idioma y edición tenés el libro.
  ///
  /// Open Library siempre devuelve el título de la obra original, así que
  /// un libro traducido aparece con el título en el idioma en que se
  /// escribió, no en el que lo leíste.
  Future<void> _cambiarEdicion() async {
    final elegida = await Navigator.of(
      context,
    ).push<Libro>(MaterialPageRoute(builder: (_) => PantallaEdiciones(l)));
    if (elegida != null && mounted) setState(() => l = elegida);
  }

  Future<void> _elegirFecha({required bool esInicio}) async {
    final hoy = DateTime.now();
    final actual = esInicio ? l.empezado : l.terminado;

    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? hoy,
      // Una fecha de fin nunca puede ser anterior a la de inicio: en vez
      // de avisar del error después, el calendario no deja elegirla.
      firstDate: esInicio ? DateTime(1970) : (l.empezado ?? DateTime(1970)),
      lastDate: hoy,
      helpText: esInicio ? 'Cuándo lo empezaste' : 'Cuándo lo terminaste',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );

    if (elegida == null) return;
    setState(() {
      if (esInicio) {
        l.empezado = elegida;
      } else {
        l.terminado = elegida;
      }
    });
    await _guardar();
  }

  Future<void> _borrarFecha({required bool esInicio}) async {
    setState(() {
      if (esInicio) {
        l.empezado = null;
      } else {
        l.terminado = null;
      }
    });
    await _guardar();
  }

  Future<void> _sumarPersonaje() async {
    final controlador = TextEditingController();

    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Paleta.nocheAlta,
        title: Text('Sumar un personaje', style: Tipo.subtitulo),
        content: TextField(
          controller: controlador,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Paleta.luz),
          cursorColor: Paleta.lila,
          decoration: const InputDecoration(
            hintText: 'Susana San Juan',
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
            child: const Text('Sumar'),
          ),
        ],
      ),
    );

    controlador.dispose();
    if (nombre == null) return;

    final limpio = nombre.trim();
    if (limpio.isEmpty) return;

    // Sin repetidos, sin importar las mayúsculas.
    final yaEsta = l.personajes.any(
      (p) => p.toLowerCase() == limpio.toLowerCase(),
    );
    if (yaEsta) return;

    setState(() => l.personajes.add(limpio));
    await _guardar();
  }

  Future<void> _sacarPersonaje(String nombre) async {
    setState(() => l.personajes.remove(nombre));
    await _guardar();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([biblioteca, cuenta]),
      builder: (context, _) {
        // Y no solo biblioteca.tiene(l). Sin el perfil, aunque el libro
        // ya estuviera guardado en este teléfono de antes, se vería toda
        // la edición —tu reseña, tus notas, cómo te dejó— sin haber
        // iniciado sesión. "Ver tu propia biblioteca" pide perfil, y esto
        // es exactamente eso: tu biblioteca, mirada desde adentro.
        final enBiblioteca = biblioteca.tiene(l) && cuenta.hayPerfil;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Paleta.lila,
            elevation: 0,
          ),
          body: Columna(
            // ListView.builder y no ListView con children.
            //
            // Con `children`, Flutter construye TODAS las secciones de
            // una: medido, eran 1340 widgets de golpe contra 418 de la
            // biblioteca, y 78 ms en una máquina rápida sin navegador.
            // En Chrome eso se sentía como que la pantalla se trababa
            // antes de abrir el libro.
            //
            // Con `builder` se construye solo lo que se ve, y el resto
            // aparece a medida que se baja.
            hijo: Builder(
              builder: (context) {
                final secciones = _secciones(enBiblioteca);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  itemCount: secciones.length,
                  itemBuilder: (_, i) => secciones[i](),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Las secciones de la ficha, como funciones que todavía no se
  /// ejecutaron.
  ///
  /// Devolver funciones y no widgets es lo que permite que ListView
  /// construya solo las que entran en pantalla. Si devolviera widgets ya
  /// armados, el trabajo de construirlos ya estaría hecho y no
  /// habríamos ganado nada.
  List<Widget Function()> _secciones(bool enBiblioteca) {
    Widget conAire(Widget hijo, [double abajo = 22]) => Padding(
      padding: EdgeInsets.only(bottom: abajo),
      child: hijo,
    );

    Widget rotulado(String rotulo, Widget hijo, [double abajo = 22]) => Padding(
      padding: EdgeInsets.only(bottom: abajo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Rotulo(rotulo), const SizedBox(height: 10), hijo],
      ),
    );

    return [
      () => conAire(
        _Encabezado(
          l,
          alPuntuar: (p) {
            l.puntaje = p;
            _guardar();
          },
          alCambiarEdicion: _cambiarEdicion,
        ),
        24,
      ),

      if (!enBiblioteca)
        () => conAire(BotonLleno('Agregar a mi biblioteca', alTocar: _agregar))
      else ...[
        () => conAire(
          _SelectorEstado(
            l.estado,
            alCambiar: (e) async {
              final eraOtro = l.estado != e;
              await biblioteca.cambiarEstado(l, e);
              if (!mounted) return;
              setState(() {});

              // El único momento en que el libro está fresco.
              // Solo la primera vez, y siempre se puede saltear.
              if (eraOtro &&
                  l.estado == Estado.leido &&
                  l.animos.isEmpty &&
                  context.mounted) {
                await preguntarComoTeDejo(context, l);
                if (mounted) setState(() {});
              }
            },
          ),
        ),

        () => rotulado(
          'Tu lectura',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Fechas(
                l,
                alTocar: (esInicio) => _elegirFecha(esInicio: esInicio),
                alBorrar: (esInicio) => _borrarFecha(esInicio: esInicio),
              ),
              if (l.estado == Estado.leyendo) ...[
                const SizedBox(height: 16),
                _avanceLectura(),
              ],
            ],
          ),
        ),

        () => rotulado('Tus estantes', ChipsDeEstantes(l)),

        () => rotulado(
          l.personajes.length > 1
              ? 'Tus personajes favoritos'
              : 'Tu personaje favorito',
          _Personajes(l, alSumar: _sumarPersonaje, alSacar: _sacarPersonaje),
        ),

        () => rotulado('Tu reseña', ResenaPropia(l)),

        // Al lado de la reseña, y con su propio rótulo: verlas juntas es
        // lo que hace evidente que son dos cosas distintas, una para
        // afuera y otra para adentro.
        () => rotulado(
          'Tus notas',
          NotaPropia(
            l,
            alTocar: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => PantallaNota(l)));
              if (mounted) setState(() {});
            },
          ),
        ),
        () => rotulado('Tus frases', _Frases(l)),

        () => rotulado(
          'Y además',
          _OtrasEscalas(
            l,
            alCambiar: (escala, v) {
              setState(() {
                switch (escala) {
                  case Escala.lagrimas:
                    l.lagrimas = v;
                  case Escala.corazones:
                    l.romantico = v;
                  case Escala.chiles:
                    l.picante = v;
                  case Escala.estrellas:
                    l.puntaje = v;
                }
              });
              _guardar();
            },
          ),
        ),

        () => rotulado(
          'Cómo te dejó',
          ChipsDeAnimo(
            elegidas: l.animos.toSet(),
            alAlternar: (a) {
              setState(() {
                if (!l.animos.remove(a) && l.animos.length < Animos.maximo) {
                  l.animos.add(a);
                }
              });
              _guardar();
            },
          ),
        ),
      ],

      // De acá para abajo es lo que dice la comunidad, todavía de
      // mentira. Va al final a propósito: primero lo tuyo.
      () => rotulado(
        'Lo que dice la comunidad',
        const _AnimosDeLaComunidad(),
        30,
      ),
      () => rotulado(
        'Reseñas de la comunidad',
        _Capas(avance: _avance, leyendo: l.estado == Estado.leyendo),
        30,
      ),
      // Solo si hay una de verdad. Un rótulo «La frase más subrayada»
      // arriba de un hueco es peor que no tener la sección.
      if (_FraseSubrayada.hayAlguna)
        () => rotulado('La frase más subrayada', const _FraseSubrayada(), 0),

      if (enBiblioteca)
        () => Padding(
          padding: const EdgeInsets.only(top: 34),
          child: BotonContorno(
            'Sacar de mi biblioteca',
            alTocar: () async {
              await biblioteca.quitar(l);
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ),
    ];
  }

  Widget _avanceLectura() {
    // Sin total conocido, el deslizador no tiene sentido: no se puede
    // mostrar «por dónde vas» de algo que no se sabe cuánto mide. Antes
    // acá había un 320 inventado, así que el deslizador y el porcentaje
    // mentían sin avisar.
    final total = l.paginas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Rotulo('Por dónde vas'),
            // Tocar el número lo abre para escribirlo. Con un libro de 800
            // páginas, arrastrar el deslizador hasta la 437 exacta es
            // imposible, y la 437 es justo el dato que alguien quiere
            // anotar cuando cierra el libro.
            // Flexible y con ellipsis: sin esto el renglón se desbordaba
            // 28 píxeles y aparecían las rayas de error. Y no es solo el
            // caso raro: «página 1200 de 1248» de un libro gordo es más
            // largo que el ancho que queda al lado del rótulo. Dice «120
            // de 254» y no «página 120 de 254» porque el rótulo de al lado
            // ya dice de qué se trata.
            Flexible(
              child: InkWell(
                onTap: _editarPaginas,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          total == null
                              ? 'página ${l.paginaActual}'
                              : '${l.paginaActual} de $total',
                          overflow: TextOverflow.ellipsis,
                          style: Tipo.meta.copyWith(
                            fontSize: 11,
                            color: Paleta.lila,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: Paleta.lila,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        if (total == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'El catálogo no dice cuántas páginas tiene esta edición. '
              'Tocá arriba para ponerlo y te queda la barra de avance.',
              style: Tipo.meta.copyWith(fontSize: 11),
            ),
          )
        else ...[
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
              onChanged: (v) => setState(() => l.paginaActual = v.round()),
              onChangeEnd: (_) => _guardar(),
            ),
          ),
          Text(
            'Moviendo esto se abren las reseñas de más abajo.',
            style: Tipo.meta.copyWith(fontSize: 11),
          ),
        ],
      ],
    );
  }

  Future<void> _editarPaginas() async {
    final r = await editarPaginas(
      context,
      paginaActual: l.paginaActual,
      total: l.paginas,
    );
    if (r == null || !mounted) return;

    setState(() {
      l.paginas = r.total;
      // Si el total nuevo es más chico que donde estabas, se recorta: la
      // página 400 de un libro de 250 no existe. Pasa de verdad al
      // corregir el total hacia abajo después de haber arrastrado el
      // deslizador con el total viejo.
      l.paginaActual = r.total == null
          ? r.paginaActual
          : r.paginaActual.clamp(0, r.total!);
    });
    await _guardar();
  }
}

/// Escribir en qué página vas y cuántas tiene **tu** edición.
///
/// # Por qué se puede corregir el total
///
/// Porque el catálogo se equivoca seguido, y porque la edición que alguien
/// tiene en la mano no es siempre la que Open Library anotó: la de bolsillo
/// tiene 480 páginas donde la de tapa dura tiene 352, y el mismo libro en
/// otra editorial puede tener cien de diferencia. Con el total mal, el
/// porcentaje de avance miente y la barra queda inservible.
///
/// # Por qué se escribe y no solo se arrastra
///
/// El deslizador está bien para moverse a ojo, pero con un libro de 800
/// páginas llegar arrastrando a la 437 exacta no se puede. Y 437 es
/// justamente el número que alguien quiere anotar cuando marca la página y
/// cierra el libro.
Future<({int paginaActual, int? total})?> editarPaginas(
  BuildContext context, {
  required int paginaActual,
  required int? total,
}) => showModalBottomSheet<({int paginaActual, int? total})>(
  context: context,
  backgroundColor: Paleta.nocheAlta,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  ),
  builder: (_) => _HojaDePaginas(paginaActual: paginaActual, total: total),
);

class _HojaDePaginas extends StatefulWidget {
  final int paginaActual;
  final int? total;

  const _HojaDePaginas({required this.paginaActual, required this.total});

  @override
  State<_HojaDePaginas> createState() => _HojaDePaginasState();
}

class _HojaDePaginasState extends State<_HojaDePaginas> {
  late final _pagina = TextEditingController(
    // Un cero de arranque es ruido: se borra para escribir arriba.
    text: widget.paginaActual == 0 ? '' : '${widget.paginaActual}',
  );
  late final _total = TextEditingController(
    text: widget.total == null ? '' : '${widget.total}',
  );

  String? _problema;

  @override
  void dispose() {
    _pagina.dispose();
    _total.dispose();
    super.dispose();
  }

  void _guardar() {
    final pagina = int.tryParse(_pagina.text.trim()) ?? 0;
    final total = int.tryParse(_total.text.trim());

    if (pagina < 0 || (total != null && total <= 0)) {
      setState(() => _problema = 'Los números tienen que ser positivos.');
      return;
    }
    if (total != null && pagina > total) {
      setState(
        () => _problema =
            'La página $pagina no existe en un libro de $total páginas.',
      );
      return;
    }

    Navigator.of(context).pop((paginaActual: pagina, total: total));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // El teclado: sin esto tapa los campos que se están escribiendo.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Columna(
          hijo: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 16),
                Text('Por dónde vas', style: Tipo.subtitulo),
                const SizedBox(height: 6),
                Text(
                  'El total es el de tu edición. Si tu ejemplar tiene más o '
                  'menos páginas que lo que dice el catálogo, corregilo acá: '
                  'lo que manda es el libro que tenés en la mano.',
                  style: Tipo.meta,
                ),
                const SizedBox(height: 18),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CampoDeTexto(
                        rotulo: 'Vas en la',
                        controlador: _pagina,
                        ejemplo: '137',
                        soloNumeros: true,
                        largoMaximo: 5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CampoDeTexto(
                        rotulo: 'De un total',
                        controlador: _total,
                        ejemplo: '254',
                        soloNumeros: true,
                        largoMaximo: 5,
                      ),
                    ),
                  ],
                ),

                if (_problema != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _problema!,
                    style: Tipo.meta.copyWith(color: Paleta.oroTexto),
                  ),
                ],

                const SizedBox(height: 18),
                BotonLleno('Guardar', alTocar: _guardar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final Libro l;
  final ValueChanged<int> alPuntuar;
  final VoidCallback alCambiarEdicion;

  const _Encabezado(
    this.l, {
    required this.alPuntuar,
    required this.alCambiarEdicion,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
              // Solo para los que vinieron del catálogo: los cargados a
              // mano ya tienen el título que la lectora quiso.
              if (l.origen == Origen.catalogo &&
                  l.id.startsWith('/works/')) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: alCambiarEdicion,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.translate_rounded,
                          size: 13,
                          color: Paleta.lila,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '¿Tenés otra edición?',
                          style: Tipo.meta.copyWith(
                            fontSize: 11.5,
                            color: Paleta.lila,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (l.origen == Origen.propio) ...[
                const SizedBox(height: 8),
                // Queda registrado de dónde salió cada ficha. No es para
                // desconfiar: es para poder completar y unir duplicados
                // más adelante sin revisar el catálogo entero.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 14,
                      color: Paleta.bruma,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Lo cargaste vos',
                      style: Tipo.meta.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Estrellas(l.puntaje, tamano: 22, alTocar: alPuntuar),
              const SizedBox(height: 4),
              Text(
                l.puntaje == 0 ? 'tocá para puntuar' : '${l.puntaje} de 5',
                style: Tipo.meta.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Las dos fechas, y cuánto te llevó si están las dos.
class _Fechas extends StatelessWidget {
  final Libro l;
  final ValueChanged<bool> alTocar;
  final ValueChanged<bool> alBorrar;

  const _Fechas(this.l, {required this.alTocar, required this.alBorrar});

  @override
  Widget build(BuildContext context) {
    final dias = l.diasDeLectura;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Fecha(
                rotulo: 'Empecé',
                fecha: l.empezado,
                alTocar: () => alTocar(true),
                alBorrar: () => alBorrar(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Fecha(
                rotulo: 'Terminé',
                fecha: l.terminado,
                alTocar: () => alTocar(false),
                alBorrar: () => alBorrar(false),
              ),
            ),
          ],
        ),
        if (dias != null) ...[
          const SizedBox(height: 10),
          Text(
            dias == 1 ? 'Lo leíste en un día.' : 'Lo leíste en $dias días.',
            style: Tipo.meta.copyWith(color: Paleta.lila),
          ),
        ],
      ],
    );
  }
}

class _Fecha extends StatelessWidget {
  final String rotulo;
  final DateTime? fecha;
  final VoidCallback alTocar;
  final VoidCallback alBorrar;

  const _Fecha({
    required this.rotulo,
    required this.fecha,
    required this.alTocar,
    required this.alBorrar,
  });

  @override
  Widget build(BuildContext context) {
    final puesta = fecha != null;

    return InkWell(
      onTap: alTocar,
      onLongPress: puesta ? alBorrar : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: puesta ? Paleta.lila : Paleta.linea),
          color: puesta ? const Color(0x14B9A6E6) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  puesta
                      ? Icons.event_available_rounded
                      : Icons.calendar_today_outlined,
                  size: 13,
                  color: puesta ? Paleta.lila : Paleta.bruma,
                ),
                const SizedBox(width: 6),
                Text(rotulo, style: Tipo.meta.copyWith(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              puesta ? fechaCorta(fecha!) : 'Anotar',
              style: TextStyle(
                fontSize: 13.5,
                color: puesta ? Paleta.luz : Paleta.bruma,
                fontWeight: puesta ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Los personajes favoritos van en lila porque hoy son un dato tuyo.
///
/// El día que la app diga "otras tres personas también eligieron a
/// Susana San Juan", eso ya es un encuentro y se pinta de oro. Y va a ser
/// una coincidencia más fina que compartir un libro: elegir el mismo
/// personaje dice **cómo** lo leíste, no solo qué leíste.
class _Personajes extends StatelessWidget {
  final Libro l;
  final VoidCallback alSumar;
  final ValueChanged<String> alSacar;

  const _Personajes(this.l, {required this.alSumar, required this.alSacar});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final nombre in l.personajes)
          InkWell(
            onTap: () => alSacar(nombre),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
              decoration: BoxDecoration(
                color: const Color(0x14B9A6E6),
                border: Border.all(color: Paleta.lila),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    size: 13,
                    color: Paleta.lila,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Paleta.luz,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: Paleta.bruma,
                  ),
                ],
              ),
            ),
          ),
        InkWell(
          onTap: alSumar,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Paleta.bruma),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              l.personajes.isEmpty ? '¿Con quién te quedaste?' : '+ Sumar otro',
              style: Tipo.meta.copyWith(fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Las tres escalas de sensación, cada una con su pregunta al lado.
///
/// Las tres escalas van en oro y se distinguen por la forma del ícono, no
/// por el color: meter un azul para las lágrimas o un rojo para el chile
/// rompería lo que hace que el oro se vea.
class _OtrasEscalas extends StatelessWidget {
  final Libro l;
  final void Function(Escala, int) alCambiar;

  const _OtrasEscalas(this.l, {required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    Widget fila(Escala escala, int valor) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(
              escala.pregunta,
              style: Tipo.meta.copyWith(fontSize: 12.5),
            ),
          ),
          Puntuacion(
            escala,
            valor,
            tamano: 20,
            alTocar: (v) => alCambiar(escala, v),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Corazones primero y lágrimas justo abajo: van de a pares.
        // El romance y el llanto se leen juntos —un romance que te hace
        // llorar es otra cosa que uno que no—, y el picante cierra.
        fila(Escala.corazones, l.romantico),
        fila(Escala.lagrimas, l.lagrimas),
        fila(Escala.chiles, l.picante),
      ],
    );
  }
}

/// Las frases subrayadas: cuántas hay y el acceso a buscarlas.
class _Frases extends StatelessWidget {
  final Libro l;
  const _Frases(this.l);

  @override
  Widget build(BuildContext context) {
    final cuantas = l.frases.length;
    final digital = biblioteca.tieneTexto(l);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cuantas > 0) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: Paleta.oroTenue,
              border: Border(left: BorderSide(color: Paleta.oro, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cortada a cuatro renglones: es un adelanto, no la
                // frase entera. Para leerla completa está el botón de
                // abajo, que además lleva a todas las demás.
                Text(
                  '“${l.frases.first.texto}”',
                  style: Tipo.lectura,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (cuantas > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'y ${cuantas - 1} más',
                    style: Tipo.meta.copyWith(
                      color: Paleta.oro,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        BotonContorno(
          cuantas == 0
              ? (digital ? 'Buscar una frase' : 'Sumar mis frases')
              : 'Ver las $cuantas frases',
          alTocar: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => PantallaFrases(l))),
        ),
      ],
    );
  }
}

/// Los tres estados. Tocar el que ya está puesto lo deshace.
///
/// Es la salida para el toque sin querer: sin eso, marcar "leído" por
/// error deja una fecha de fin inventada y un "lo leíste en un día" que
/// nunca pasó, sin forma de arreglarlo.
class _SelectorEstado extends StatelessWidget {
  final Estado activo;
  final ValueChanged<Estado> alCambiar;

  const _SelectorEstado(this.activo, {required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: Estado.values.map((e) {
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

class _AnimosDeLaComunidad extends StatelessWidget {
  const _AnimosDeLaComunidad();

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
          .map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Paleta.linea),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                '${e.$1} · ${e.$2}',
                style: Tipo.meta.copyWith(fontSize: 11.5),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Reseñas de la comunidad, por tramos de spoiler.
///
/// # Por qué acá no hay reseñas de muestra
///
/// Antes había tres, firmadas «Caro Vidal», «Juli Peralta» y «Mara
/// Giménez», y en ningún lado decía que fueran inventadas. Puestas en la
/// ficha de cualquier libro, se leían como si tres personas hubieran
/// opinado de *ese* libro: se elogiaba «la mitad del medio, cuando aparece
/// la casa» de una novela que no tiene ninguna casa.
///
/// En la pantalla de Descubrir sí quedan reseñas de muestra, pero ahí están
/// rotuladas «RESEÑAS DE MUESTRA» y dicen en voz alta que todavía no hay
/// comunidad. Eso es una maqueta; esto era una afirmación falsa.
///
/// Los tres tramos se quedan, apagados, porque explican cómo va a
/// funcionar: cada uno se abre cuando llegás a esa parte del libro, así
/// nadie te arruina el final. Cuando haya reseñas de verdad van a entrar
/// justo ahí.
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

  bool _abierta(int i) => widget.avance >= _umbrales[i];

  @override
  Widget build(BuildContext context) {
    if (!_abierta(_elegida)) _elegida = 0;

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
                        color: es ? Paleta.lila : Paleta.linea,
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!abierta) ...[
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 11,
                            color: Paleta.bruma,
                          ),
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
                              fontWeight: es
                                  ? FontWeight.w600
                                  : FontWeight.w400,
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
        const SizedBox(height: 16),

        // El vacío se dice, no se disimula. Una ficha con este espacio en
        // blanco parecería que algo no cargó.
        Text(
          'Todavía no hay reseñas de este tramo.',
          style: Tipo.cuerpo.copyWith(color: Paleta.bruma),
        ),
        const SizedBox(height: 6),
        Text(
          _abierta(2)
              ? 'Sos de las primeras. Escribí la tuya más arriba y va a ser '
                    'la que lea quien llegue después.'
              : 'Cuando haya, cada tramo se abre al llegar a esa parte del '
                    'libro: nadie te cuenta el final antes de tiempo.',
          style: Tipo.meta,
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
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: Paleta.bruma,
                ),
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

/// La frase que más gente subrayó de este libro.
///
/// # Por qué devuelve nada
///
/// Acá había una frase fija —«La oscuridad no se hereda…»— con el texto
/// «subrayada por 43 personas» debajo, en oro. Salía igual en la ficha de
/// cualquier libro: en el oro que esta app reserva para los encuentros con
/// otra persona, debía de una novela que no la contiene, con un número de
/// personas que no existen.
///
/// El oro es la promesa más fuerte de Colibrí: «alguien más marcó esto».
/// Gastarla en algo inventado la vacía para cuando sea verdad.
///
/// Cuando haya frases subidas de varias personas, esto va a mirar la tabla
/// `frases` y traer la más repetida de esta edición. Hasta entonces
/// devuelve nada, y la ficha no dibuja la sección: ver [_secciones].
class _FraseSubrayada extends StatelessWidget {
  const _FraseSubrayada();

  /// Todavía no hay de dónde sacarla.
  ///
  /// Es un getter y no una constante para que se lea como lo que es: una
  /// pregunta que hoy siempre se contesta «no» y que mañana va a mirar la
  /// base.
  static bool get hayAlguna => false;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
