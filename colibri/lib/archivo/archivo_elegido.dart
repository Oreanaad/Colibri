/// Un archivo elegido: el nombre y los bytes. Nada más, y a propósito.
///
/// No guardamos la ruta al archivo original ni una referencia a él: apenas
/// se le saca el texto, estos bytes se sueltan y no queda nada.
class ArchivoElegido {
  final String nombre;
  final List<int> bytes;

  const ArchivoElegido({required this.nombre, required this.bytes});

  bool get esEpub => nombre.toLowerCase().endsWith('.epub');
  bool get esPdf => nombre.toLowerCase().endsWith('.pdf');
}
