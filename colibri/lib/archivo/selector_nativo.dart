import 'package:file_picker/file_picker.dart';

import 'archivo_elegido.dart';

/// En Android, iPhone y escritorio, file_picker anda bien: abre el
/// explorador del sistema y devuelve los bytes.
///
/// Sin filtro de extensión a propósito. Con `FileType.custom` el sistema
/// esconde o apaga archivos válidos —en iOS el filtro va por UTI y no por
/// extensión— y queda una pantalla donde no se puede elegir nada.
/// Preferimos dejar elegir cualquiera y validar en la app, que además nos
/// deja explicar qué pasó cuando no sirve.
/// [acepta] es una sugerencia para el navegador y acá no se usa: en
/// nativo elegimos cualquier archivo y validamos en la app, por lo que
/// explica el comentario de arriba.
Future<ArchivoElegido?> elegirArchivo({String acepta = ''}) async {
  final elegido = await FilePicker.pickFiles(
    type: FileType.any,
    withData: true, // los bytes, en memoria y nada más
  );

  final archivo = elegido?.files.singleOrNull;
  final bytes = archivo?.bytes;
  if (archivo == null || bytes == null) return null;

  return ArchivoElegido(nombre: archivo.name, bytes: bytes);
}
