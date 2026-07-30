import 'package:flutter/material.dart';
import 'api.dart';
import 'modelos.dart';
import 'tema.dart';

/// La tapa de un libro.
///
/// Si Open Library no la tiene, dibuja una: violeta con el título y la
/// autora. Nunca aparece un rectángulo gris que diga "sin imagen", porque
/// una biblioteca llena de huecos se ve rota.
class Tapa extends StatelessWidget {
  final Libro libro;
  final double ancho;
  final bool marcada;
  final String tamano;

  const Tapa(
    this.libro, {
    super.key,
    this.ancho = 100,
    this.marcada = false,
    this.tamano = 'M',
  });

  @override
  Widget build(BuildContext context) {
    final url = Api.urlTapa(libro.tapaId, tamano: tamano);

    return Container(
      width: ancho,
      height: ancho * 1.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: marcada ? Border.all(color: Paleta.oro, width: 2) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(marcada ? 2 : 4),
        child: url == null
            ? _TapaGenerada(libro, ancho: ancho)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _TapaGenerada(libro, ancho: ancho),
                loadingBuilder: (_, hijo, progreso) => progreso == null
                    ? hijo
                    : Container(color: Paleta.nocheAlta),
              ),
      ),
    );
  }
}

class _TapaGenerada extends StatelessWidget {
  final Libro libro;
  final double ancho;

  const _TapaGenerada(this.libro, {required this.ancho});

  /// El tono sale del título, así que dos libros distintos nunca
  /// quedan idénticos, pero el mismo libro se ve siempre igual.
  Color get _fondo {
    final semilla = libro.titulo.hashCode.abs();
    final matiz = 250.0 + (semilla % 40) - 20; // violetas cercanos
    final luminosidad = 0.14 + (semilla % 7) * 0.012;
    return HSLColor.fromAHSL(1, matiz % 360, 0.42, luminosidad).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final escala = ancho / 100;
    return Container(
      color: _fondo,
      padding: EdgeInsets.all(9 * escala),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              libro.titulo,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11 * escala,
                height: 1.2,
                color: Paleta.luz,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            libro.autor,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.5 * escala,
              height: 1.2,
              color: Paleta.oro,
            ),
          ),
        ],
      ),
    );
  }
}

/// Estrellas de puntuación. Van en oro: son lo que dijo una persona.
class Estrellas extends StatelessWidget {
  final int puntaje;
  final double tamano;
  final ValueChanged<int>? alTocar;

  const Estrellas(this.puntaje, {super.key, this.tamano = 16, this.alTocar});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final llena = i < puntaje;
        final estrella = Icon(
          llena ? Icons.star_rounded : Icons.star_outline_rounded,
          size: tamano,
          color: llena ? Paleta.oro : Paleta.linea,
        );
        if (alTocar == null) return estrella;
        return GestureDetector(
          onTap: () => alTocar!(puntaje == i + 1 ? 0 : i + 1),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: estrella,
          ),
        );
      }),
    );
  }
}

/// El logotipo. Las cuatro letras del medio en oro son la palabra "libro"
/// apareciendo sola: es el secreto de la marca y no se toca.
class Logotipo extends StatelessWidget {
  final double tamano;
  const Logotipo({super.key, this.tamano = 20});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: tamano,
      letterSpacing: tamano * 0.02,
      color: Paleta.luz,
      fontWeight: FontWeight.w400,
    );
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'co', style: base),
        TextSpan(text: 'libr', style: base.copyWith(color: Paleta.oro)),
        TextSpan(text: 'í', style: base),
      ]),
    );
  }
}

/// Botón principal. Es el único relleno de toda la app: la acción de la
/// que depende el producto entero es agregar un libro a la biblioteca.
class BotonLleno extends StatelessWidget {
  final String texto;
  final VoidCallback? alTocar;
  const BotonLleno(this.texto, {super.key, this.alTocar});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: alTocar,
        style: FilledButton.styleFrom(
          backgroundColor: Paleta.lila,
          foregroundColor: Paleta.noche,
          disabledBackgroundColor: Paleta.linea,
          disabledForegroundColor: Paleta.bruma,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(texto),
      ),
    );
  }
}

class BotonContorno extends StatelessWidget {
  final String texto;
  final VoidCallback? alTocar;
  const BotonContorno(this.texto, {super.key, this.alTocar});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: alTocar,
        style: OutlinedButton.styleFrom(
          foregroundColor: Paleta.lila,
          side: const BorderSide(color: Paleta.lila),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        child: Text(texto),
      ),
    );
  }
}

class Rotulo extends StatelessWidget {
  final String texto;
  const Rotulo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(texto.toUpperCase(), style: Tipo.rotulo);
}

/// El cartel dorado del encuentro: aparece solo cuando hay otra
/// persona del otro lado.
class AvisoOro extends StatelessWidget {
  final Widget hijo;
  const AvisoOro({super.key, required this.hijo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Paleta.oroTenue,
        border: Border.all(color: Paleta.oroBorde),
        borderRadius: BorderRadius.circular(10),
      ),
      child: hijo,
    );
  }
}
