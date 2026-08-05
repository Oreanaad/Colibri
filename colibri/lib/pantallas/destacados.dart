import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'ficha.dart';

/// Descubrir: libros al azar para mirar antes de escribir nada.
///
/// # El problema que resuelve
///
/// Explorar sin cuenta arrancaba en una caja de texto vacía: para ver un
/// libro había que saber primero cuál buscar. Eso es al revés de cómo se
/// descubre algo para leer, que es mirando y no tipeando.
///
/// # Por qué "al azar" y no "recomendados"
///
/// La palabra importa. "Recomendado" dice que la app sabe algo de tus
/// gustos, y no sabe nada: no hay cuenta todavía, y aunque la hubiera, no
/// existe ningún motor que mire qué leyó cada una para sugerirle algo a
/// otra. Llamar "recomendado" a un sorteo sería la clase de mentira que
/// se nota apenas alguien recibe dos veces la misma sugerencia sin haber
/// hecho nada que la explique.
///
/// Lo que sí hay es un mazo curado —de acá abajo— del que se reparten
/// unos pocos cada vez, así que se ve distinto en cada visita sin
/// fingir saber nada de quien mira.
///
/// # Por qué son libros reales y no inventados
///
/// Las tapas y los datos salen de Open Library, igual que cualquier
/// búsqueda. Lo único curado es la lista de qué preguntarle; la respuesta
/// es la real. El mazo mezcla narrativa latinoamericana —los diez con los
/// que se midió que el catálogo encuentra bien buscando por título— con
/// las sagas que ya cubren las insignias: son las dos comunidades que la
/// propia app dice que existen acá.
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
  /// Uno por título, no una lista entera: así un libro que ya se buscó
  /// alguna vez no se vuelve a pedir, se haya mostrado esta vez o no.
  static const _cache = 'colibri.descubrir.cache.v1';

  /// Cuántos se reparten por tanda. Ni uno —no habría nada para
  /// descubrir— ni el mazo entero —dejaría de sentirse como un sorteo y
  /// pasaría a ser una lista larga para desplazar.
  static const _porTanda = 8;

  /// El mazo. Narrativa latinoamericana y las sagas que ya tienen
  /// insignia propia: son los dos públicos que la app ya sabe que tiene.
  static const _mazo = [
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
    ('Los detectives salvajes', 'Roberto Bolaño'),
    ('La casa de los espíritus', 'Isabel Allende'),
    ('Como agua para chocolate', 'Laura Esquivel'),
    ('Ficciones', 'Jorge Luis Borges'),
    ('Kentukis', 'Samanta Schweblin'),
    ('La virgen cabeza', 'Gabriela Cabezón Cámara'),
    ('Mugre rosa', 'Fernanda Trías'),
    ('Temporada de huracanes', 'Fernanda Melchor'),
    ("Harry Potter and the Philosopher's Stone", 'J. K. Rowling'),
    ('The Hunger Games', 'Suzanne Collins'),
    ('Divergent', 'Veronica Roth'),
    ('Percy Jackson and the Lightning Thief', 'Rick Riordan'),
    ('City of Bones', 'Cassandra Clare'),
    ('A Court of Thorns and Roses', 'Sarah J. Maas'),
    ('Fourth Wing', 'Rebecca Yarros'),
    ('It Ends With Us', 'Colleen Hoover'),
    ('The Seven Husbands of Evelyn Hugo', 'Taylor Jenkins Reid'),
    ('A Game of Thrones', 'George R. R. Martin'),
    ('The Fellowship of the Ring', 'J. R. R. Tolkien'),
    ('Pride and Prejudice', 'Jane Austen'),
  ];

  final _random = Random();
  List<(String, String)> _tanda = const [];
  List<Libro> _libros = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _repartir();
  }

  /// Elige [_porTanda] títulos del mazo sin repetir los que ya se ven en
  /// pantalla, y los resuelve.
  Future<void> _repartir() async {
    setState(() => _cargando = true);

    // Se sortea sin los que ya estaban, para que "mostrame otros" se
    // sienta como otra mano y no como la misma barajada de nuevo.
    final disponibles = _mazo.where((t) => !_tanda.contains(t)).toList();
    final mazo = disponibles.length >= _porTanda ? disponibles : _mazo;
    mazo.shuffle(_random);
    _tanda = mazo.take(_porTanda).toList();

    final prefs = await SharedPreferences.getInstance();
    final cache = _leerCache(prefs);

    final resueltos = <Libro>[];
    var cambioElCache = false;

    for (final (titulo, autor) in _tanda) {
      final clave = '$titulo|$autor';
      final guardado = cache[clave];

      if (guardado != null) {
        resueltos.add(Libro.desdeJson(guardado));
        continue;
      }

      Libro libro;
      try {
        libro =
            await Api.primero(titulo, autor) ??
            Libro(id: titulo, titulo: titulo, autor: autor);
      } catch (_) {
        libro = Libro(id: titulo, titulo: titulo, autor: autor);
      }
      resueltos.add(libro);
      cache[clave] = libro.aJson();
      cambioElCache = true;
    }

    if (cambioElCache) await prefs.setString(_cache, jsonEncode(cache));

    if (!mounted) return;
    setState(() {
      _libros = resueltos;
      _cargando = false;
    });
  }

  Map<String, dynamic> _leerCache(SharedPreferences prefs) {
    final crudo = prefs.getString(_cache);
    if (crudo == null) return {};
    try {
      return jsonDecode(crudo) as Map<String, dynamic>;
    } catch (_) {
      return {}; // formato viejo o roto: se arranca de cero
    }
  }

  void _abrir(Libro libro) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PantallaFicha(libro)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Rotulo('Descubrir'),
            TextButton(
              onPressed: _cargando ? null : _repartir,
              style: TextButton.styleFrom(
                foregroundColor: Paleta.lila,
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'Mostrame otros',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Al azar, de un mazo curado. Todavía no sabemos qué te gusta a '
          'vos: eso empieza cuando armes tu perfil.',
          style: Tipo.meta,
        ),
        const SizedBox(height: 14),

        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
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
          )
        else
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
