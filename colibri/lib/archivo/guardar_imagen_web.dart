import 'dart:js_interop';
// Para preguntarle a JavaScript si tiene una función antes de llamarla.
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Guardar la placa desde el navegador.
///
/// # Por qué no alcanza con compartir
///
/// El menú de compartir del navegador (`navigator.share`) **solo existe
/// en sitios seguros**: HTTPS o localhost. Mientras probás la app desde
/// otra máquina de tu casa —`http://192.168.x.x:8080`— no existe, y el
/// intento de usarlo tira un error. Por eso "no se podía descargar".
///
/// Así que: si el menú del sistema está disponible, lo usamos; si no,
/// bajamos el archivo, que funciona siempre y en todos lados.
Future<bool> guardarImagen(
  Uint8List bytes, {
  required String nombre,
  String? texto,
}) async {
  // Un Blob es un archivo que vive en la memoria del navegador. Lo
  // creamos una vez y lo usamos para las dos vías.
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );

  if (await _compartirConElSistema(blob, nombre, texto)) return true;

  _bajarArchivo(blob, nombre);
  return true;
}

/// El menú nativo de compartir, cuando el navegador lo tiene.
///
/// Hay que preguntar dos cosas: si existe, y si acepta archivos. Muchos
/// navegadores comparten texto pero no imágenes, y ahí conviene bajarla.
Future<bool> _compartirConElSistema(
  web.Blob blob,
  String nombre,
  String? texto,
) async {
  try {
    final navegador = web.window.navigator as JSObject;
    if (!navegador.has('share') || !navegador.has('canShare')) return false;

    final archivo = web.File(
      [blob].toJS,
      nombre,
      web.FilePropertyBag(type: 'image/png'),
    );

    final datos = JSObject()
      ..setProperty('files'.toJS, [archivo].toJS)
      ..setProperty('text'.toJS, (texto ?? '').toJS);

    final puede = navegador.callMethod<JSBoolean>('canShare'.toJS, datos);
    if (!puede.toDart) return false;

    await (navegador.callMethod<JSPromise>('share'.toJS, datos)).toDart;
    return true;
  } catch (_) {
    // Si la persona cancela también cae acá. Bajar el archivo igual no
    // molesta: queda en Descargas y listo.
    return false;
  }
}

/// La descarga de toda la vida: un enlace invisible al que se le hace
/// click. Funciona en cualquier navegador y sin sitio seguro.
void _bajarArchivo(web.Blob blob, String nombre) {
  final url = web.URL.createObjectURL(blob);

  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre
    ..style.display = 'none';

  web.document.body!.append(enlace);
  enlace.click();
  enlace.remove();

  // La dirección del blob ocupa memoria hasta que se suelta. Esperamos
  // un momento porque soltarla antes de que arranque la descarga la
  // cancela.
  Future<void>.delayed(
    const Duration(seconds: 30),
  ).then((_) => web.URL.revokeObjectURL(url));
}
