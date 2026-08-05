import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'ficha.dart';

/// Una biblioteca para mirar antes de escribir nada.
///
/// # El problema que resuelve
///
/// Explorar sin cuenta arrancaba en una caja de texto vacía: para ver un
/// libro había que saber primero cuál buscar. Eso es al revés de cómo se
/// descubre algo para leer, que es mirando y no tipeando.
///
/// # Por qué son libros reales y no inventados
///
/// Las tapas y los datos salen de Open Library, igual que cualquier
/// búsqueda: estos diez títulos son los mismos con los que se midió, en
/// su momento, que el catálogo encuentra bien la narrativa latinoamericana
/// buscando por título. Lo único curado es la lista de qué preguntarle;
/// la respuesta es la real.
///
/// # Las reseñas de muestra
///
/// Son las mismas tres que ya se usan en la ficha de cualquier libro
/// mientras no haya servidor de comunidad de verdad, con la misma
/// etiqueta. Se repiten acá a propósito y no se inventan otras: que
/// parecieran distintas sugeriría que hay más contenido real del que hay.
class BibliotecaDestacada extends StatefulWidget {
  const BibliotecaDestacada({super.key});

  @override
  State<BibliotecaDestacada> createState() => _BibliotecaDestacadaState();
}

class _BibliotecaDestacadaState extends State<BibliotecaDestacada> {
  static const _cache = 'colibri.destacados.v1';

  static const _titulos = [
    ('Cometierra', 'Dolores Reyes'),
    ('Las malas', 'Camila Sosa Villada'),
    ('Cien años de soledad', 'Gabriel García Márquez'),
    ('Pedro Páramo', 'Juan Rulfo'),
    ('Nuestra parte de noche', 'Mariana Enriquez'),
    ('Chicas muertas', 'Selva Almada'),
    ('La uruguaya', 'Pedro Mairal'),
    ('Catedrales', 'Claudia Piñeiro'),
    ('Rayuela', 'Julio Cortázar'),
    ('Distancia de rescate', 'Samanta Schweblin'),
  ];

  List<Libro> _libros = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Se resuelve una sola vez contra Open Library y se guarda. Sin esto,
  /// cada vez que alguien abre Explorar se mandan diez consultas de
  /// nuevo, y en datos móviles eso se siente.
  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_cache);

    if (crudo != null) {
      try {
        final lista = jsonDecode(crudo) as List;
        setState(() {
          _libros = lista
              .map((j) => Libro.desdeJson(j as Map<String, dynamic>))
              .toList();
          _cargando = false;
        });
        return;
      } catch (_) {
        // Formato viejo o roto: se rehace.
      }
    }

    final encontrados = <Libro>[];
    for (final (titulo, autor) in _titulos) {
      try {
        final l = await Api.primero(titulo, autor);
        encontrados.add(l ?? Libro(id: titulo, titulo: titulo, autor: autor));
      } catch (_) {
        encontrados.add(Libro(id: titulo, titulo: titulo, autor: autor));
      }
    }

    if (!mounted) return;
    await prefs.setString(
      _cache,
      jsonEncode(encontrados.map((l) => l.aJson()).toList()),
    );
    setState(() {
      _libros = encontrados;
      _cargando = false;
    });
  }

  void _abrir(Libro libro) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PantallaFicha(libro)));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Paleta.lila),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Rotulo('Para empezar a mirar'),
        const SizedBox(height: 12),
        GrillaLibros(_libros, alTocar: _abrir),
        const SizedBox(height: 28),
        const Rotulo('Reseñas de muestra'),
        const SizedBox(height: 6),
        Text(
          'Todavía no hay comunidad de verdad: esto es cómo se van a ver '
          'las reseñas cuando la haya.',
          style: Tipo.meta,
        ),
        const SizedBox(height: 12),
        const _ReseniasDeMuestra(),
      ],
    );
  }
}

/// Las mismas tres reseñas que ya aparecen en la ficha de cualquier
/// libro. Ver el porqué en el comentario de arriba de [BibliotecaDestacada].
class _ReseniasDeMuestra extends StatelessWidget {
  const _ReseniasDeMuestra();

  static const _textos = [
    (
      'Empieza como una novela de terror y termina siendo sobre un padre y '
          'un hijo. Aguantá las primeras cien páginas, que después no la '
          'soltás.',
      'Caro Vidal',
      5,
    ),
    (
      'La leí en un viaje de tres horas y me quedé sin viaje. De las que se '
          'terminan de un tirón y después no podés empezar otra en varios '
          'días.',
      'Juli Peralta',
      5,
    ),
    (
      'No es un libro para todo el mundo, pero si es para vos, lo vas a '
          'saber en la primera página.',
      'Mara Giménez',
      4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (texto, quien, estrellas) in _textos)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Paleta.nocheAlta,
                border: Border.all(color: Paleta.linea),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"$texto"', style: Tipo.lectura.copyWith(fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '$quien  ',
                        style: Tipo.meta.copyWith(fontSize: 11.5),
                      ),
                      Estrellas(estrellas, tamano: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
