import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'api.dart';
import 'cuenta.dart';
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
    final url = Api.tapaDe(libro, tamano: tamano);

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
            : Stack(
                fit: StackFit.expand,
                children: [
                  // Debajo de todo, la tapa dibujada: se ve al instante y
                  // hace que nunca haya un rectángulo vacío.
                  _TapaGenerada(libro, ancho: ancho),

                  // En la ficha pedimos la tapa grande, que es una
                  // descarga distinta a la de la grilla. Mientras llega,
                  // mostramos la mediana, que ya está en memoria de haber
                  // pasado por la lista: así abrir un libro es inmediato
                  // en vez de quedarse pensando.
                  if (tamano != 'M')
                    CachedNetworkImage(
                      imageUrl: Api.tapaDe(libro)!,
                      cacheManager: tapasGuardadas,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),

                  CachedNetworkImage(
                    imageUrl: url,
                    cacheManager: tapasGuardadas,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                    // Mientras baja no se pone nada: debajo ya está la tapa
                    // dibujada, y taparla con una rueda girando sería
                    // cambiar algo que se ve por algo que no dice nada.
                    placeholder: (_, _) => const SizedBox.shrink(),
                    // Sin esto la tapa aparece de golpe cuando termina de
                    // bajar, y el salto se nota más que la espera.
                    fadeInDuration: const Duration(milliseconds: 220),
                    fadeOutDuration: Duration.zero,
                  ),
                ],
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

/// Las cuatro cosas que se puntúan de un libro.
///
/// Miden cosas distintas y por eso conviven. Un libro puede ser flojo y
/// hacerte llorar igual, o ser romántico sin nada de picante: con una
/// sola nota todo eso se pierde.
enum Escala { estrellas, lagrimas, corazones, chiles }

extension DatosDeEscala on Escala {
  String get nombre => switch (this) {
    Escala.estrellas => 'Puntaje',
    Escala.lagrimas => 'Lágrimas',
    Escala.corazones => 'Romance',
    Escala.chiles => 'Picante',
  };

  String get pregunta => switch (this) {
    Escala.estrellas => '¿Qué tan bueno?',
    Escala.lagrimas => '¿Cuánto lloraste?',
    Escala.corazones => '¿Cuánto romance?',
    Escala.chiles => '¿Cuánto calienta?',
  };

  /// Cada escala tiene su color, y no es decoración: **el color nombra**.
  /// Una lágrima dorada no dice "lloré" y un corazón gris no dice
  /// "romance". Es la única excepción a la regla de que el oro es lo
  /// único cálido de la app.
  Color get color => switch (this) {
    Escala.estrellas => Paleta.oro,
    Escala.lagrimas => Paleta.agua,
    Escala.corazones => Paleta.rojo,
    Escala.chiles => Paleta.rojo,
  };
}

/// Una fila de cinco marcas que se tocan para puntuar.
///
/// Cada escala tiene su forma **y** su color: estrella dorada, lágrima
/// azul, corazón rojo y chile rojo con el cabito verde.
///
/// Es la única excepción a la regla de que el oro es lo único cálido, y
/// está bien que lo sea: acá el color no decora, nombra. Los tonos están
/// bajados de saturación para que no le peleen al oro ni a las tapas.
///
/// Lo que **no** cambia de color es el estado apagado: las cinco marcas
/// vacías van todas en gris. Así lo que se ve es cuánto puntuaste, no
/// cuántas escalas hay.
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
    final color = cuenta ? escala.color : Paleta.linea;

    if (escala == Escala.chiles) {
      return Chile(
        tamano: tamano,
        color: color,
        colorTallo: cuenta ? Paleta.verde : Paleta.linea,
        lleno: cuenta,
      );
    }

    return Icon(
      switch (escala) {
        Escala.estrellas =>
          cuenta ? Icons.star_rounded : Icons.star_outline_rounded,
        Escala.lagrimas =>
          cuenta ? Icons.water_drop_rounded : Icons.water_drop_outlined,
        Escala.corazones =>
          cuenta ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        // El chile se dibuja aparte, arriba: acá no llega nunca.
        Escala.chiles => Icons.circle,
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
  const duracion = Duration(seconds: 3);

  // clearSnackBars y no hideCurrentSnackBar.
  //
  // Los avisos hacen cola: si mostrás tres seguidos, el segundo espera a
  // que termine el primero y el tercero al segundo. `hide` solo baja el
  // que está y deja pasar al siguiente, así que parecía que el cartel no
  // se iba nunca cuando en realidad eran varios en fila. `clear` vacía la
  // cola entera: siempre se ve el último y nada más.
  mensajero.clearSnackBars();

  final control = mensajero.showSnackBar(
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
      duration: duracion,
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

  // Red de seguridad.
  //
  // El temporizador que trae Flutter arranca recién cuando termina la
  // animación de entrada del cartel. Si esa animación se interrumpe
  // —algo muy fácil de provocar cuando la pantalla se redibuja justo en
  // ese momento— el temporizador nunca arranca y el aviso se queda para
  // siempre. Este cierra ese cartel puntual, así que si mientras tanto
  // apareció otro, no lo toca.
  Timer(duracion + const Duration(milliseconds: 500), () {
    try {
      control.close();
    } catch (_) {
      // ya se había ido, y está perfecto
    }
  });
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
/// Cambiar el estado de un libro que ya estás mirando.
///
/// Se parece a [dondeVa] pero **no es lo mismo y no hay que fusionarlas**:
/// esta llama a `cambiarEstado` sin condición, y ahí tocar dos veces el
/// mismo estado lo devuelve a pendientes. Eso es una función pedida —
/// marcar «leído» sin querer y poder deshacerlo— y solo tiene sentido acá,
/// donde estás dentro del libro. En una lista de resultados, volver a
/// tocar el estante en el que ya está se lee como «sí, ahí está bien», y
/// sacarlo sería un accidente.
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

/// Dónde se guardan las tapas para no bajarlas de nuevo.
///
/// # El problema, medido
///
/// Una tapa de la grilla pesa 25 KB y la de la ficha 68 KB. Los servidores
/// las dan con permiso de guardarlas **tres horas**, y sin `etag`: cuando
/// se vencen no hay forma de preguntar «¿sigue igual?», hay que bajarlas
/// enteras otra vez. Con sesenta libros eso es un mega y medio cada vez.
///
/// Y en el teléfono es peor, porque Flutter solo las guarda en memoria:
/// cerrás la app y se pierden todas. Abrir la biblioteca en el colectivo
/// costaba la descarga completa, cada vez.
///
/// # Por qué treinta días y no tres horas
///
/// Las tres horas las decide el servidor, y para un servidor es una
/// decisión razonable: no sabe qué le vas a pedir. Pero nosotros sí
/// sabemos qué estamos pidiendo, y **la tapa de un libro no cambia**. Si
/// alguna vez cambia —porque elegiste otra edición— cambia la dirección,
/// no la imagen, así que no hay nada viejo que se pueda quedar pegado.
///
/// # Lo que esto no arregla
///
/// **En el navegador no cambia nada.** El paquete guarda en disco en
/// iPhone, Android y escritorio, pero en web usa memoria y nada sobrevive
/// a recargar la página. Lo dice su propio código: en web el
/// almacenamiento es `MemoryCacheSystem`. Ahí seguimos dependiendo de las
/// tres horas del navegador.
final tapasGuardadas = CacheManager(
  Config(
    'colibri.tapas',
    stalePeriod: const Duration(days: 30),
    // Quinientas tapas a 25 KB son unos doce megas. Una biblioteca de
    // quinientos libros es mucha biblioteca, y doce megas en el teléfono
    // no son nada.
    maxNrOfCacheObjects: 500,
    fileService: _bajadorDeTapas,
  ),
);

/// Cuántas tapas se bajan al mismo tiempo.
///
/// El paquete trae 10 de fábrica, y con una grilla de 24 tapas eso son dos
/// tandas: la segunda arranca cuando termina la primera. Medido contra el
/// servidor de Open Library, con 24 tapas:
///
///     de a una       32,1 s
///     10 a la vez     2,6 s   <- lo que hacía antes
///     24 a la vez     2,3 s
///
/// La diferencia es chica porque las tapas pesan poco —20 KB— y el cuello
/// es la latencia, no el ancho de banda. Pero es gratis, y en una conexión
/// de celular, donde cada viaje cuesta más, la diferencia crece.
///
/// No se sube más: la idea no es abrir cien conexiones al mismo servidor,
/// que es una forma de hacerse bloquear —ya nos devolvió un 503 midiendo—.
/// 24 es lo que entra en una pantalla.
final _bajadorDeTapas = HttpFileService()..concurrentFetches = 24;

/// La cara de alguien, dibujada.
///
/// # Por qué no se sube una foto
///
/// Guardar fotos necesita un lugar donde guardarlas, y eso es servidor y
/// plata. Pero además: una app de lectura no necesita caras. Lo que sí
/// necesita es que dos personas se distingan de un vistazo, y para eso
/// alcanza con una letra y un color.
///
/// El color sale del @usuario, siempre el mismo. Si cambiara en cada
/// arranque, tu cara en la app sería otra cada vez que abrís.
class Avatar extends StatelessWidget {
  final Perfil perfil;
  final double tamano;

  const Avatar(this.perfil, {super.key, this.tamano = 44});

  @override
  Widget build(BuildContext context) {
    // El decodificado va afuera del widget y adentro de un try.
    //
    // `errorBuilder` atrapa una imagen que no se puede dibujar, pero acá
    // lo que falla primero es pasar el texto guardado a bytes, y eso
    // rompe **antes** de que haya widget. Lo encontró una prueba con un
    // texto que no era una foto: la pantalla del perfil se caía entera.
    final bytes = _bytesDe(perfil.foto);

    if (bytes != null) {
      return ClipOval(
        child: SizedBox(
          width: tamano,
          height: tamano,
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            // Y esta sigue haciendo falta, para el otro caso: bytes que
            // se leen bien pero no son una imagen.
            errorBuilder: (_, _, _) => _Inicial(perfil, tamano: tamano),
          ),
        ),
      );
    }
    return _Inicial(perfil, tamano: tamano);
  }

  static Uint8List? _bytesDe(String? guardado) {
    if (guardado == null) return null;
    try {
      return base64Decode(guardado);
    } catch (_) {
      return null;
    }
  }
}

/// El avatar dibujado, para cuando no hay foto.
class _Inicial extends StatelessWidget {
  final Perfil perfil;
  final double tamano;

  const _Inicial(this.perfil, {required this.tamano});

  @override
  Widget build(BuildContext context) {
    // Se queda del lado violeta de la rueda, entre el lila de la casa y el
    // azul: un avatar verde o naranja rompería la paleta entera.
    final color = HSLColor.fromAHSL(
      1,
      210 + perfil.tono * 80, // de azul a violeta
      0.34,
      0.62,
    ).toColor();

    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        border: Border.all(color: color, width: 1.5),
        shape: BoxShape.circle,
      ),
      child: Text(
        perfil.inicial,
        style: TextStyle(
          color: color,
          fontSize: tamano * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// El estante donde está un libro, para tocar y moverlo.
///
/// Lo usan la búsqueda y el escáner, que son los dos lugares donde se
/// cargan libros de a muchos y donde hace falta ver de un vistazo dónde
/// quedó cada uno. Vive acá para que los dos se vean igual: si en una
/// pantalla fuera un botón y en la otra un texto, habría que aprender dos
/// veces lo mismo.
class ChipDeEstante extends StatelessWidget {
  final Estado estado;
  final VoidCallback alTocar;

  const ChipDeEstante(this.estado, {super.key, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Moverlo o sacarlo',
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: const Color(0x22B9A6E6),
            border: Border.all(color: Paleta.lila),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_rounded, size: 14, color: Paleta.lila),
              const SizedBox(width: 5),
              Text(
                estado.nombre,
                style: const TextStyle(
                  fontSize: 12,
                  color: Paleta.lila,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Elegir dónde va un libro, desde una lista de resultados.
///
/// # Por qué no alcanza con un más que suma a pendientes
///
/// Cuando alguien busca un libro suelto, mandarlo a pendientes y ofrecer
/// cambiarlo después está bien. Cuando está cargando veinte de una, no:
/// los avisos hacen cola, se pisan, y al tercero ya no sabés cuál era el
/// que querías mover.
///
/// Así que se pregunta antes. Dos toques por libro, y ninguna duda.
///
/// # Por qué muestra el título
///
/// Porque en una lista de veinte resultados parecidos, una hoja que dice
/// «¿Dónde lo ponés?» sin decir qué es «lo» obliga a cerrarla para
/// fijarse.
///
/// Devuelve `true` si algo cambió, para que la fila se vuelva a dibujar.
Future<bool> dondeVa(BuildContext context, Libro libro) async {
  final yaEsta = biblioteca.tiene(libro);
  final guardado = biblioteca.buscarPorClave(libro.clave) ?? libro;

  final elegido = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: Paleta.nocheAlta,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Paleta.linea,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  yaEsta ? 'Moverlo a' : '¿Dónde lo ponés?',
                  style: Tipo.subtitulo,
                ),
                const SizedBox(height: 4),
                Text(
                  libro.titulo,
                  style: Tipo.meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final e in Estado.values)
            ListTile(
              title: Text(e.nombre, style: Tipo.cuerpo),
              trailing: yaEsta && guardado.estado == e
                  ? const Icon(Icons.check_rounded, color: Paleta.lila)
                  : null,
              onTap: () => Navigator.of(context).pop(e),
            ),
          if (yaEsta) ...[
            const Divider(color: Paleta.linea, height: 1),
            ListTile(
              title: Text(
                'Sacarlo de mi biblioteca',
                style: Tipo.cuerpo.copyWith(color: Paleta.bruma),
              ),
              onTap: () => Navigator.of(context).pop(#sacar),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    ),
  );

  if (elegido == null) return false;

  if (elegido == #sacar) {
    await biblioteca.quitar(guardado);
    return true;
  }

  final estado = elegido as Estado;

  if (!yaEsta) {
    await biblioteca.agregar(libro);
    // Se agrega primero y se mueve después, en vez de nacer ya con el
    // estado puesto: así pasa por cambiarEstado, que es quien anota la
    // fecha de cuándo lo empezaste o lo terminaste.
    if (estado != Estado.pendiente) {
      await biblioteca.cambiarEstado(libro, estado);
    }
  } else if (guardado.estado != estado) {
    await biblioteca.cambiarEstado(guardado, estado);
  }
  return true;
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
    // LayoutBuilder y no MediaQuery: hace falta el ancho que esta grilla
    // tiene de verdad, no el de la pantalla. Ver
    // [Medidas.columnasParaAncho].
    return LayoutBuilder(
      builder: (context, medidas) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: libros.length,
        // Fijamos las columnas y no el ancho de la tapa. Al revés —que
        // era como estaba— las tapas se achicaban cuando la pantalla
        // crecía.
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Medidas.columnasParaAncho(medidas.maxWidth),
          crossAxisSpacing: 10,
          mainAxisSpacing: 14,
          // 0,52 y no 2/3: la tapa sola es 2/3, y abajo van el título y
          // las estrellas. Sin este aire, la celda le queda corta y el
          // renglón de abajo se corta con las rayas de error.
          childAspectRatio: 0.52,
        ),
        itemBuilder: (_, i) {
          final l = libros[i];
          return GestureDetector(
            onTap: () => alTocar(l),
            child: LayoutBuilder(
              builder: (_, c) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tapa(
                    l,
                    ancho: c.maxWidth,
                    marcada: marcados.contains(l.clave),
                  ),
                  const SizedBox(height: 5),
                  // El título debajo de la tapa.
                  //
                  // Una grilla de tapas sin nombre obliga a abrir cada una
                  // para saber qué es, y con veinte libros eso es veinte
                  // toques. Ya estaba así en Descubrir, donde se probó que
                  // se puede decidir mirando; en los estantes faltaba.
                  //
                  // Dos renglones: los títulos largos —«Harry Potter y la
                  // Orden del Fénix»— no entran en uno a este ancho, y
                  // cortarlos en «Harry Potter y la…» los deja sin decir
                  // cuál es.
                  Text(
                    l.titulo,
                    style: Tipo.meta.copyWith(fontSize: 10.5, height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Las estrellas solo si puntuaste. Cinco estrellas
                  // apagadas en cada libro sin puntaje se leen como un
                  // cero, y no es cero: es que todavía no dijiste nada.
                  if (l.puntaje > 0) ...[
                    const SizedBox(height: 3),
                    Estrellas(l.puntaje, tamano: 10),
                  ],
                ],
              ),
            ),
          );
        },
      ),
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
