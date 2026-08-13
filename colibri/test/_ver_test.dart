import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/compartir_resena.dart';

void main() {
  testWidgets('dibujar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final l = Libro(
      id: '1', titulo: 'Fuego y sangre', autor: 'George R. R. Martin',
      anio: 2018, paginas: 880, estado: Estado.leido,
      puntaje: 5, lagrimas: 2, romantico: 1, picante: 3,
      empezado: DateTime(2025, 12, 24), terminado: DateTime(2026, 3, 25),
      resena: 'Una narrativa muy buena con historias y personajes increíbles. '
          'Conocer de cerca la dinastía Targaryen te da otro punto de vista de '
          'la canción de hielo y fuego, nunca volverás a ver GOT igual después '
          'de este libro. Es fantasía cruda y satírica, todo eso mezclado con '
          'dragones, veneno, conquistas, traiciones y muchas (pero muchas) '
          'muertes.',
      animos: ['no pude parar', 'me dejó pensando'],
    );

    final llave = GlobalKey();
    for (final (fondo, nombre) in [
      (FondoDeResena.noche, 'noche'),
      (FondoDeResena.papel, 'papel'),
      (FondoDeResena.oro, 'oro'),
    ]) {
      await tester.binding.setSurfaceSize(const Size(420, 800));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
        child: SizedBox(width: 360, height: 640,
          child: RepaintBoundary(key: llave,
            child: PlacaDeResena(libro: l, fondo: fondo)))))));
      await tester.pumpAndSettle();

      final r = llave.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await r.toImage(pixelRatio: 2);
      final d = await img.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/placa-$nombre.png').writeAsBytesSync(d!.buffer.asUint8List());
    }
    await tester.binding.setSurfaceSize(null);
  });
}
