import 'dart:math';

import 'package:flutter/material.dart';

import '../modelos.dart';
import '../tema.dart';
import '../vitrina.dart';
import '../widgets.dart';

/// Tu estante, dibujado como un mueble.
///
/// # Qué hace distinto a una grilla
///
/// Muestra los libros como están en un estante: parados, de canto, con el
/// grosor que les da su cantidad de páginas. Y deja decorarlo, que es lo
/// que la gente hace con los suyos.
///
/// # Cómo se reparten los libros
///
/// Se llena repisa por repisa hasta que no entra el siguiente. Si hay más
/// libros que lugar, la última repisa queda apretada en vez de dejar libros
/// afuera: un estante que esconde libros sin decirlo es peor que uno lleno.
class MuebleDeEstante extends StatelessWidget {
  final List<Libro> libros;
  final Vitrina vitrina;
  final ValueChanged<Libro> alTocar;

  /// Cuando se toca un libro con el editor abierto: cambia de postura en
  /// vez de abrirse.
  final ValueChanged<Libro>? alCambiarPostura;

  const MuebleDeEstante({
    super.key,
    required this.libros,
    required this.vitrina,
    required this.alTocar,
    this.alCambiarPostura,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final ancho = medidas.maxWidth;
        final repisas = _repartir(libros, vitrina, ancho);

        return Container(
          decoration: BoxDecoration(
            color: vitrina.fondo.pared,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Column(
            children: [
              for (final (i, enLaRepisa) in repisas.indexed)
                _Repisa(
                  libros: enLaRepisa,
                  vitrina: vitrina,
                  // Los adornos se reparten entre las repisas en vez de
                  // amontonarse en la primera: uno por repisa, en orden.
                  adornos: _adornosDe(i, vitrina, repisas.length),
                  alTocar: alTocar,
                  alCambiarPostura: alCambiarPostura,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Qué adornos van en cada repisa.
///
/// Las luces van en todas —una guirnalda cruza el mueble entero— y los
/// objetos se reparten de a uno, empezando por arriba. Poner los seis en la
/// misma repisa la convertiría en una repisa de adornos.
Set<Adorno> _adornosDe(int repisa, Vitrina v, int cuantas) {
  final objetos = v.adornos.where((a) => !a.cuelga).toList();
  return {
    if (v.adornos.contains(Adorno.luces)) Adorno.luces,
    for (final (i, o) in objetos.indexed)
      if (i % cuantas == repisa) o,
  };
}

/// El alto de cada repisa, según cuántas haya.
///
/// Con dos repisas hay lugar de sobra y los libros se ven grandes; con seis
/// hay que apretarlas. El mínimo es lo que hace falta para que un lomo siga
/// leyéndose como un libro y no como una rayita.
double _altoDeRepisa(int cuantas) => switch (cuantas) {
  2 => 190,
  3 => 168,
  4 => 146,
  5 => 128,
  _ => 114,
};

/// Reparte los libros por repisa según lo que entra.
///
/// # Los adornos ocupan lugar
///
/// La primera versión repartía los libros y **después** ponía los adornos
/// al final de la fila, que es como se ven bien. El resultado fue un
/// desborde de 63 píxeles: la planta y el gato no entraban en el lugar que
/// ya se habían llevado los libros.
///
/// Un adorno es un objeto en la repisa y ocupa como un libro. Así que el
/// lugar se reserva antes, por repisa, y los libros se reparten en lo que
/// queda. Cuáles van en cada una se puede saber de antemano porque depende
/// solo de cuántas repisas hay, que ya está elegido.
List<List<Libro>> _repartir(List<Libro> libros, Vitrina v, double ancho) {
  final alto = _altoDeRepisa(v.repisas);
  final repisas = <List<Libro>>[];
  var actual = <Libro>[];
  var usado = 0.0;

  /// El ancho útil de una repisa, ya descontados sus adornos.
  double lugarEn(int i) {
    final objetos = _adornosDe(i, v, v.repisas).where((a) => !a.cuelga).length;
    // El «+7» es el padding de cada objeto y el «+3» final es el
    // separador que lleva el último libro de la fila, que también ocupa.
    return ancho - 20 - objetos * (alto * 0.42 + 7) - 3;
  }

  for (final libro in libros) {
    final w = v.posturaDe(libro.clave) == Postura.tapa
        ? _altoDeLomo(libro, alto) / 1.5
        : _anchoDeLomo(libro);

    // La última repisa aguanta lo que sobre: dejar libros afuera sin
    // decirlo es peor que una repisa apretada. Con muchos más libros que
    // lugar, conviene subir el número de repisas, y eso lo decide quien
    // arma el estante.
    if (usado + w > lugarEn(repisas.length) &&
        actual.isNotEmpty &&
        repisas.length < v.repisas - 1) {
      repisas.add(actual);
      actual = [];
      usado = 0;
    }
    actual.add(libro);
    usado += w + 3;
  }
  if (actual.isNotEmpty) repisas.add(actual);

  // Las repisas vacías se dibujan igual: un mueble de cuatro repisas con
  // dos libros sigue siendo un mueble de cuatro repisas.
  while (repisas.length < v.repisas) {
    repisas.add(const []);
  }
  return repisas;
}

double _anchoDeLomo(Libro libro) {
  final paginas = libro.paginas;
  if (paginas == null || paginas <= 0) return 26;
  return (14 + paginas / 22).clamp(14.0, 44.0);
}

double _altoDeLomo(Libro libro, double altoDeRepisa) {
  final semilla = libro.titulo.hashCode.abs();
  return altoDeRepisa * (0.62 + (semilla % 23) / 23 * 0.26);
}

Color _colorDeLomo(Libro libro) {
  final semilla = libro.titulo.hashCode.abs();
  return HSLColor.fromAHSL(
    1,
    (semilla % 360).toDouble(),
    0.22 + (semilla % 11) / 11 * 0.20,
    0.20 + (semilla % 7) / 7 * 0.14,
  ).toColor();
}

class _Repisa extends StatelessWidget {
  final List<Libro> libros;
  final Vitrina vitrina;
  final Set<Adorno> adornos;
  final ValueChanged<Libro> alTocar;
  final ValueChanged<Libro>? alCambiarPostura;

  const _Repisa({
    required this.libros,
    required this.vitrina,
    required this.adornos,
    required this.alTocar,
    this.alCambiarPostura,
  });

  @override
  Widget build(BuildContext context) {
    final alto = _altoDeRepisa(vitrina.repisas);
    final objetos = adornos.where((a) => !a.cuelga).toList();

    return Column(
      children: [
        SizedBox(
          height: alto,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                // La repisa se desliza.
                //
                // Antes la última «aguantaba lo que sobre», y con cuarenta
                // libros en dos repisas eso era un desborde de mil noventa
                // y nueve píxeles: las rayas amarillas y negras encima del
                // estante. Recortarlo tampoco servía —el aviso de desborde
                // salta igual— y esconder los libros de más era justo lo
                // que se quería evitar.
                //
                // Deslizándose entran todos y no se esconde ninguno, que es
                // además lo que pasa con una repisa llena de verdad: los
                // libros del fondo están, hay que correr los de adelante.
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final libro in libros) ...[
                        _Libro(
                          libro,
                          postura: vitrina.posturaDe(libro.clave),
                          altoDeRepisa: alto,
                          alTocar: () => alCambiarPostura != null
                              ? alCambiarPostura!(libro)
                              : alTocar(libro),
                        ),
                        const SizedBox(width: 3),
                      ],
                      // Los objetos van al final de la fila, apoyados al
                      // lado de los libros, que es donde caben en un
                      // estante de verdad.
                      for (final o in objetos) _Objeto(o, alto: alto),
                    ],
                  ),
                ),
              ),

              if (adornos.contains(Adorno.luces))
                const Positioned(left: 0, right: 0, top: 4, child: _Luces()),
            ],
          ),
        ),
        _Tabla(color: vitrina.fondo.tabla),
      ],
    );
  }
}

class _Tabla extends StatelessWidget {
  final Color color;
  const _Tabla({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    height: 7,
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 7,
          offset: const Offset(0, 3),
        ),
      ],
    ),
  );
}

/// Un libro en la repisa: de canto o de frente, según cómo lo pusiste.
class _Libro extends StatelessWidget {
  final Libro libro;
  final Postura postura;
  final double altoDeRepisa;
  final VoidCallback alTocar;

  const _Libro(
    this.libro, {
    required this.postura,
    required this.altoDeRepisa,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final alto = _altoDeLomo(libro, altoDeRepisa);

    return GestureDetector(
      onTap: alTocar,
      child: postura == Postura.tapa
          ? SizedBox(
              width: alto / 1.5,
              height: alto,
              child: Tapa(libro, ancho: alto / 1.5),
            )
          : _Lomo(libro, ancho: _anchoDeLomo(libro), alto: alto),
    );
  }
}

class _Lomo extends StatelessWidget {
  final Libro libro;
  final double ancho;
  final double alto;

  const _Lomo(this.libro, {required this.ancho, required this.alto});

  @override
  Widget build(BuildContext context) {
    final color = _colorDeLomo(libro);
    final angosto = ancho < 22;
    final claro = HSLColor.fromColor(color);

    return Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        // El degradado es lo que le da volumen: el canto de un libro recibe
        // la luz de un lado. Sin esto la fila se ve como rectángulos.
        gradient: LinearGradient(
          colors: [
            color,
            claro
                .withLightness((claro.lightness + 0.07).clamp(0.0, 1.0))
                .toColor(),
            color,
          ],
          stops: const [0, 0.35, 1],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        border: Border.all(color: Colors.black.withValues(alpha: 0.28)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Column(
        children: [
          _Nervio(ancho: ancho),
          const SizedBox(height: 6),
          Expanded(
            child: angosto
                // En un lomo finito no entra el título. Forzarlo daría una
                // letra ilegible, que es peor que el color solo.
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
          const SizedBox(height: 6),
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

/// Un adorno apoyado en la repisa.
///
/// Dibujados y no emoji: un emoji se ve distinto en cada teléfono y
/// tamaño, y al lado de unos lomos dibujados a mano se nota que viene de
/// otro lado. Estos son formas simples con los colores del mueble.
class _Objeto extends StatelessWidget {
  final Adorno adorno;
  final double alto;

  const _Objeto(this.adorno, {required this.alto});

  @override
  Widget build(BuildContext context) {
    final tamano = alto * 0.42;
    return Padding(
      padding: const EdgeInsets.only(left: 5, right: 2),
      child: SizedBox(
        width: tamano,
        height: tamano,
        child: CustomPaint(painter: _DibujoDeAdorno(adorno)),
      ),
    );
  }
}

class _DibujoDeAdorno extends CustomPainter {
  final Adorno adorno;
  const _DibujoDeAdorno(this.adorno);

  @override
  void paint(Canvas l, Size m) {
    final p = Paint()..isAntiAlias = true;
    final base = m.height;

    switch (adorno) {
      case Adorno.planta:
        // La maceta y tres hojas que salen para arriba.
        p.color = const Color(0xFF8C5A3C);
        l.drawRRect(
          RRect.fromLTRBR(
            m.width * 0.28,
            base * 0.66,
            m.width * 0.72,
            base,
            Radius.circular(m.width * 0.05),
          ),
          p,
        );
        p.color = const Color(0xFF4E8A5B);
        for (final (dx, dy) in [(-0.22, 0.30), (0.0, 0.16), (0.22, 0.32)]) {
          l.drawOval(
            Rect.fromCenter(
              center: Offset(m.width * (0.5 + dx), base * dy),
              width: m.width * 0.30,
              height: base * 0.46,
            ),
            p,
          );
        }

      case Adorno.gato:
        // Un gato hecho bollito, que es como duermen en los estantes.
        p.color = const Color(0xFF6B5B7B);
        l.drawOval(Rect.fromLTRB(0, base * 0.42, m.width, base), p);
        // Las dos orejas.
        for (final dx in [0.26, 0.62]) {
          final camino = Path()
            ..moveTo(m.width * dx, base * 0.48)
            ..lineTo(m.width * (dx + 0.06), base * 0.24)
            ..lineTo(m.width * (dx + 0.12), base * 0.48)
            ..close();
          l.drawPath(camino, p);
        }

      case Adorno.hojas:
        p.color = const Color(0xFFB4703A);
        for (final (dx, r) in [(0.22, -0.5), (0.5, 0.2), (0.78, 0.7)]) {
          l.save();
          l.translate(m.width * dx, base * 0.86);
          l.rotate(r);
          l.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: m.width * 0.34,
              height: base * 0.16,
            ),
            p,
          );
          l.restore();
        }

      case Adorno.vela:
        p.color = const Color(0xFFEDE3D0);
        l.drawRect(
          Rect.fromLTRB(m.width * 0.36, base * 0.34, m.width * 0.64, base),
          p,
        );
        p.color = const Color(0xFFFFC96B);
        l.drawOval(
          Rect.fromCenter(
            center: Offset(m.width * 0.5, base * 0.24),
            width: m.width * 0.16,
            height: base * 0.22,
          ),
          p,
        );

      case Adorno.caracol:
        p.color = const Color(0xFFD9C3A5);
        for (final (dx, s) in [(0.3, 0.62), (0.68, 0.44)]) {
          l.drawOval(
            Rect.fromCenter(
              center: Offset(m.width * dx, base * 0.84),
              width: m.width * 0.34 * s * 1.6,
              height: base * 0.30 * s * 1.6,
            ),
            p,
          );
        }

      case Adorno.luces:
        break; // cuelga arriba, no se apoya
    }
  }

  @override
  bool shouldRepaint(_DibujoDeAdorno viejo) => viejo.adorno != adorno;
}

/// La guirnalda. No parpadea: quieta se ve como luces, en movimiento se ve
/// como una notificación.
class _Luces extends StatelessWidget {
  const _Luces();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, m) {
      const paso = 26.0;
      final cuantas = max(1, (m.maxWidth / paso).floor());

      return SizedBox(
        height: 10,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 3,
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            for (var i = 0; i < cuantas; i++)
              Positioned(
                left: i * paso + paso / 2,
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
        // Dos halos: el de adentro es el brillo, el de afuera el resplandor
        // que cae sobre los libros. Con uno solo se ve como un punto
        // amarillo pegado encima.
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

/// «Armá tu estante»: el editor.
///
/// # Por qué es una hoja y no otra pantalla
///
/// Porque hay que ver el mueble mientras se lo cambia. Elegir un fondo sin
/// verlo detrás de tus libros es elegir un cuadradito de color, y la mitad
/// de las decisiones se toman mirando.
///
/// Ocupa la parte de abajo y deja el mueble arriba, a la vista.
class HojaDeArmar extends StatelessWidget {
  final Vitrina vitrina;
  final ValueChanged<Vitrina> alCambiar;

  const HojaDeArmar({
    super.key,
    required this.vitrina,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Paleta.nocheAlta,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Rotulo('Cuántas repisas'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (
                var n = Vitrina.minimoDeRepisas;
                n <= Vitrina.maximoDeRepisas;
                n++
              )
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Ficha(
                      '$n',
                      puesta: vitrina.repisas == n,
                      alTocar: () => alCambiar(vitrina.copiarCon(repisas: n)),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 18),
          const Rotulo('El fondo'),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              children: [
                for (final f in FondoDeVitrina.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: _FichaDeColor(
                      f,
                      puesta: vitrina.fondo == f,
                      alTocar: () => alCambiar(vitrina.copiarCon(fondo: f)),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Rotulo('Qué le ponés'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 8,
            children: [
              for (final a in Adorno.values)
                _Ficha(
                  a.nombre,
                  puesta: vitrina.adornos.contains(a),
                  alTocar: () => alCambiar(vitrina.alternarAdorno(a)),
                  ancho: false,
                ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            'Tocá un libro del estante para darlo vuelta: de lomo o de tapa. '
            'En una biblioteca de verdad siempre hay dos o tres de frente.',
            style: Tipo.meta.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _Ficha extends StatelessWidget {
  final String texto;
  final bool puesta;
  final VoidCallback alTocar;
  final bool ancho;

  const _Ficha(
    this.texto, {
    required this.puesta,
    required this.alTocar,
    this.ancho = true,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: alTocar,
    borderRadius: BorderRadius.circular(30),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: ancho ? 8 : 13, vertical: 7),
      decoration: BoxDecoration(
        color: puesta ? Paleta.lila : null,
        border: Border.all(color: puesta ? Paleta.lila : Paleta.linea),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          color: puesta ? Paleta.noche : Paleta.luz,
          fontWeight: puesta ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}

/// Un fondo, mostrado con su propio color.
///
/// El color va **en** la ficha y no al lado en un puntito: elegir «Bosque»
/// leyendo la palabra es elegir a ciegas.
class _FichaDeColor extends StatelessWidget {
  final FondoDeVitrina fondo;
  final bool puesta;
  final VoidCallback alTocar;

  const _FichaDeColor(
    this.fondo, {
    required this.puesta,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: alTocar,
    borderRadius: BorderRadius.circular(30),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: fondo.pared,
        border: Border.all(
          color: puesta ? Paleta.lila : Paleta.linea,
          width: puesta ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        fondo.nombre,
        style: TextStyle(
          fontSize: 12.5,
          color: Paleta.luz,
          fontWeight: puesta ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}
