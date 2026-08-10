import 'package:flutter/material.dart';

import '../cuenta.dart';
import '../insignias.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// Elegir los tres libros que te representan.
///
/// Se eligen de tu biblioteca y no se escriben, para que se vea la tapa.
/// Ver [Perfil.libros].
Future<List<String>?> elegirTusLibros(
  BuildContext context,
  List<String> puestos,
) => showModalBottomSheet<List<String>>(
  context: context,
  backgroundColor: Paleta.nocheAlta,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  ),
  builder: (_) => _HojaDeLibros(puestos),
);

class _HojaDeLibros extends StatefulWidget {
  final List<String> puestos;
  const _HojaDeLibros(this.puestos);

  @override
  State<_HojaDeLibros> createState() => _HojaDeLibrosState();
}

class _HojaDeLibrosState extends State<_HojaDeLibros> {
  late final _elegidos = [...widget.puestos];

  void _alternar(Libro libro) {
    setState(() {
      if (_elegidos.remove(libro.clave)) return;
      // Cuando ya hay tres, la cuarta no entra. Se apagan en vez de
      // desaparecer, como los chips de ánimo: se ve que están y por qué
      // no se pueden tocar.
      if (_elegidos.length < Perfil.maximoDeLibros) _elegidos.add(libro.clave);
    });
  }

  @override
  Widget build(BuildContext context) {
    final todos = biblioteca.todos;
    final lleno = _elegidos.length >= Perfil.maximoDeLibros;

    return SafeArea(
      child: Columna(
        hijo: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: _Manija()),
              const SizedBox(height: 16),
              Text('Los libros que sos', style: Tipo.subtitulo),
              const SizedBox(height: 6),
              Text(
                todos.isEmpty
                    ? 'Todavía no tenés libros en tu biblioteca. Sumá alguno '
                          'y volvé.'
                    : 'Hasta ${Perfil.maximoDeLibros}. Los que elijas van a '
                          'ser lo primero que vea alguien que entre a tu '
                          'estante.',
                style: Tipo.meta,
              ),
              const SizedBox(height: 14),

              if (todos.isNotEmpty)
                Flexible(
                  // El ancho real de la hoja, que no es el de la pantalla.
                  child: LayoutBuilder(
                    builder: (context, medidas) => GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: Medidas.columnasParaAncho(
                          medidas.maxWidth,
                        ),
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: todos.length,
                      itemBuilder: (_, i) {
                        final libro = todos[i];
                        final puesto = _elegidos.contains(libro.clave);
                        final apagado = lleno && !puesto;

                        return Opacity(
                          opacity: apagado ? 0.32 : 1,
                          child: InkWell(
                            onTap: apagado ? null : () => _alternar(libro),
                            child: LayoutBuilder(
                              builder: (_, m) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Tapa(
                                    libro,
                                    ancho: m.maxWidth,
                                    marcada: puesto,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    libro.titulo,
                                    style: Tipo.meta.copyWith(fontSize: 10.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              BotonLleno(
                _elegidos.isEmpty
                    ? 'Sin ninguno'
                    : 'Listo · ${_elegidos.length} de ${Perfil.maximoDeLibros}',
                alTocar: () => Navigator.of(context).pop(_elegidos),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Elegir las insignias: casa, facción, cabaña.
Future<List<String>?> elegirTusInsignias(
  BuildContext context,
  List<String> puestas,
) => showModalBottomSheet<List<String>>(
  context: context,
  backgroundColor: Paleta.nocheAlta,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  ),
  builder: (_) => _HojaDeInsignias(puestas),
);

class _HojaDeInsignias extends StatefulWidget {
  final List<String> puestas;
  const _HojaDeInsignias(this.puestas);

  @override
  State<_HojaDeInsignias> createState() => _HojaDeInsigniasState();
}

class _HojaDeInsigniasState extends State<_HojaDeInsignias> {
  late var _elegidas = [...widget.puestas];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Columna(
        hijo: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: _Manija()),
              const SizedBox(height: 16),
              Text('Tus insignias', style: Tipo.subtitulo),
              const SizedBox(height: 6),
              Text(
                'Una por saga: no estás en dos casas. Tocá la que tenés '
                'puesta para sacarla.',
                style: Tipo.meta,
              ),
              const SizedBox(height: 16),

              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final saga in Insignia.sagas) ...[
                      Rotulo(saga),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 8,
                        children: [
                          for (final i in Insignia.deLaSaga(saga))
                            ChapaDeInsignia(
                              i,
                              puesta: _elegidas.contains(i.clave),
                              alTocar: () => setState(
                                () =>
                                    _elegidas = Insignia.alternar(_elegidas, i),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 6),
              BotonLleno(
                _elegidas.isEmpty
                    ? 'Sin ninguna'
                    : 'Listo · ${_elegidas.length}',
                alTocar: () => Navigator.of(context).pop(_elegidas),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una insignia dibujada, con el color de su fandom.
///
/// El color no sale de la paleta de la app y es a propósito: Slytherin es
/// verde, y una insignia de Slytherin en lila no es una insignia, es un
/// chip. Ver el comentario de arriba de [Insignia].
class ChapaDeInsignia extends StatelessWidget {
  final Insignia insignia;
  final bool puesta;
  final VoidCallback? alTocar;

  const ChapaDeInsignia(
    this.insignia, {
    super.key,
    this.puesta = true,
    this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(insignia.color);

    // Sobre el fondo oscuro de la app, algunos colores de fandom quedan
    // ilegibles —el negro de Verdad, el gris de Abnegación—. Se aclaran
    // hasta que se puedan leer, sin dejar de ser el color que son.
    final legible = HSLColor.fromColor(color)
        .withLightness(HSLColor.fromColor(color).lightness.clamp(0.55, 0.80))
        .toColor();

    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: puesta ? legible.withValues(alpha: 0.20) : null,
          border: Border.all(color: puesta ? legible : Paleta.linea),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          insignia.nombre,
          style: TextStyle(
            fontSize: 12.5,
            color: puesta ? legible : Paleta.bruma,
            fontWeight: puesta ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _Manija extends StatelessWidget {
  const _Manija();

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 4,
    decoration: BoxDecoration(
      color: Paleta.linea,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// Los tres libros, como se ven en el perfil.
class TusLibros extends StatelessWidget {
  final List<String> claves;
  final ValueChanged<Libro>? alTocar;

  const TusLibros(this.claves, {super.key, this.alTocar});

  @override
  Widget build(BuildContext context) {
    // Un libro elegido puede haber salido de la biblioteca después. Se
    // saltea en vez de dejar un hueco: nadie se acuerda de qué había ahí.
    final libros = claves
        .map(biblioteca.buscarPorClave)
        .whereType<Libro>()
        .toList();

    if (libros.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final libro in libros)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 76,
              child: InkWell(
                onTap: alTocar == null ? null : () => alTocar!(libro),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tapa(libro, ancho: 76),
                    const SizedBox(height: 6),
                    Text(
                      libro.titulo,
                      style: Tipo.meta.copyWith(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
