/// Sacar una imagen de la app y dejarla en el teléfono o la computadora.
///
/// Como con el selector de archivos, hay dos implementaciones y Dart
/// elige sola según dónde corre la app:
///
/// - En Android y iPhone se abre el menú de compartir del sistema.
/// - En la web se baja el archivo, porque el menú de compartir del
///   navegador solo existe en sitios seguros y mientras probás desde
///   otra máquina de tu casa no lo es.
library;

export 'guardar_imagen_nativo.dart'
    if (dart.library.js_interop) 'guardar_imagen_web.dart';
