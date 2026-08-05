import 'package:flutter/material.dart';

import '../cuenta.dart';
import '../fanfic.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'cargar_fanfic.dart';
import 'exigir_cuenta.dart';
import 'ficha.dart';

/// La sección de los fanfics.
///
/// # Por qué tienen sección propia y no una solapa más
///
/// Porque se cargan distinto. Un libro se busca en un catálogo; un fanfic
/// lo cargás vos con su enlace, y ese enlace es lo que impide que el mismo
/// fic entre cuatro mil veces. Si el botón de agregar fanfics viviera
/// mezclado con el de buscar libros, la mitad de las veces alguien iba a
/// cargar un fic como si fuera un libro —sin enlace— y ahí se pierde toda
/// la garantía.
///
/// Separarlos no es ordenar por gusto: **es la única forma de que la regla
/// del enlace se cumpla siempre.**
///
/// # Por qué no aparecen también en la biblioteca
///
/// Mostrarlos en los dos lados sería contar dos veces lo mismo: verías
/// «40 leídos» en un lado y «12 leídos» en otro y ningún número sería el
/// de tu año. La única excepción es la búsqueda, que sí mira todo: que la
/// app te diga «no lo tenés» cuando lo tenés es peor que mezclar.
class PantallaFanfics extends StatelessWidget {
  const PantallaFanfics({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([biblioteca, cuenta]),
      builder: (context, _) {
        // Sin catálogo que mirar: un fanfic se carga con su enlace, y
        // ese enlace es tuyo o no lo es. No hay nada intermedio que
        // "explorar" acá, así que sin perfil no se muestra nada de esta
        // sección, ni siquiera vacía.
        if (!cuenta.hayPerfil) {
          return const NecesitaCuenta(
            titulo: 'Tus fanfics necesitan tu perfil',
            motivo:
                'Se guardan en tu cuenta, así no se pierden si cambiás de '
                'teléfono. Podés seguir explorando libros sin ella.',
          );
        }

        final fics = biblioteca.fanfics;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Columna(
                  hijo: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // El nombre de la sección y no el logotipo: el
                        // logotipo está en la biblioteca, que es la casa.
                        Text(
                          'Fanfics',
                          style: Tipo.titulo.copyWith(fontSize: 22),
                        ),
                        IconButton(
                          onPressed: () => _agregar(context),
                          icon: const Icon(Icons.add_rounded),
                          color: Paleta.lila,
                          tooltip: 'Agregar un fanfic',
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Columna(
                    hijo: fics.isEmpty
                        ? _Vacio(alAgregar: () => _agregar(context))
                        : _Lista(fics),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _agregar(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const PantallaCargarFanfic()));
}

class _Lista extends StatelessWidget {
  final List<Libro> fics;
  const _Lista(this.fics);

  @override
  Widget build(BuildContext context) {
    void abrir(Libro fic) => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PantallaFicha(fic)));

    List<Widget> seccion(String titulo, List<Libro> cuales) {
      if (cuales.isEmpty) return const [];
      return [
        Rotulo('$titulo · ${cuales.length}'),
        const SizedBox(height: 12),
        GrillaLibros(cuales, alTocar: abrir),
        const SizedBox(height: 26),
      ];
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        ...seccion('Leyendo', biblioteca.fanficsEnEstado(Estado.leyendo)),
        ...seccion('Pendientes', biblioteca.fanficsEnEstado(Estado.pendiente)),
        ...seccion('Leídos', biblioteca.fanficsEnEstado(Estado.leido)),

        const SizedBox(height: 6),
        BotonContorno(
          'Agregar otro',
          alTocar: () => PantallaFanfics._agregar(context),
        ),
        const SizedBox(height: 18),
        _PorQueElEnlace(cuantos: fics.length),
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  final VoidCallback alAgregar;
  const _Vacio({required this.alAgregar});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
      children: [
        Text(
          'Acá van los fanfics.',
          style: Tipo.titulo,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'No están en ningún catálogo, así que los cargás vos: pegás el '
          'enlace, ponés el título y listo. Después viven como cualquier '
          'otra lectura, con su puntaje, sus frases y todo lo demás.',
          style: Tipo.meta,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        BotonLleno('Agregar un fanfic', alTocar: alAgregar),
        const SizedBox(height: 28),
        const _PorQueElEnlace(cuantos: 0),
      ],
    );
  }
}

/// La regla, dicha una vez y a la vista.
///
/// No es un aviso legal escondido: es la única cosa que hay que entender
/// de esta sección, y explica por qué la app pide algo que a primera vista
/// parece un trámite.
class _PorQueElEnlace extends StatelessWidget {
  final int cuantos;
  const _PorQueElEnlace({required this.cuantos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Paleta.nocheAlta,
        border: Border.all(color: Paleta.linea),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Rotulo('Por qué se pide el enlace'),
          const SizedBox(height: 8),
          Text(
            'Un mismo fic lo carga muchísima gente, y cada una escribe el '
            'título a su manera: con el ship adelante, con el fandom, '
            'abreviado. Si los comparáramos por el título, un solo fic '
            'serían cientos de fichas distintas.\n\n'
            'El enlace tiene un número que puso el sitio y que nadie '
            'escribe a mano. Con eso alcanza para saber que es el mismo, '
            'aunque lo hayan escrito de mil formas.',
            style: Tipo.meta,
          ),
          if (cuantos > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Reconoce ${Sitio.values.where((s) => s != Sitio.otro).map((s) => s.nombre).join(", ")} '
              'y cualquier otro sitio.',
              style: Tipo.meta.copyWith(fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}
