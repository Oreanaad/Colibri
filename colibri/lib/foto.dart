import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Preparar una foto para que sea un avatar.
///
/// # Por qué no se guarda la foto tal cual
///
/// Una foto de teléfono pesa cuatro megas y tiene tres mil píxeles de
/// lado. El avatar más grande que muestra la app mide sesenta y dos.
/// Guardarla entera sería:
///
/// - reventar el guardado del navegador, que da unos cinco megas para
///   toda la app —los libros, las frases y todo lo demás—;
/// - gastar datos de la persona para nada;
/// - y hacer que la pantalla tarde en dibujar algo que se ve del tamaño
///   de una uña.
///
/// # Los números, medidos y no elegidos a ojo
///
/// A 256 píxeles de lado, un JPEG de calidad media pesa unos 16 KB, y
/// guardado como texto —que es como entra en el teléfono— unos 21 KB.
/// A 512 serían 85 KB, cuatro veces más, para un avatar que nunca se ve
/// a más de 62 puntos. A 128 empieza a verse blando en pantallas buenas.
///
/// 256 es el número que se ve nítido en cualquier pantalla y no molesta.
class Foto {
  /// El lado del cuadrado que se guarda.
  static const lado = 256;

  /// Calidad del JPEG. Ochenta y dos es donde la cuenta deja de mejorar:
  /// más arriba pesa bastante más y no se nota, más abajo se ensucian los
  /// bordes de la cara.
  static const calidad = 82;

  /// Deja una foto lista para ser avatar, o null si eso no era una foto.
  ///
  /// Recorta al cuadrado por el centro, la lleva a [lado] y la guarda como
  /// JPEG. Devuelve null en vez de romper: la persona eligió un archivo
  /// del teléfono y bien puede haber elegido cualquier cosa.
  /// Recibe `List<int>` y no `Uint8List` porque es lo que da el selector
  /// de archivos, y convertirlo del lado de quien llama sería pedirle que
  /// sepa un detalle que no le importa.
  static Uint8List? paraAvatar(List<int> bytes) {
    // Con un archivo que no es una imagen, `decodeImage` **rompe** en vez
    // de devolver nada: mira los primeros bytes para adivinar el formato
    // y con un archivo vacío se pasa del final. Lo encontró una prueba, y
    // es exactamente lo que pasa cuando alguien abre el explorador de su
    // teléfono y elige cualquier cosa.
    final img.Image? original;
    try {
      original = img.decodeImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
    if (original == null) return null;

    // Las fotos de teléfono suelen venir derechas pero con una nota
    // aparte que dice «esto va girado noventa grados». Sin esto, media
    // app aparece acostada.
    final derecha = img.bakeOrientation(original);

    // Cuadrado por el centro. Recortar y no deformar: una cara estirada
    // para que entre en un cuadrado se ve mal de una forma difícil de
    // explicar pero imposible de no notar.
    final corte = min(derecha.width, derecha.height);
    final cuadrada = img.copyCrop(
      derecha,
      x: (derecha.width - corte) ~/ 2,
      y: (derecha.height - corte) ~/ 2,
      width: corte,
      height: corte,
    );

    // `average` y no el más rápido: al achicar mucho, el rápido se saltea
    // píxeles y deja bordes con escalones.
    final chica = img.copyResize(
      cuadrada,
      width: lado,
      height: lado,
      interpolation: img.Interpolation.average,
    );

    return img.encodeJpg(chica, quality: calidad);
  }
}

/// Preparar la foto del lomo de un libro.
///
/// # Por qué no sirve [Foto.paraAvatar]
///
/// Porque recorta al cuadrado, y un lomo es todo lo contrario: alto y
/// angosto. Recortarlo al cuadrado se comería el título, que es lo único
/// que hay que ver.
///
/// # Los números
///
/// El lomo más ancho que dibuja la app mide 44 puntos, y en una pantalla de
/// tres veces son 132 píxeles. Se guarda a 160 de ancho: alcanza para que
/// se vea nítido y no sobra tanto como para pesar.
///
/// El alto sale de la foto y no se toca. Cada libro tiene la proporción que
/// tiene, y forzarla a una fija sería deformar justamente lo que la persona
/// fue a fotografiar.
class FotoDeLomo {
  static const ancho = 160;
  static const calidad = 82;

  /// Deja la foto lista, o null si eso no era una foto.
  static Uint8List? preparar(List<int> bytes) {
    final img.Image? original;
    try {
      original = img.decodeImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
    if (original == null) return null;

    // Las fotos de teléfono vienen con una nota aparte que dice cómo van
    // giradas. Sin esto, media foto de lomo aparece acostada.
    final derecha = img.bakeOrientation(original);

    // Una foto más angosta que el destino no se agranda: agrandar no suma
    // detalle, solo peso y borrosidad.
    final chica = derecha.width <= ancho
        ? derecha
        : img.copyResize(
            derecha,
            width: ancho,
            interpolation: img.Interpolation.average,
          );

    return img.encodeJpg(chica, quality: calidad);
  }

  /// El color que más manda en una imagen.
  ///
  /// # Para qué
  ///
  /// Para que el lomo dibujado de un libro se parezca a su tapa. Ningún
  /// catálogo publica fotos de lomos —se comprobó: Open Library solo tiene
  /// tapas de frente y `spine` contesta 404— así que lo más cerca que se
  /// puede estar de «que la app lo busque sola» es sacarle el color a la
  /// tapa, que sí existe.
  ///
  /// # Cómo se elige
  ///
  /// Se agrupan los píxeles por tono redondeado y gana el grupo más
  /// numeroso. No el promedio: el promedio de una tapa roja con letras
  /// blancas es rosa, y el de una tapa de dos colores es un color que no
  /// está en la tapa.
  ///
  /// Se saltean los píxeles casi blancos y casi negros. Casi todas las
  /// tapas tienen mucho de los dos —fondos y texto— y ganarían siempre,
  /// dejando todos los lomos grises.
  ///
  /// Después se lleva a una luz oscura y una saturación media: un lomo
  /// tiene que ser oscuro para que el título blanco se lea encima, y las
  /// encuadernaciones de verdad son apagadas.
  static int? colorQueManda(List<int> bytes) {
    final img.Image? original;
    try {
      original = img.decodeImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
    if (original == null) return null;

    // A 48 de ancho antes de contar: una tapa de 180x270 son cincuenta mil
    // píxeles, y contar cincuenta mil para elegir un color es tiempo
    // regalado. Con 48 el color que manda es el mismo.
    final chica = img.copyResize(original, width: 48);
    final cuenta = <int, int>{};

    for (var y = 0; y < chica.height; y++) {
      for (var x = 0; x < chica.width; x++) {
        final p = chica.getPixel(x, y);
        final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();

        final maximo = max(r, max(g, b));
        final minimo = min(r, min(g, b));
        if (maximo > 236 || maximo < 26) continue; // casi blanco o casi negro
        if (maximo - minimo < 18) continue; // gris: no dice nada del libro

        // Redondeado de a 32: sin esto, dos rojos que el ojo ve iguales
        // cuentan como dos colores distintos y ninguno gana.
        final clave = (r ~/ 32) * 64 + (g ~/ 32) * 8 + (b ~/ 32);
        cuenta[clave] = (cuenta[clave] ?? 0) + 1;
      }
    }

    if (cuenta.isEmpty) return null; // una tapa en blanco y negro

    var mejor = cuenta.keys.first;
    for (final e in cuenta.entries) {
      if (e.value > (cuenta[mejor] ?? 0)) mejor = e.key;
    }

    // Del grupo se vuelve al centro de su casilla.
    final r = (mejor ~/ 64) * 32 + 16;
    final g = ((mejor % 64) ~/ 8) * 32 + 16;
    final b = (mejor % 8) * 32 + 16;

    return 0xFF000000 | (r << 16) | (g << 8) | b;
  }
}
