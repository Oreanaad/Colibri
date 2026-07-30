import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'archivo_elegido.dart';

/// Selector de archivos propio para la web.
///
/// Escrito a mano porque el de file_picker no funciona en Safari de
/// iPhone: agrega el `<input type="file">`, le hace click y lo borra del
/// documento en la misma vuelta. Un input desconectado no devuelve nada.
///
/// Acá el input se queda en el documento hasta que la elección termina.
/// Es la diferencia entera.
Future<ArchivoElegido?> elegirArchivo() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    // El accept es una sugerencia, no un filtro: iOS igual deja elegir
    // cualquier cosa, y la validación de verdad la hacemos nosotras.
    ..accept = '.epub,application/epub+zip'
    ..multiple = false
    // Escondido pero presente. `display: none` hace que algunos
    // navegadores ignoren el click, así que lo sacamos de la vista
    // moviéndolo, que funciona en todos.
    ..style.position = 'fixed'
    ..style.left = '-10000px'
    ..style.opacity = '0';

  web.document.body!.append(input);

  final resultado = Completer<ArchivoElegido?>();

  void terminar(ArchivoElegido? archivo) {
    if (!resultado.isCompleted) resultado.complete(archivo);
    input.remove(); // recién ahora, cuando ya no hace falta
  }

  // El que escucha tiene que devolver void: JavaScript no sabe qué hacer
  // con un Future de Dart, y convertir una función `async` con .toJS no
  // compila. Así que el listener llama a la lectura y no la espera.
  Future<void> leerArchivo() async {
    final archivos = input.files;
    final archivo = (archivos == null || archivos.length == 0)
        ? null
        : archivos.item(0);

    if (archivo == null) {
      terminar(null);
      return;
    }

    try {
      // arrayBuffer() devuelve una promesa de JavaScript; toDart la
      // convierte en algo que Dart sabe esperar.
      final buffer = await archivo.arrayBuffer().toDart;
      terminar(ArchivoElegido(
        nombre: archivo.name,
        bytes: buffer.toDart.asUint8List(),
      ));
    } catch (_) {
      terminar(null);
    }
  }

  input.addEventListener(
    'change',
    ((web.Event _) => unawaited(leerArchivo())).toJS,
  );

  // Cuando la persona cancela. No todos los navegadores lo mandan, así
  // que abajo hay un plan B.
  input.addEventListener('cancel', ((web.Event _) => terminar(null)).toJS);

  input.click();

  // Plan B para cancelar: si vuelve el foco a la página y pasado un rato
  // no llegó ningún archivo, damos la elección por cancelada. Sin esto,
  // en los navegadores que no mandan 'cancel' la app se queda esperando
  // para siempre con el reloj girando.
  //
  // El retraso inicial es necesario: abrir el selector ya produce un
  // blur y un focus, y sin esperar se cancelaría sola al instante.
  unawaited(Future<void>.delayed(const Duration(seconds: 1)).then((_) {
    if (resultado.isCompleted) return;
    late final JSFunction alVolverElFoco;
    alVolverElFoco = ((web.Event _) {
      web.window.removeEventListener('focus', alVolverElFoco);
      Future<void>.delayed(const Duration(seconds: 2)).then((_) {
        if (!resultado.isCompleted) terminar(null);
      });
    }).toJS;
    web.window.addEventListener('focus', alVolverElFoco);
  }));

  return resultado.future;
}
