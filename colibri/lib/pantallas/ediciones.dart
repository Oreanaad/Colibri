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
  List<Libro>? _ediciones;
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

    final actualizado = Libro(
      id: viejo.id, // la obra sigue siendo la misma
      titulo: edicion.titulo,
      autor: viejo.autor,
      tapaId: edicion.tapaId ?? viejo.tapaId,
      editorial: edicion.editorial ?? viejo.editorial,
      anio: edicion.anio ?? viejo.anio,
      paginas: edicion.paginas ?? viejo.paginas,
      estado: viejo.estado,
      puntaje: viejo.puntaje,
      paginaActual: viejo.paginaActual,
      empezado: viejo.empezado,
      terminado: viejo.terminado,
      resena: viejo.resena,
      resenaConSpoilers: viejo.resenaConSpoilers,
      personaje: viejo.personaje,
      estantes: viejo.estantes,
      frases: viejo.frases,
      origen: viejo.origen,
    );

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
        backgroundColor: Paleta.noche,
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
                      'Open Library guarda el título de la obra original. '
                      'Si tenés una traducción, buscala acá y la ficha pasa '
                      'a estar en tu idioma.',
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

    final lista = _ediciones ?? const <Libro>[];
    if (lista.isEmpty) {
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: lista.length,
      separatorBuilder: (_, _) =>
          const Divider(color: Paleta.linea, height: 20, thickness: 1),
      itemBuilder: (_, i) =>
          _Edicion(lista[i], alElegir: () => _elegir(lista[i])),
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

class _Edicion extends StatelessWidget {
  final Libro edicion;
  final VoidCallback alElegir;

  const _Edicion(this.edicion, {required this.alElegir});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alElegir,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tapa(edicion, ancho: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  edicion.titulo,
                  style: Tipo.cuerpo.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (edicion.editorial != null) edicion.editorial!,
                    if (edicion.anio != null) '${edicion.anio}',
                    if (edicion.paginas != null) '${edicion.paginas} pág.',
                  ].join(' · '),
                  style: Tipo.meta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Paleta.bruma),
        ],
      ),
    );
  }
}
