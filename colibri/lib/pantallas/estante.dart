import 'dart:math';

import 'package:flutter/material.dart';

import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// Tu biblioteca como una biblioteca: los libros de canto, en una repisa.
///
/// # De dónde sale
///
/// De cómo la gente muestra sus libros. Una grilla de tapas es un catálogo;
/// una repisa con los lomos parados es un estante, y lo que se comparte en
/// redes es siempre el estante. La diferencia no es decorativa: en la
/// grilla cada libro ocupa lo mismo, y en la repisa un libro de novecientas
/// páginas es visiblemente más gordo que uno de ciento veinte. Eso es
/// información que la grilla tira.
///
/// # Por qué no reemplaza a la grilla
///
/// Porque contestan cosas distintas. La grilla sirve para encontrar un
/// libro: se lee el título de un vistazo. La repisa sirve para mirar lo que
/// leíste, que es otra cosa y se hace en otro momento. Conviven con un
/// botón, y cuál preferís queda recordado.
class EstanteDeLomos extends StatefulWidget {
  final List<Libro> libros;
  final ValueChanged<Libro> alTocar;

  /// Las luces de la repisa, que se prenden y se apagan.
  final bool conLuces;

  const EstanteDeLomos(
    this.libros, {
    super.key,
    required this.alTocar,
    this.conLuces = true,
  });

  @override
  State<EstanteDeLomos> createState() => _EstanteDeLomosState();
}

class _EstanteDeLomosState extends State<EstanteDeLomos> {
  /// Qué libro está dado vuelta, mostrando la tapa.
  ///
  /// Uno solo a la vez y no una lista: dar vuelta un libro es mirarlo, y
  /// mirar dos a la vez no es nada. Además, si quedaran muchos dados vuelta
  /// la repisa se convierte otra vez en una grilla desordenada.
  String? _dadoVuelta;

  @override
  Widget build(BuildContext context) {
    if (widget.libros.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, medidas) {
        // Los lomos se acomodan solos: se van sumando a la balda hasta que
        // no entra el siguiente, y ahí empieza otra. Es lo que pasa con los
        // libros de verdad, y evita tener que decidir cuántos por repisa.
        final baldas = <List<Libro>>[];
        var actual = <Libro>[];
        var usado = 0.0;

        for (final libro in widget.libros) {
          final ancho = _anchoDeLomo(libro);
          if (usado + ancho > medidas.maxWidth - 24 && actual.isNotEmpty) {
            baldas.add(actual);
            actual = [];
            usado = 0;
          }
          actual.add(libro);
          usado += ancho + _separacion;
        }
        if (actual.isNotEmpty) baldas.add(actual);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final balda in baldas)
              _Balda(
                libros: balda,
                conLuces: widget.conLuces,
                dadoVuelta: _dadoVuelta,
                alTocar: (l) {
                  // El primer toque lo da vuelta; el segundo lo abre. Así
                  // se puede mirar la tapa sin salir de la repisa, y llegar
                  // a la ficha sigue siendo un gesto corto.
                  if (_dadoVuelta == l.clave) {
                    widget.alTocar(l);
                  } else {
                    setState(() => _dadoVuelta = l.clave);
                  }
                },
              ),
          ],
        );
      },
    );
  }
}

/// Cuánto separa un lomo del siguiente. Poco: los libros de una repisa se
/// tocan, y con aire se ven como fichas y no como libros.
const _separacion = 3.0;

/// El alto de una balda, medido para un teléfono.
const _altoDeBalda = 172.0;

/// El grosor del lomo, según las páginas.
///
/// Es lo que hace que la repisa se lea como una biblioteca de verdad y no
/// como una fila de barritas: un tomo de novecientas páginas tiene que
/// verse gordo al lado de una novela corta.
///
/// Sin páginas anotadas se usa un grosor medio, que es lo mismo que hace
/// una persona cuando no sabe: pone algo del montón. La proporción sale de
/// una regla vieja de imprenta —más o menos veinte hojas por milímetro— y
/// después se recorta a lo que se ve bien en pantalla.
double _anchoDeLomo(Libro libro) {
  final paginas = libro.paginas;
  if (paginas == null || paginas <= 0) return 26;
  return (14 + paginas / 22).clamp(14.0, 44.0);
}

/// El alto de un libro. Los libros no son todos iguales, y una fila
/// perfectamente pareja se ve como un gráfico de barras.
double _altoDeLomo(Libro libro) {
  final semilla = libro.titulo.hashCode.abs();
  return _altoDeBalda * (0.72 + (semilla % 23) / 23 * 0.26);
}

/// El color del lomo.
///
/// # Por qué acá sí hay color
///
/// El librero del fondo de la app es todo del mismo violeta a propósito,
/// para no competir con las tapas. Acá los lomos **son** los libros, así
/// que el color es la información, no el adorno.
///
/// Sale del título, así que dos libros distintos nunca quedan iguales y el
/// mismo libro se ve siempre igual. Los tonos se mantienen oscuros y poco
/// saturados: una repisa de colores chillones se ve como una juguetería, y
/// las encuadernaciones de verdad son apagadas.
Color _colorDeLomo(Libro libro) {
  final semilla = libro.titulo.hashCode.abs();
  final matiz = (semilla % 360).toDouble();
  final saturacion = 0.22 + (semilla % 11) / 11 * 0.20;
  final luz = 0.20 + (semilla % 7) / 7 * 0.14;
  return HSLColor.fromAHSL(1, matiz, saturacion, luz).toColor();
}

class _Balda extends StatelessWidget {
  final List<Libro> libros;
  final bool conLuces;
  final String? dadoVuelta;
  final ValueChanged<Libro> alTocar;

  const _Balda({
    required this.libros,
    required this.conLuces,
    required this.dadoVuelta,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _altoDeBalda,
          child: Stack(
            children: [
              // Los libros, apoyados en el piso de la balda.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final libro in libros) ...[
                      _Lomo(
                        libro,
                        dadoVuelta: dadoVuelta == libro.clave,
                        alTocar: () => alTocar(libro),
                      ),
                      const SizedBox(width: _separacion),
                    ],
                  ],
                ),
              ),

              if (conLuces)
                const Positioned(left: 0, right: 0, top: 6, child: _Luces()),
            ],
          ),
        ),

        // La tabla de la repisa.
        Container(
          height: 7,
          margin: const EdgeInsets.only(bottom: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF3A2E1F),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un libro de canto, que se da vuelta al tocarlo.
class _Lomo extends StatelessWidget {
  final Libro libro;
  final bool dadoVuelta;
  final VoidCallback alTocar;

  const _Lomo(this.libro, {required this.dadoVuelta, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final ancho = _anchoDeLomo(libro);
    final alto = _altoDeLomo(libro);

    return GestureDetector(
      onTap: alTocar,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: dadoVuelta ? 1 : 0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        builder: (context, t, _) {
          // Gira sobre su eje vertical, como un libro que se saca de la
          // repisa y se pone de frente. A mitad de camino se cambia lo que
          // se dibuja, que es cuando el canto queda perpendicular y no se
          // ve nada: ahí el cambio es invisible.
          final angulo = t * pi;
          final deFrente = t > 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // un poco de perspectiva
              ..rotateY(angulo),
            // En la segunda mitad del giro, lo que se dibuje sale espejado
            // —está mirando para el otro lado— así que la tapa se
            // contrarrota. Sin esto el título de la tapa aparece al revés.
            child: deFrente
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _DeFrente(libro, alto: alto),
                  )
                : _DeCanto(libro, ancho: ancho, alto: alto),
          );
        },
      ),
    );
  }
}

/// El lomo, con el título escrito a lo largo.
class _DeCanto extends StatelessWidget {
  final Libro libro;
  final double ancho;
  final double alto;

  const _DeCanto(this.libro, {required this.ancho, required this.alto});

  @override
  Widget build(BuildContext context) {
    final color = _colorDeLomo(libro);
    final angosto = ancho < 22;

    return Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        // Un degradado apenas, que es lo que le da volumen: el canto de un
        // libro recibe la luz de un lado y no del otro. Sin esto la fila se
        // ve como rectángulos planos.
        gradient: LinearGradient(
          colors: [
            color,
            HSLColor.fromColor(color)
                .withLightness(
                  (HSLColor.fromColor(color).lightness + 0.07).clamp(0.0, 1.0),
                )
                .toColor(),
            color,
          ],
          stops: const [0, 0.35, 1],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          topRight: Radius.circular(2),
        ),
        border: Border.all(color: Colors.black.withValues(alpha: 0.28)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
      child: Column(
        children: [
          // Las dos rayitas de arriba, que en las encuadernaciones de
          // verdad son los nervios del lomo. Es lo que hace que se lea
          // como un libro y no como una barra de color.
          _Nervio(ancho: ancho),
          const SizedBox(height: 8),

          Expanded(
            child: angosto
                // En un lomo finito no entra el título: queda el color y
                // los nervios, que ya dicen «libro». Forzarlo daría una
                // letra ilegible, que es peor que nada.
                ? const SizedBox.shrink()
                : RotatedBox(
                    quarterTurns: 1,
                    child: Center(
                      child: Text(
                        libro.titulo.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: ancho < 30 ? 8.5 : 9.5,
                          height: 1,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 8),
          _Nervio(ancho: ancho),
        ],
      ),
    );
  }
}

class _Nervio extends StatelessWidget {
  final double ancho;
  const _Nervio({required this.ancho});

  @override
  Widget build(BuildContext context) => Container(
    width: ancho * 0.62,
    height: 1.2,
    color: Colors.white.withValues(alpha: 0.22),
  );
}

/// El libro dado vuelta: la tapa, de frente.
class _DeFrente extends StatelessWidget {
  final Libro libro;
  final double alto;

  const _DeFrente(this.libro, {required this.alto});

  @override
  Widget build(BuildContext context) {
    // La tapa mantiene su proporción y se apoya en el mismo piso, así el
    // libro parece haber girado y no haber cambiado de tamaño.
    final ancho = alto / 1.5;

    return Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Tapa(libro, ancho: ancho),
    );
  }
}

/// Las luces de la repisa.
///
/// # Por qué se pueden apagar
///
/// Porque son de las dos clases de cosa a la vez: a mucha gente le gustan y
/// a otra le parecen ruido encima de sus libros. Y porque una luz que
/// parpadea sobre un texto lo hace más difícil de leer. Se prenden de
/// fábrica —es lo que la gente pone en sus estantes— y se apagan de un
/// toque, y queda recordado.
///
/// No parpadean. Se probó y en una pantalla, quietas, se ven como luces; en
/// movimiento se ven como una notificación.
class _Luces extends StatelessWidget {
  const _Luces();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, medidas) {
      const separacion = 26.0;
      final cuantas = (medidas.maxWidth / separacion).floor();

      return SizedBox(
        height: 10,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // El cable, que cuelga apenas entre luz y luz.
            Positioned(
              left: 0,
              right: 0,
              top: 3,
              child: Container(
                height: 1,
                color: Paleta.linea.withValues(alpha: 0.7),
              ),
            ),
            for (var i = 0; i < cuantas; i++)
              Positioned(
                left: i * separacion + separacion / 2,
                top: 2,
                child: const _Luz(),
              ),
          ],
        ),
      );
    },
  );
}

class _Luz extends StatelessWidget {
  const _Luz();

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFFFE0A3),
      boxShadow: [
        // Dos halos y no uno: el de adentro da el brillo y el de afuera el
        // resplandor que cae sobre los libros. Con uno solo se ve como un
        // punto amarillo pegado.
        BoxShadow(
          color: const Color(0xFFFFC96B).withValues(alpha: 0.9),
          blurRadius: 6,
        ),
        BoxShadow(
          color: const Color(0xFFFFB84D).withValues(alpha: 0.35),
          blurRadius: 18,
          spreadRadius: 2,
        ),
      ],
    ),
  );
}
