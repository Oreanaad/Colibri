import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// Cargar un libro que no está en ningún catálogo.
///
/// Acá va a entrar buena parte de la narrativa latinoamericana reciente y
/// casi todo lo de editoriales independientes: Open Library y Google Books
/// son flojas justo en lo que tu comunidad lee.
///
/// Dos decisiones de diseño que sostienen la pantalla:
///
/// - **Solo dos campos son obligatorios.** Un formulario largo no mejora
///   el catálogo: hace que nadie cargue nada. Un libro con dos datos
///   buenos vale infinitamente más que un libro que no existe.
/// - **El aviso de duplicado sugiere, nunca bloquea.** A veces son
///   ediciones distintas y la persona tiene razón.
class PantallaCargarLibro extends StatefulWidget {
  /// Lo que venía escrito en el buscador, para no hacerlo tipear dos veces.
  final String textoBuscado;

  const PantallaCargarLibro({super.key, this.textoBuscado = ''});

  @override
  State<PantallaCargarLibro> createState() => _PantallaCargarLibroState();
}

class _PantallaCargarLibroState extends State<PantallaCargarLibro> {
  late final _titulo = TextEditingController(text: widget.textoBuscado);
  final _autor = TextEditingController();
  final _editorial = TextEditingController();
  final _anio = TextEditingController();
  final _paginas = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Redibuja mientras se escribe: así la tapa de vista previa y el
    // aviso de duplicados se actualizan solos.
    for (final c in [_titulo, _autor]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_titulo, _autor, _editorial, _anio, _paginas]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _tituloLimpio => _titulo.text.trim();
  String get _autorLimpio => _autor.text.trim();
  bool get _sePuedeGuardar =>
      _tituloLimpio.isNotEmpty && _autorLimpio.isNotEmpty;

  /// El libro tal como quedaría. Sirve para la vista previa y para guardar.
  Libro get _borrador => Libro(
    id: 'propio:${DateTime.now().microsecondsSinceEpoch}',
    titulo: _tituloLimpio.isEmpty ? 'Sin título' : _tituloLimpio,
    autor: _autorLimpio.isEmpty ? 'Sin autora' : _autorLimpio,
    editorial: _editorial.text.trim().isEmpty ? null : _editorial.text.trim(),
    anio: int.tryParse(_anio.text.trim()),
    paginas: int.tryParse(_paginas.text.trim()),
    origen: Origen.propio,
  );

  Future<void> _guardar() async {
    final libro = _borrador;
    await biblioteca.agregar(libro);

    if (!mounted) return;
    Navigator.of(context).pop(libro);
    mostrarAviso(
      context,
      '«${libro.titulo}» se sumó a ${libro.estado.nombre}',
      accion: 'Cambiar',
      alAccionar: () => elegirEstado(context, libro),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parecidos = biblioteca.parecidos(_tituloLimpio);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Paleta.noche,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: const Text(
          'Cargar un libro',
          style: TextStyle(color: Paleta.luz, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: Columna(
          hijo: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _VistaPrevia(_borrador),
              const SizedBox(height: 22),

              _Campo(
                rotulo: 'Título',
                obligatorio: true,
                controlador: _titulo,
                ejemplo: 'Las niñas del naranjel',
                capitalizacion: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),
              _Campo(
                rotulo: 'Autora',
                obligatorio: true,
                controlador: _autor,
                ejemplo: 'Gabriela Cabezón Cámara',
                capitalizacion: TextCapitalization.words,
              ),

              if (parecidos.isNotEmpty) ...[
                const SizedBox(height: 16),
                _AvisoDeParecidos(parecidos),
              ],

              const SizedBox(height: 22),
              const Rotulo('Opcionales'),
              const SizedBox(height: 12),
              _Campo(
                rotulo: 'Editorial',
                controlador: _editorial,
                ejemplo: 'Random House',
                capitalizacion: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Campo(
                      rotulo: 'Año',
                      controlador: _anio,
                      ejemplo: '2023',
                      soloNumeros: true,
                      largoMaximo: 4,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Campo(
                      rotulo: 'Páginas',
                      controlador: _paginas,
                      ejemplo: '224',
                      soloNumeros: true,
                      largoMaximo: 5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),
              BotonLleno(
                'Agregar a mi biblioteca',
                alTocar: _sePuedeGuardar ? _guardar : null,
              ),
              const SizedBox(height: 12),
              Text(
                _sePuedeGuardar
                    ? 'Va a quedar marcado como cargado por vos. Cuando haya '
                          'comunidad, otras personas podrán completarlo.'
                    : 'Con el título y la autora alcanza. Todo lo demás es '
                          'opcional y se puede completar después.',
                style: Tipo.meta.copyWith(fontSize: 11.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La tapa que va a tener el libro, dibujándose mientras se escribe.
///
/// No es un adorno: ver la tapa aparecer convierte llenar un formulario
/// en armar algo, y eso cambia cuántas personas llegan al final.
class _VistaPrevia extends StatelessWidget {
  final Libro borrador;
  const _VistaPrevia(this.borrador);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Tapa(borrador, ancho: 92),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Rotulo('Así va a quedar'),
              const SizedBox(height: 8),
              Text(
                'Colibrí le dibuja una tapa con el título y la autora. '
                'El color sale del propio título, así que dos libros nunca '
                'quedan iguales.',
                style: Tipo.meta,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Avisa si el libro se parece a algo que ya tenés.
///
/// Sugiere, nunca bloquea: a veces son ediciones distintas del mismo
/// libro y la persona sabe lo que está haciendo.
class _AvisoDeParecidos extends StatelessWidget {
  final List<Libro> libros;
  const _AvisoDeParecidos(this.libros);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            libros.length == 1
                ? 'Fijate que no sea este, que ya lo tenés'
                : 'Fijate que no sea alguno de estos, que ya los tenés',
            style: Tipo.cuerpo.copyWith(
              color: Paleta.oro,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (final l in libros.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Tapa(l, ancho: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${l.titulo} · ${l.autor}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Tipo.cuerpo.copyWith(
                        fontSize: 12.5,
                        color: Paleta.oroTexto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Si es otra edición, seguí igual.',
            style: Tipo.meta.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final String rotulo;
  final TextEditingController controlador;
  final String ejemplo;
  final bool obligatorio;
  final bool soloNumeros;
  final int? largoMaximo;
  final TextCapitalization capitalizacion;

  const _Campo({
    required this.rotulo,
    required this.controlador,
    required this.ejemplo,
    this.obligatorio = false,
    this.soloNumeros = false,
    this.largoMaximo,
    this.capitalizacion = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(rotulo.toUpperCase(), style: Tipo.rotulo),
            if (obligatorio) ...[
              const SizedBox(width: 5),
              Text('·', style: Tipo.rotulo.copyWith(color: Paleta.lila)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controlador,
          textCapitalization: capitalizacion,
          keyboardType: soloNumeros ? TextInputType.number : TextInputType.text,
          inputFormatters: [
            if (soloNumeros) FilteringTextInputFormatter.digitsOnly,
            if (largoMaximo != null)
              LengthLimitingTextInputFormatter(largoMaximo),
          ],
          style: const TextStyle(color: Paleta.luz, fontSize: 15),
          cursorColor: Paleta.lila,
          decoration: InputDecoration(
            hintText: ejemplo,
            hintStyle: Tipo.meta.copyWith(fontSize: 14),
            isDense: true,
            filled: true,
            fillColor: Paleta.nocheAlta,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
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
      ],
    );
  }
}
