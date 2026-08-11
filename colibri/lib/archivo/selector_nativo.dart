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
/// # Menos las fotos
///
/// La única excepción es cuando lo que se pide es una imagen, y no es por
/// filtrar: es porque en el iPhone son dos pantallas distintas. Con
/// `FileType.any` se abre **Archivos**, y el carrete de fotos no está
/// ahí; el iPhone no lo muestra como carpeta. Alguien buscando su foto de
/// perfil recorría iCloud sin encontrar ninguna de sus fotos.
///
/// Con `FileType.image` se abre el carrete, que es donde están. En iOS 14
/// y de ahí para arriba eso es el selector nuevo, que ni siquiera pide
/// permiso porque la app nunca ve la biblioteca: recibe la foto elegida y
/// nada más.
///
/// [acepta] es la sugerencia que usa la versión web —un `accept` de
/// HTML—. Acá alcanza con saber si eso menciona imágenes.
Future<ArchivoElegido?> elegirArchivo({String acepta = ''}) async {
  final quiereUnaFoto = acepta.contains('image');

  final elegido = await FilePicker.pickFiles(
    type: quiereUnaFoto ? FileType.image : FileType.any,
    withData: true, // los bytes, en memoria y nada más
  );

  final archivo = elegido?.files.singleOrNull;
  final bytes = archivo?.bytes;
  if (archivo == null || bytes == null) return null;

  return ArchivoElegido(nombre: archivo.name, bytes: bytes);
}
