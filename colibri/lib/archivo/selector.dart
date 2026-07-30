/// Elegir un archivo del teléfono.
///
/// Hay dos implementaciones y Dart elige sola según dónde corre la app.
/// Eso se llama *importación condicional*: es la forma de tener código
/// distinto por plataforma sin llenar todo de `if (kIsWeb)`.
///
/// # Por qué en la web no usamos file_picker
///
/// Su implementación web agrega un `<input type="file">` al documento, le
/// hace click y **lo borra del documento en la misma vuelta**:
///
/// ```dart
/// _target.children.add(uploadInput);
/// uploadInput.click();
/// _target.removeChild(firstChild);   // ya no está
/// ```
///
/// En Chrome de escritorio zafa, porque el diálogo alcanza a abrirse. En
/// Safari de iPhone no: el input queda desconectado del documento y el
/// selector no devuelve nada, o directamente falla.
///
/// Encima activa por defecto una heurística que cancela la elección cuando
/// la ventana recupera el foco — y en iOS abrir el selector produce
/// justamente un blur y un focus, así que se cancela sola.
///
/// Nuestra versión web mantiene el input en el documento hasta terminar.
/// En Android y iPhone nativos file_picker anda bien, así que ahí lo
/// seguimos usando.
library;

export 'archivo_elegido.dart';
export 'selector_nativo.dart' if (dart.library.js_interop) 'selector_web.dart';
