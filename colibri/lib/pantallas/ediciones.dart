import 'package:flutter/material.dart';

import '../api.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// Los idiomas que ofrece el filtro.
///
/// No están todos los del mundo a propósito: una lista larga es una lista
/// que nadie mira. Estos cubren lo que lee la comunidad, y siempre queda
/// "todos" para el resto.
const _idiomas = <String?, String>{
  null: 'Todos',
  'spa': 'Español',
  'eng': 'Inglés',
  'por': 'Portugués',
  'fre': 'Francés',
  'ita': 'Italiano',
};

/// Elegir qué edición de un libro es la que tenés.
///
/// Existe porque la búsqueda de Open Library siempre devuelve el título
/// de la obra original: buscás "harry potter y la piedra filosofal" y te
/// contesta "Harry Potter and the Philosopher's Stone". El título en tu
/// idioma vive en las ediciones, y hay que ir a buscarlo aparte.
class PantallaEdiciones extends StatefulWidget {
  final Libro libro;
  const PantallaEdiciones(this.libro, {super.key});

  @override
  State<PantallaEdiciones> createState() => _PantallaEdicionesState();
}

class _PantallaEdicionesState extends State<PantallaEdiciones> {
  Ediciones? _ediciones;
  String? _idioma = 'spa'; // lo más probable, y se cambia de un toque
  bool _cargando = true;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _fallo = false;
    });
    try {
      final r = await Api.ediciones(widget.libro, idioma: _idioma);
      if (!mounted) return;
      setState(() {
        _ediciones = r;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _fallo = true;
      });
    }
  }

  /// Cambia el título, la tapa y los datos, pero **no toca nada tuyo**:
  /// las frases, la reseña, el puntaje y las fechas siguen ahí.
  Future<void> _elegir(Libro edicion) async {
    final viejo = widget.libro;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    final actualizado = combinarEdicion(viejo, edicion);

    await biblioteca.quitar(viejo);
    await biblioteca.agregar(actualizado);

    if (!mounted) return;
    navegador.pop(actualizado);
    avisar(mensajero, 'Listo: «${actualizado.titulo}»');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: const Text(
          'Elegir tu edición',
          style: TextStyle(color: Paleta.luz, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: Columna(
          hijo: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buscá la portada igual a la del libro que tenés en la '
                      'mano. Al elegirla, la ficha pasa a ser la de tu '
                      'edición: el título en tu idioma y tu tapa.',
                      style: Tipo.meta,
                    ),
                    const SizedBox(height: 14),
                    _Idiomas(
                      activo: _idioma,
                      alElegir: (i) {
                        setState(() => _idioma = i);
                        _cargar();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(child: _cuerpo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Paleta.lila),
          ),
        ),
      );
    }

    if (_fallo) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
        child: Text(
          'No se pudo conectar. Fijate la conexión y probá de nuevo.',
          style: Tipo.meta,
          textAlign: TextAlign.center,
        ),
      );
    }

    final resultado =
        _ediciones ?? const (confirmadas: <Libro>[], sinIdioma: <Libro>[]);
    final confirmadas = paraMirar(resultado.confirmadas);
    final sinIdioma = paraMirar(resultado.sinIdioma);

    if (confirmadas.isEmpty && sinIdioma.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
        child: Text(
          _idioma == null
              ? 'Este libro no tiene otras ediciones cargadas.'
              : 'No hay ediciones en ${_idiomas[_idioma]!.toLowerCase()}.\n\n'
                    'Probá con «Todos», o dejá la que está.',
          style: Tipo.meta,
          textAlign: TextAlign.center,
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (confirmadas.isNotEmpty) _grilla(confirmadas),

        // Las que el catálogo no etiquetó, abajo y con el motivo dicho.
        //
        // Van al final y no mezcladas porque de estas no sabemos nada, y
        // arriba estorbarían. Pero van, porque acá adentro está la mitad
        // de las ediciones en castellano: de las 200 de Harry Potter, 78
        // no tienen idioma cargado, y la primera de esas es la de
        // Salamandra.
        if (sinIdioma.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                confirmadas.isEmpty ? 4 : 26,
                20,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Rotulo('Sin idioma cargado'),
                  const SizedBox(height: 6),
                  Text(
                    'El catálogo no anotó en qué idioma están estas. Puede '
                    'que la tuya sea una: fijate la portada.',
                    style: Tipo.meta,
                  ),
                ],
              ),
            ),
          ),
          _grilla(sinIdioma),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  Widget _grilla(List<Libro> ediciones) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // Las columnas se fijan y la tapa se estira para llenarlas, no al
      // revés. Ver [Medidas.columnasParaAncho]: pedir "ninguna más ancha
      // que 132" hacía que las tapas se achicaran justo al agrandarse la
      // pantalla. Acá se nota más que en ningún lado, porque esta
      // pantalla es para mirar tapas y decidir cuál es la tuya.
      sliver: SliverLayoutBuilder(
        // crossAxisExtent y no el ancho de la ventana: es el ancho que
        // la grilla tiene de verdad, ya sin los 20 de sangría.
        builder: (context, medidas) => SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Medidas.columnasParaAncho(medidas.crossAxisExtent),
            childAspectRatio: 0.52,
            crossAxisSpacing: 12,
            mainAxisSpacing: 18,
          ),
          itemCount: ediciones.length,
          itemBuilder: (_, i) => _Edicion(
            ediciones[i],
            esLaTuya: ediciones[i].tapaId == widget.libro.tapaId,
            alElegir: () => _elegir(ediciones[i]),
          ),
        ),
      ),
    );
  }
}

class _Idiomas extends StatelessWidget {
  final String? activo;
  final ValueChanged<String?> alElegir;

  const _Idiomas({required this.activo, required this.alElegir});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _idiomas.entries.map((e) {
          final es = e.key == activo;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => alElegir(e.key),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: es ? Paleta.lila : Paleta.linea),
                  color: es ? const Color(0x22B9A6E6) : null,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    color: es ? Paleta.lila : Paleta.bruma,
                    fontWeight: es ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Una edición, como se ve en la grilla.
///
/// La portada es lo grande y el texto es la aclaración, no al revés. Nadie
/// reconoce su libro leyendo «Salamandra, 2005»: lo reconoce viéndolo.
class _Edicion extends StatelessWidget {
  final Libro edicion;
  final bool esLaTuya;
  final VoidCallback alElegir;

  const _Edicion(
    this.edicion, {
    required this.esLaTuya,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) => InkWell(
        onTap: alElegir,
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // El marco dorado sobre la que ya tenés puesta: en esta app el
            // oro es lo que involucra a otra persona o a una decisión ya
            // tomada, y esta es la decisión anterior tuya.
            Tapa(edicion, ancho: medidas.maxWidth, marcada: esLaTuya),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: Text(
                [
                  if (edicion.editorial != null) edicion.editorial!,
                  if (edicion.anio != null) '${edicion.anio}',
                ].join(' · '),
                style: Tipo.meta.copyWith(fontSize: 11, height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prepara la lista para elegir mirando, que es distinto de leerla.
///
/// Dos reglas, las dos por el mismo motivo:
///
/// - **Las que tienen tapa van primero.** Si estás buscando la portada
///   azul que tenés en la mano, una fila de rectángulos vacíos arriba de
///   todo no te sirve para nada.
/// - **Una tapa, una vez.** Open Library tiene la misma edición cargada
///   varias veces con la misma imagen. Mostrar seis veces la misma
///   portada no da a elegir: da a dudar.
List<Libro> paraMirar(List<Libro> ediciones) {
  final vistas = <int>{};
  final conTapa = <Libro>[];
  final sinTapa = <Libro>[];

  for (final e in ediciones) {
    final tapa = e.tapaId;
    if (tapa == null) {
      sinTapa.add(e);
    } else if (vistas.add(tapa)) {
      conTapa.add(e);
    }
  }
  return [...conTapa, ...sinTapa];
}

/// Junta el libro que ya tenías con la edición que elegiste.
///
/// # Qué se queda de cada uno
///
/// De la edición viene **cómo es el libro**: el título en su idioma, la
/// tapa, la editorial, el año, las páginas. De lo que ya tenías viene
/// **todo lo tuyo**, y eso incluye lo que es fácil de olvidar: cuánto
/// lloraste, cuánto picaba, cuánto romance y cómo te dejó.
///
/// Está separada de la pantalla para poder probarla. Antes vivía adentro
/// del botón, y ahí se le habían escapado cuatro campos: cambiar de
/// edición borraba las cuatro escalas y las etiquetas, en silencio.
Libro combinarEdicion(Libro viejo, Libro edicion) {
  return Libro(
    id: viejo.id, // la obra sigue siendo la misma
    titulo: edicion.titulo,
    autor: viejo.autor,
    tapaId: edicion.tapaId ?? viejo.tapaId,
    // Si la edición elegida trae tapa, esa manda y la anterior se va. Si
    // no se borrara, un libro que vino de Google se quedaría con la
    // portada de Google para siempre: la dirección propia le gana al
    // número, y elegir tapa nueva no cambiaría nada.
    tapaUrl: edicion.tapaId != null ? null : viejo.tapaUrl,
    editorial: edicion.editorial ?? viejo.editorial,
    anio: edicion.anio ?? viejo.anio,
    paginas: edicion.paginas ?? viejo.paginas,
    estado: viejo.estado,
    puntaje: viejo.puntaje,
    lagrimas: viejo.lagrimas,
    romantico: viejo.romantico,
    picante: viejo.picante,
    animos: viejo.animos,
    paginaActual: viejo.paginaActual,
    empezado: viejo.empezado,
    terminado: viejo.terminado,
    resena: viejo.resena,
    resenaConSpoilers: viejo.resenaConSpoilers,
    personajes: viejo.personajes,
    estantes: viejo.estantes,
    frases: viejo.frases,
    origen: viejo.origen,
  );
}
