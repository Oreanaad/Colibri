import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'ficha.dart';

/// La biblioteca de otra persona: la pantalla más importante de la app.
/// Los libros que también tenés vos se encienden en oro.
///
/// En la demo, Caro es de mentira y su estante se resuelve una vez contra
/// Open Library. En la app real esto viene de tu servidor.
class PantallaComunidad extends StatefulWidget {
  const PantallaComunidad({super.key});

  @override
  State<PantallaComunidad> createState() => _PantallaComunidadState();
}

class _PantallaComunidadState extends State<PantallaComunidad> {
  static const _cache = 'colibri.caro.v1';

  static const _estanteDeCaro = [
    ('Distancia de rescate', 'Samanta Schweblin'),
    ('Las cosas que perdimos en el fuego', 'Mariana Enriquez'),
    ('Pedro Páramo', 'Juan Rulfo'),
    ('La casa de los espíritus', 'Isabel Allende'),
    ('Rayuela', 'Julio Cortázar'),
    ('Los detectives salvajes', 'Roberto Bolaño'),
    ('Como agua para chocolate', 'Laura Esquivel'),
    ('Cien años de soledad', 'Gabriel García Márquez'),
    ('El túnel', 'Ernesto Sabato'),
  ];

  List<Libro> _libros = [];
  bool _cargando = true;
  bool _siguiendo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_cache);

    if (crudo != null) {
      try {
        final lista = jsonDecode(crudo) as List;
        setState(() {
          _libros =
              lista.map((j) => Libro.desdeJson(j as Map<String, dynamic>)).toList();
          _cargando = false;
        });
        return;
      } catch (_) {
        // cache vieja: la rehacemos
      }
    }

    final encontrados = <Libro>[];
    for (final (titulo, autor) in _estanteDeCaro) {
      try {
        final l = await Api.primero(titulo, autor);
        encontrados.add(l ??
            Libro(id: titulo, titulo: titulo, autor: autor)); // tapa generada
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: biblioteca,
      builder: (context, _) {
        final mias = biblioteca.todos.map((l) => l.clave).toSet();
        final comunes =
            _libros.where((l) => mias.contains(l.clave)).map((l) => l.clave).toSet();

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Caro Vidal', style: Tipo.titulo),
                        const SizedBox(height: 3),
                        Text('${_libros.length} libros · sigue a 48',
                            style: Tipo.meta),
                      ],
                    ),
                  ),
                  // Seguir es secundario: la acción de esta pantalla es mirar.
                  OutlinedButton(
                    onPressed: () => setState(() => _siguiendo = !_siguiendo),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Paleta.lila,
                      side: const BorderSide(color: Paleta.lila),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                    ),
                    child: Text(_siguiendo ? 'Siguiendo' : 'Seguir',
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Paleta.lila),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Armando la biblioteca de Caro…',
                          style: Tipo.meta, textAlign: TextAlign.center),
                    ],
                  ),
                )
              else ...[
                AvisoOro(
                  hijo: comunes.isEmpty
                      ? Text(
                          'Todavía no tienen ningún libro en común. '
                          'Agregá alguno a tu biblioteca y volvé: los que '
                          'coincidan se encienden en oro.',
                          style: Tipo.cuerpo
                              .copyWith(color: Paleta.oroTexto, fontSize: 13),
                        )
                      : Text.rich(
                          TextSpan(
                            style: Tipo.cuerpo.copyWith(
                                color: Paleta.oroTexto, fontSize: 13),
                            children: [
                              TextSpan(
                                text: comunes.length == 1
                                    ? 'Tienen 1 libro en común'
                                    : 'Tienen ${comunes.length} libros en común',
                                style: const TextStyle(
                                    color: Paleta.oro,
                                    fontWeight: FontWeight.w600),
                              ),
                              const TextSpan(
                                  text:
                                      '. Los marcados también están en tu biblioteca.'),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 18),
                GrillaLibros(
                  _libros,
                  marcados: comunes,
                  alTocar: (l) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PantallaFicha(
                          biblioteca.buscarPorClave(l.clave) ?? l),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
