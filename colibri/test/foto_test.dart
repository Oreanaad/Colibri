import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:colibri/foto.dart';

/// Preparar una foto para que sea avatar.
///
/// Una foto de teléfono pesa cuatro megas y el avatar más grande de la app
/// mide sesenta y dos puntos. Todo lo de acá abajo es que esa diferencia
/// no rompa nada.
void main() {
  /// Una foto de mentira, del tamaño que se le pida.
  Uint8List inventar(int ancho, int alto) {
    final i = img.Image(width: ancho, height: alto);
    for (var y = 0; y < alto; y++) {
      for (var x = 0; x < ancho; x++) {
        i.setPixelRgb(x, y, (x * 255) ~/ ancho, (y * 255) ~/ alto, 120);
      }
    }
    return Uint8List.fromList(img.encodeJpg(i));
  }

  group('el tamaño', () {
    test('sale cuadrada de 256, venga como venga', () {
      for (final medida in [
        (3024, 4032),
        (4032, 3024),
        (500, 500),
        (80, 200),
      ]) {
        final salida = Foto.paraAvatar(inventar(medida.$1, medida.$2))!;
        final leida = img.decodeImage(salida)!;

        expect(leida.width, 256, reason: 'entrando ${medida.$1}×${medida.$2}');
        expect(leida.height, 256);
      }
    });

    test('una foto de teléfono entera queda en unos 20 KB', () {
      // El número que decide si esto se puede guardar en el teléfono. Una
      // foto de 3024×4032 pesa megas; acá tiene que salir del orden de
      // los kilobytes.
      final salida = Foto.paraAvatar(inventar(3024, 4032))!;

      expect(salida.length, lessThan(60 * 1024), reason: '${salida.length} B');
      // Guardada como texto ocupa un tercio más, y eso también tiene que
      // entrar en los cinco megas que da el navegador para toda la app.
      expect(salida.length * 4 / 3, lessThan(80 * 1024));
    });

    test('una chiquita no se agranda de más ni se rompe', () {
      final salida = Foto.paraAvatar(inventar(80, 80))!;

      expect(img.decodeImage(salida)!.width, 256);
    });
  });

  group('el recorte', () {
    test('recorta al centro en vez de deformar', () {
      // Una cara estirada para que entre en un cuadrado se ve mal de una
      // forma difícil de explicar e imposible de no notar. Se comprueba
      // mirando el color: la imagen inventada va de oscuro a claro de
      // izquierda a derecha, así que si recortó por el centro, el borde
      // izquierdo del resultado ya no es el más oscuro de todos.
      final ancha = inventar(1000, 200);
      final salida = img.decodeImage(Foto.paraAvatar(ancha)!)!;

      final izquierda = salida.getPixel(2, 128).r;
      expect(
        izquierda,
        greaterThan(60),
        reason: 'si fuera casi 0, tomó desde el borde y no desde el centro',
      );
    });
  });

  group('lo que no es una foto', () {
    test('devuelve nada en vez de romper', () {
      // La persona abrió el explorador de su teléfono y puede haber
      // elegido cualquier cosa.
      for (final basura in [
        Uint8List(0),
        Uint8List.fromList([1, 2, 3, 4, 5]),
        Uint8List.fromList('esto es un texto, no una foto'.codeUnits),
      ]) {
        expect(Foto.paraAvatar(basura), isNull);
      }
    });
  });

  group('el formato', () {
    test('sale siempre como JPEG', () {
      // Aunque entre un PNG. Un PNG de una foto pesa varias veces más que
      // el JPEG equivalente y acá lo que importa es el peso.
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 90, height: 90)),
      );
      final salida = Foto.paraAvatar(png)!;

      // Los JPEG empiezan con estos dos bytes, siempre.
      expect(salida[0], 0xFF);
      expect(salida[1], 0xD8);
    });
  });
}
