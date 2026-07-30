import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'ficha.dart';

/// Buscar y agregar. La búsqueda arranca sola mientras se escribe:
/// no hay botón de "buscar", porque la espera tiene que ser invisible.
class PantallaBuscar extends StatefulWidget {
  const PantallaBuscar({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Paleta.noche,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: const Text('Agregar un libro',
            style: TextStyle(color: Paleta.luz, fontSize: 17)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: TextField(
                controller: _controlador,
                onChanged: _alEscribir,
                autofocus: true,
                style: const TextStyle(color: Paleta.luz, fontSize: 15),
                cursorColor: Paleta.lila,
                decoration: InputDecoration(
                  hintText: 'Título, autora o ISBN',
                  hintStyle: Tipo.meta,
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Paleta.bruma, size: 20),
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
              ),
            ),
            if (_buscando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: Paleta.noche,
                    valueColor: AlwaysStoppedAnimation<Color>(Paleta.lila),
                  ),
                ),
              ),
            Expanded(child: _cuerpo()),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_error != null) {
      return _Mensaje(_error!);
    }
    if (!_busco && _resultados.isEmpty) {
      return const _Mensaje(
        'Escribí al menos tres letras.\n\nEsta demo busca en Open Library, '
        'que es abierta y gratis. Probá con los libros que estás leyendo vos: '
        'lo que no encuentre es exactamente lo que la comunidad va a tener '
        'que cargar a mano.',
      );
    }
    if (_resultados.isEmpty) {
      return const _Mensaje(
        'No apareció nada.\n\nEn la app real, acá va el botón para cargarlo '
        'a mano: es el camino por el que van a entrar las editoriales '
        'independientes y la narrativa latinoamericana reciente.',
      );
    }

    return AnimatedBuilder(
      animation: biblioteca,
      builder: (context, _) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: _resultados.length,
        separatorBuilder: (_, _) => const Divider(
          color: Paleta.linea,
          height: 22,
          thickness: 1,
        ),
        itemBuilder: (_, i) => _Resultado(_resultados[i]),
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  final Libro libro;
  const _Resultado(this.libro);

  @override
  Widget build(BuildContext context) {
    final yaEsta = biblioteca.tiene(libro);
    final guardado = biblioteca.buscarPorClave(libro.clave);

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
                Text(libro.titulo,
                    style: Tipo.cuerpo.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
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
          IconButton(
            onPressed: () async {
              if (yaEsta) {
                await biblioteca.quitar(libro);
                if (context.mounted) {
                  mostrarAviso(context, '«${libro.titulo}» salió de tu biblioteca');
                }
              } else {
                await biblioteca.agregar(libro);
                if (!context.mounted) return;
                mostrarAviso(
                  context,
                  '«${libro.titulo}» se sumó a ${libro.estado.nombre}',
                  accion: 'Cambiar',
                  alAccionar: () => elegirEstado(context, libro),
                );
              }
            },
            icon: Icon(
              yaEsta ? Icons.check_circle_rounded : Icons.add_circle_outline,
              color: yaEsta ? Paleta.lila : Paleta.bruma,
            ),
            tooltip: yaEsta ? 'Sacar de mi biblioteca' : 'Agregar',
          ),
        ],
      ),
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
