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
