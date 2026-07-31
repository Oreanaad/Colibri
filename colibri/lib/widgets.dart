import 'package:flutter/material.dart';
import 'api.dart';
import 'chile.dart';
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

/// Las tres cosas que se puntúan de un libro.
///
/// Miden cosas distintas y por eso conviven: [estrellas] dice qué tan
/// bueno es, [lagrimas] cuánto te hizo llorar y [chiles] cuánto calienta.
/// Un libro puede ser flojo y hacerte llorar igual.
enum Escala { estrellas, lagrimas, chiles }

extension DatosDeEscala on Escala {
  String get nombre => switch (this) {
    Escala.estrellas => 'Puntaje',
    Escala.lagrimas => 'Lágrimas',
    Escala.chiles => 'Picante',
  };

  String get pregunta => switch (this) {
    Escala.estrellas => '¿Qué tan bueno?',
    Escala.lagrimas => '¿Cuánto lloraste?',
    Escala.chiles => '¿Cuánto calienta?',
  };
}

/// Una fila de cinco marcas que se tocan para puntuar.
///
/// Las tres escalas van en oro y se distinguen por la forma del ícono, no
/// por el color. Es la misma decisión de siempre: el oro es lo único
/// cálido de la app, y meter un azul para las lágrimas o un rojo para los
/// chiles rompería lo que hace que el oro se vea.
class Puntuacion extends StatelessWidget {
  final Escala escala;
  final int valor;
  final double tamano;
  final ValueChanged<int>? alTocar;

  const Puntuacion(
    this.escala,
    this.valor, {
    super.key,
    this.tamano = 16,
    this.alTocar,
  });

  Widget _marca(bool cuenta) {
    final color = cuenta ? Paleta.oro : Paleta.linea;

    if (escala == Escala.chiles) {
      return Chile(tamano: tamano, color: color, lleno: cuenta);
    }

    return Icon(
      switch (escala) {
        Escala.estrellas =>
          cuenta ? Icons.star_rounded : Icons.star_outline_rounded,
        Escala.lagrimas =>
          cuenta ? Icons.water_drop_rounded : Icons.water_drop_outlined,
        Escala.chiles => Icons.circle, // no llega acá
      },
      size: tamano,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final marca = _marca(i < valor);
        if (alTocar == null) return marca;

        return GestureDetector(
          // Tocar la que ya está puesta borra la puntuación: es la salida
          // para el toque sin querer, igual que con los estados.
          onTap: () => alTocar!(valor == i + 1 ? 0 : i + 1),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: marca,
          ),
        );
      }),
    );
  }
}

/// Atajo para el caso más común, que es el puntaje de siempre.
class Estrellas extends StatelessWidget {
  final int puntaje;
  final double tamano;
  final ValueChanged<int>? alTocar;

  const Estrellas(this.puntaje, {super.key, this.tamano = 16, this.alTocar});

  @override
  Widget build(BuildContext context) =>
      Puntuacion(Escala.estrellas, puntaje, tamano: tamano, alTocar: alTocar);
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
      TextSpan(
        children: [
          TextSpan(text: 'co', style: base),
          TextSpan(
            text: 'libr',
            style: base.copyWith(color: Paleta.oro),
          ),
          TextSpan(text: 'í', style: base),
        ],
      ),
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

/// El cartelito de abajo que confirma que algo pasó.
///
/// Confirmar es más importante de lo que parece: sin esto, tocás
/// "agregar" y no pasa nada visible, así que no sabés si funcionó.
///
/// Va en lila relleno con el texto oscuro. Antes iba del color de las
/// tarjetas y se perdía contra el fondo: un aviso que no se ve no avisa.
void avisar(
  ScaffoldMessengerState mensajero,
  String texto, {
  String? accion,
  VoidCallback? alAccionar,
}) {
  mensajero
    ..hideCurrentSnackBar() // si había otro, no se apilan
    ..showSnackBar(
      SnackBar(
        content: Text(
          texto,
          style: const TextStyle(
            color: Paleta.noche,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Paleta.lila,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
        // Para que se pueda echar de un manotazo sin esperar.
        dismissDirection: DismissDirection.horizontal,
        action: accion == null
            ? null
            : SnackBarAction(
                label: accion,
                textColor: Paleta.noche,
                onPressed: alAccionar ?? () {},
              ),
      ),
    );
}

/// La forma cómoda, cuando la pantalla que avisa sigue en pie.
///
/// Ojo: si vas a cerrar la pantalla antes de avisar, no sirve. Después de
/// un `Navigator.pop` el contexto ya no existe y buscar el mensajero
/// desde ahí falla o se lo pide a una pantalla equivocada, y el aviso
/// queda colgado sin que nadie lo apague. En ese caso, guardá el
/// mensajero *antes* de cerrar y usá [avisar].
void mostrarAviso(
  BuildContext context,
  String texto, {
  String? accion,
  VoidCallback? alAccionar,
}) {
  final mensajero = ScaffoldMessenger.maybeOf(context);
  if (mensajero == null) return;
  avisar(mensajero, texto, accion: accion, alAccionar: alAccionar);
}

/// Hoja de abajo para elegir dónde va un libro. Se usa desde el aviso de
/// "agregado" y desde la ficha.
Future<void> elegirEstado(BuildContext context, Libro libro) async {
  final elegido = await showModalBottomSheet<Estado>(
    context: context,
    backgroundColor: Paleta.nocheAlta,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Paleta.linea,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          for (final e in Estado.values)
            ListTile(
              title: Text(e.nombre, style: Tipo.cuerpo),
              trailing: libro.estado == e
                  ? const Icon(Icons.check_rounded, color: Paleta.lila)
                  : null,
              onTap: () => Navigator.of(context).pop(e),
            ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );

  if (elegido != null) await biblioteca.cambiarEstado(libro, elegido);
}

/// La grilla de tapas. La usan la biblioteca, los estantes y el perfil
/// de otra persona, así que vive acá y no dentro de una pantalla.
class GrillaLibros extends StatelessWidget {
  final List<Libro> libros;
  final ValueChanged<Libro> alTocar;

  /// Claves de los libros que se encienden en oro: los que compartís
  /// con la persona cuya biblioteca estás mirando.
  final Set<String> marcados;

  const GrillaLibros(
    this.libros, {
    super.key,
    required this.alTocar,
    this.marcados = const {},
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: libros.length,
      // Fijamos el ancho de cada tapa, no la cantidad de columnas: así
      // la grilla suma columnas sola cuando hay lugar —tres en un
      // teléfono, seis en un monitor— y las tapas nunca se agrandan.
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: Medidas.anchoDeTapa(context),
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
        childAspectRatio: 2 / 3,
      ),
      itemBuilder: (_, i) {
        final l = libros[i];
        return GestureDetector(
          onTap: () => alTocar(l),
          child: LayoutBuilder(
            builder: (_, c) =>
                Tapa(l, ancho: c.maxWidth, marcada: marcados.contains(l.clave)),
          ),
        );
      },
    );
  }
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
