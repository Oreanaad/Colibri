import 'dart:convert';

import 'package:flutter/material.dart';

import '../api.dart';
import '../archivo/selector.dart';
import '../goodreads.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// Traer tu biblioteca de Goodreads.
///
/// # Por qué en dos pasos
///
/// Primero entran los libros, sin pedirle nada a internet: doscientos
/// libros aparecen al instante y funciona sin señal. Recién después, y
/// solo si querés, se van a buscar las tapas.
///
/// Podría hacerse todo junto, pero serían varios minutos mirando una rueda
/// girar antes de ver un solo libro. **Es mejor ver tu biblioteca entera
/// sin tapas que no verla.** Y si cortás la búsqueda de tapas por la
/// mitad, lo que encontró queda.
class PantallaImportar extends StatefulWidget {
  const PantallaImportar({super.key});

  @override
  State<PantallaImportar> createState() => _PantallaImportarState();
}

enum _Paso { esperando, leyendo, revisando, importando, listo }

class _PantallaImportarState extends State<PantallaImportar> {
  _Paso _paso = _Paso.esperando;
  String? _error;

  Importacion? _leido;
  List<Libro> _nuevos = const [];
  int _repetidos = 0;
  int _entraron = 0;

  // El paso de las tapas.
  bool _buscandoTapas = false;
  bool _pedidoParar = false;
  int _revisadas = 0;
  int _encontradas = 0;

  Future<void> _elegir() async {
    setState(() {
      _paso = _Paso.leyendo;
      _error = null;
    });

    try {
      final archivo = await elegirArchivo(acepta: '.csv,text/csv');
      if (archivo == null) {
        if (mounted) setState(() => _paso = _Paso.esperando);
        return;
      }

      // Goodreads exporta en UTF-8, pero algunas planillas viejas vienen
      // en Latin-1 y ahí los acentos llegan rotos. Si UTF-8 falla,
      // probamos con el otro antes de darnos por vencidas.
      String texto;
      try {
        texto = utf8.decode(archivo.bytes);
      } catch (_) {
        texto = latin1.decode(archivo.bytes);
      }

      final leido = Goodreads.leer(texto);

      if (leido.noEsDeGoodreads) {
        _fallar(
          'Ese archivo se puede abrir, pero no es una lista de Goodreads: '
          'no tiene una columna «Title».\n\nFijate de haber bajado el que '
          'te manda Goodreads por correo, sin abrirlo ni guardarlo con '
          'otro programa.',
        );
        return;
      }
      if (leido.vacia) {
        _fallar('Ese archivo no tiene ningún libro adentro.');
        return;
      }

      final nuevos = leido.libros
          .where((l) => biblioteca.buscarPorClave(l.clave) == null)
          .toList();

      if (!mounted) return;
      setState(() {
        _leido = leido;
        _nuevos = nuevos;
        _repetidos = leido.libros.length - nuevos.length;
        _paso = _Paso.revisando;
      });
    } catch (_) {
      _fallar(
        'No se pudo leer el archivo. Tiene que ser el .csv que te manda '
        'Goodreads, sin abrirlo antes con otro programa.',
      );
    }
  }

  void _fallar(String motivo) {
    if (!mounted) return;
    setState(() {
      _error = motivo;
      _paso = _Paso.esperando;
    });
  }

  Future<void> _importar() async {
    setState(() => _paso = _Paso.importando);

    final entraron = await biblioteca.agregarVarios(_nuevos);

    if (!mounted) return;
    setState(() {
      _entraron = entraron;
      _paso = _Paso.listo;
    });
  }

  /// Va a buscar la tapa de cada libro que tenga código de barras.
  ///
  /// De a uno y no todos juntos, a propósito: cien pedidos al mismo tiempo
  /// hacen que el catálogo empiece a contestar que no, y el resultado sería
  /// peor. Y se puede parar en cualquier momento; lo que encontró, queda.
  Future<void> _buscarTapas() async {
    setState(() {
      _buscandoTapas = true;
      _pedidoParar = false;
      _revisadas = 0;
      _encontradas = 0;
    });

    final conCodigo = _nuevos.where((l) => l.isbn != null).toList();

    for (final libro in conCodigo) {
      if (_pedidoParar || !mounted) break;

      final encontrado = await Api.porIsbn(libro.isbn!);
      if (!mounted) break;

      if (encontrado != null &&
          (encontrado.tapaId != null || encontrado.tapaUrl != null)) {
        // Solo la tapa. El título y la autoría se dejan como los trajiste:
        // el catálogo suele devolver el título de la obra original, y
        // pisar «Nuestra parte de noche» con otro sería empeorarlo.
        final i = biblioteca.todos.indexWhere((l) => l.clave == libro.clave);
        if (i != -1) {
          biblioteca.todos[i]
            ..tapaId = encontrado.tapaId
            ..tapaUrl = encontrado.tapaUrl;
          _encontradas++;
        }
      }
      setState(() => _revisadas++);
    }

    await biblioteca.actualizar();
    if (mounted) setState(() => _buscandoTapas = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: const Text(
          'Traer mi biblioteca',
          style: TextStyle(color: Paleta.luz, fontSize: 17),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Columna(
          hijo: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              if (_paso == _Paso.listo) ..._resultado() else ..._antes(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _antes() => [
    const _ComoSacarElArchivo(),
    const SizedBox(height: 22),

    if (_error != null) ...[
      _Aviso(_error!, esError: true),
      const SizedBox(height: 18),
    ],

    if (_paso == _Paso.revisando) ...[
      _Revision(leido: _leido!, nuevos: _nuevos.length, repetidos: _repetidos),
      const SizedBox(height: 18),
      BotonLleno(
        _nuevos.isEmpty
            ? 'Ya los tenías a todos'
            : 'Sumar ${_nuevos.length} ${_nuevos.length == 1 ? "libro" : "libros"}',
        alTocar: _nuevos.isEmpty ? null : _importar,
      ),
      const SizedBox(height: 10),
      BotonContorno(
        'Elegir otro archivo',
        alTocar: () => setState(() => _paso = _Paso.esperando),
      ),
    ] else
      BotonLleno(switch (_paso) {
        _Paso.leyendo => 'Leyendo…',
        _Paso.importando => 'Sumando…',
        _ => 'Elegir el archivo',
      }, alTocar: _paso == _Paso.esperando ? _elegir : null),
  ];

  List<Widget> _resultado() => [
    const SizedBox(height: 8),
    Text(
      _entraron == 1 ? 'Entró 1 libro.' : 'Entraron $_entraron libros.',
      style: Tipo.titulo,
    ),
    const SizedBox(height: 6),
    Text(
      _repetidos == 0
          ? 'Ya están en tu biblioteca, con su puntaje, sus estantes y lo '
                'que hayas escrito.'
          : 'Ya están en tu biblioteca. Los otros $_repetidos ya los tenías '
                'y no se tocaron.',
      style: Tipo.meta,
    ),
    const SizedBox(height: 26),

    ..._pasoDeTapas(),

    const SizedBox(height: 10),
    BotonContorno(
      'Volver a mi biblioteca',
      alTocar: () => Navigator.of(context).pop(),
    ),
  ];

  List<Widget> _pasoDeTapas() {
    final conCodigo = _nuevos.where((l) => l.isbn != null).length;
    if (conCodigo == 0) {
      return [
        _Aviso(
          'Ninguno de esos libros trae código de barras en la lista, así que '
          'las tapas hay que buscarlas de a uno, desde cada libro.',
        ),
        const SizedBox(height: 18),
      ];
    }

    if (_buscandoTapas) {
      return [
        const Rotulo('Buscando las tapas'),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: conCodigo == 0 ? 0 : _revisadas / conCodigo,
          backgroundColor: Paleta.linea,
          valueColor: const AlwaysStoppedAnimation<Color>(Paleta.lila),
        ),
        const SizedBox(height: 10),
        Text(
          '$_revisadas de $conCodigo · $_encontradas encontradas',
          style: Tipo.meta,
        ),
        const SizedBox(height: 14),
        BotonContorno(
          'Parar',
          alTocar: () => setState(() => _pedidoParar = true),
        ),
        const SizedBox(height: 10),
        Text(
          'Lo que encuentre queda guardado aunque lo pares.',
          style: Tipo.meta.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 18),
      ];
    }

    if (_revisadas > 0) {
      return [
        _Aviso(
          'Se buscaron $_revisadas y aparecieron $_encontradas tapas. '
          'Las que no están se pueden elegir a mano desde cada libro.',
        ),
        const SizedBox(height: 18),
      ];
    }

    return [
      const Rotulo('Las tapas'),
      const SizedBox(height: 8),
      Text(
        'La lista de Goodreads no trae portadas, pero $conCodigo de esos '
        'libros traen su código de barras. Con eso se pueden ir a buscar.\n\n'
        'Tarda un rato porque van de a uno, y se puede parar cuando quieras.',
        style: Tipo.meta,
      ),
      const SizedBox(height: 14),
      BotonLleno('Buscar las tapas', alTocar: _buscarTapas),
      const SizedBox(height: 18),
    ];
  }
}

class _ComoSacarElArchivo extends StatelessWidget {
  const _ComoSacarElArchivo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Si ya tenías tu biblioteca en Goodreads, no hace falta volver a '
          'cargarla.',
          style: Tipo.cuerpo,
        ),
        const SizedBox(height: 14),
        const Rotulo('Cómo sacar el archivo'),
        const SizedBox(height: 8),
        Text(
          '1.  En Goodreads, entrá a My Books.\n'
          '2.  Abajo a la izquierda, Import and Export.\n'
          '3.  Tocá Export Library y esperá: tarda unos minutos y te llega '
          'un correo con un archivo .csv.\n'
          '4.  Volvé acá y elegilo.',
          style: Tipo.meta.copyWith(height: 1.7),
        ),
        const SizedBox(height: 14),
        Text(
          'Viaja todo: el estante donde estaba cada libro, tu puntaje, las '
          'fechas, tus estantes propios y las reseñas que hayas escrito. '
          'Nada sale de tu teléfono.',
          style: Tipo.meta,
        ),
      ],
    );
  }
}

/// Lo que se encontró en el archivo, antes de tocar nada.
///
/// Se muestra antes de importar y no después, porque después ya no hay
/// nada que decidir. Y con números: «214 libros» se puede comparar contra
/// lo que una sabe que tiene; «listo» no se puede comparar con nada.
class _Revision extends StatelessWidget {
  final Importacion leido;
  final int nuevos;
  final int repetidos;

  const _Revision({
    required this.leido,
    required this.nuevos,
    required this.repetidos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Paleta.nocheAlta,
        border: Border.all(color: Paleta.linea),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Rotulo('En el archivo'),
          const SizedBox(height: 10),
          _Linea('${leido.libros.length} libros', principal: true),
          if (nuevos != leido.libros.length) _Linea('$nuevos nuevos para vos'),
          if (repetidos > 0) _Linea('$repetidos que ya tenías'),
          if (leido.sinTitulo > 0)
            _Linea('${leido.sinTitulo} filas sin título, se saltean'),
          _Linea('${leido.conIsbn} con código de barras'),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final String texto;
  final bool principal;
  const _Linea(this.texto, {this.principal = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      texto,
      style: principal
          ? Tipo.cuerpo.copyWith(fontWeight: FontWeight.w600)
          : Tipo.meta,
    ),
  );
}

class _Aviso extends StatelessWidget {
  final String texto;
  final bool esError;
  const _Aviso(this.texto, {this.esError = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: esError ? Paleta.oroTenue : Paleta.nocheAlta,
        border: Border.all(color: esError ? Paleta.oroBorde : Paleta.linea),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: Tipo.meta.copyWith(color: esError ? Paleta.oroTexto : null),
      ),
    );
  }
}
