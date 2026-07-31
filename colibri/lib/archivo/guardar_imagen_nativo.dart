import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// En Android y iPhone se abre el menú del sistema: mandar por WhatsApp,
/// subir a Instagram, guardar en la galería. Eso es lo que la gente
/// espera, y lo resuelve el sistema, no nosotras.
Future<bool> guardarImagen(
  Uint8List bytes, {
  required String nombre,
  String? texto,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: nombre)],
      fileNameOverrides: [nombre],
      text: texto,
    ),
  );
  return true;
}
