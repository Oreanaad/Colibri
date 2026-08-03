import 'package:flutter/material.dart';

import '../fanfic.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'cargar_libro.dart' show CampoDeTexto;
import 'ficha.dart';

/// Sumar un fanfic.
///
/// # Por qué el enlace va primero y es obligatorio
///
/// Los fanfics no están en ningún catálogo: los carga quien los lee. Eso
/// quiere decir que el mismo fic va a entrar cargado por muchísima gente,
/// cada una escribiendo el título a su manera —con el ship adelante, con
/// el fandom, abreviado, en mayúsculas— y comparando títulos serían
/// cuatro mil fichas de un solo fic.
///
/// El enlace arregla eso de raíz, porque es un número que puso el sitio y
/// nadie lo escribe a mano. Por eso es el primer campo y el único
/// obligatorio: **es lo que hace que sea ese fic y no otro.** Ver
/// [Fanfic.identidad].
///
/// # Por qué avisa antes de guardar
///
/// Apenas pegás el enlace, sin pedirle nada a internet, la app ya sabe si
/// ese fic está en tu biblioteca. Decírtelo ahí —y no después de que
/// llenaste cinco campos— es la diferencia entre una ayuda y un reto.
class PantallaCargarFanfic extends StatefulWidget {
  const PantallaCargarFanfic({super.key});

  @override
  State<PantallaCargarFanfic> createState() => _PantallaCargarFanficState();
}

class _PantallaCargarFanficState extends State<PantallaCargarFanfic> {
  final _enlace = TextEditingController();
  final _titulo = TextEditingController();
  final _autoria = TextEditingController();
  final _fandom = TextEditingController();
  final _capitulos = TextEditingController();

  @override
  void initState() {
    super.initState();
    _enlace.addListener(() => setState(() {}));
    for (final c in [_titulo, _autoria]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_enlace, _titulo, _autoria, _fandom, _capitulos]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _identidad => Fanfic.identidad(_enlace.text);

  /// El fic que ya tenés con ese enlace, si lo tenés.
  Libro? get _yaLoTenes {
    final id = _identidad;
    if (id == null) return null;
    return biblioteca.buscarPorClave('fanfic|$id');
  }

  bool get _sePuedeGuardar =>
      _identidad != null &&
      _yaLoTenes == null &&
      _titulo.text.trim().isNotEmpty;

  Future<void> _guardar() async {
    final limpio = Fanfic.limpiar(_enlace.text)!;

    final fic = Libro(
      id: 'fanfic:${_identidad!}',
      titulo: _titulo.text.trim(),
      autor: _autoria.text.trim().isEmpty
          ? 'Autoría sin nombre'
          : _autoria.text.trim(),
      enlace: limpio,
      fandom: _fandom.text.trim().isEmpty ? null : _fandom.text.trim(),
      paginas: int.tryParse(_capitulos.text.trim()),
      origen: Origen.fanfic,
    );

    await biblioteca.agregar(fic);
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => PantallaFicha(fic)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: const Text(
          'Sumar un fanfic',
          style: TextStyle(color: Paleta.luz, fontSize: 17),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Columna(
          hijo: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              CampoDeTexto(
                rotulo: 'El enlace',
                controlador: _enlace,
                ejemplo: 'archiveofourown.org/works/1234567',
                obligatorio: true,
                capitalizacion: TextCapitalization.none,
              ),
              const SizedBox(height: 8),
              _LoQueSabemosDelEnlace(
                texto: _enlace.text,
                identidad: _identidad,
                yaLoTenes: _yaLoTenes,
              ),

              const SizedBox(height: 20),
              CampoDeTexto(
                rotulo: 'Título',
                controlador: _titulo,
                ejemplo: 'Todo lo que somos',
                obligatorio: true,
                capitalizacion: TextCapitalization.sentences,
              ),
              const SizedBox(height: 18),
              CampoDeTexto(
                rotulo: 'Quién lo escribió',
                controlador: _autoria,
                ejemplo: 'su nombre en el sitio',
                capitalizacion: TextCapitalization.none,
              ),
              const SizedBox(height: 18),
              CampoDeTexto(
                rotulo: 'De qué fandom',
                controlador: _fandom,
                ejemplo: 'Harry Potter',
                capitalizacion: TextCapitalization.words,
              ),
              const SizedBox(height: 18),
              CampoDeTexto(
                rotulo: 'Capítulos',
                controlador: _capitulos,
                ejemplo: '37',
                soloNumeros: true,
                largoMaximo: 5,
              ),

              const SizedBox(height: 28),
              BotonLleno(
                'Sumarlo a pendientes',
                alTocar: _sePuedeGuardar ? _guardar : null,
              ),
              const SizedBox(height: 20),
              Text(
                'Los fanfics viven en tu biblioteca como cualquier otra '
                'lectura: con su puntaje, sus frases y todo lo demás. '
                'Colibrí no guarda el texto, guarda que lo leíste.',
                style: Tipo.meta.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo que la app deduce del enlace, en el momento.
///
/// Sin pedirle nada a internet: de qué sitio es, y si ese fic ya está en
/// tu biblioteca. Es toda la seguridad contra los repetidos, hecha visible.
class _LoQueSabemosDelEnlace extends StatelessWidget {
  final String texto;
  final String? identidad;
  final Libro? yaLoTenes;

  const _LoQueSabemosDelEnlace({
    required this.texto,
    required this.identidad,
    required this.yaLoTenes,
  });

  @override
  Widget build(BuildContext context) {
    if (texto.trim().isEmpty) {
      return Text(
        'Pegá la dirección del fic. Es lo que hace que sea ese y no otro: '
        'sin ella, el mismo fanfic cargado por diez personas serían diez '
        'fichas distintas.',
        style: Tipo.meta,
      );
    }

    if (identidad == null) {
      return _Cartel(
        icono: Icons.link_off_rounded,
        texto:
            'Eso no parece una dirección. Tiene que ser el enlace del fic, '
            'copiado del navegador.',
      );
    }

    final repetido = yaLoTenes;
    if (repetido != null) {
      return _Cartel(
        icono: Icons.check_circle_outline_rounded,
        oro: true,
        texto: 'Ese fic ya está en tu biblioteca: «${repetido.titulo}».',
        accion: 'Abrirlo',
        alAccionar: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => PantallaFicha(repetido)),
        ),
      );
    }

    return _Cartel(
      icono: Icons.link_rounded,
      texto: 'Un fic de ${Fanfic.sitioDe(texto).nombre}. No lo tenías.',
    );
  }
}

class _Cartel extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool oro;
  final String? accion;
  final VoidCallback? alAccionar;

  const _Cartel({
    required this.icono,
    required this.texto,
    this.oro = false,
    this.accion,
    this.alAccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: oro ? Paleta.oroTenue : Paleta.nocheAlta,
        border: Border.all(color: oro ? Paleta.oroBorde : Paleta.linea),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 17, color: oro ? Paleta.oro : Paleta.bruma),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texto,
                  style: Tipo.meta.copyWith(
                    color: oro ? Paleta.oroTexto : null,
                  ),
                ),
                if (accion != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: alAccionar,
                    child: Text(
                      accion!,
                      style: Tipo.meta.copyWith(
                        color: Paleta.lila,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
