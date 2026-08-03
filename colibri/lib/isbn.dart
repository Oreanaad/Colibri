/// Los códigos de barras de la contratapa.
///
/// # Qué es lo que se lee
///
/// El código de barras de un libro es un EAN-13: trece dígitos. Los tres
/// primeros dicen de qué familia de productos es, y ahí está casi todo lo
/// que necesitamos saber:
///
/// - **978 y 979** son libros. Ese número existe justamente para eso: en
///   los años setenta la industria del libro le pidió un prefijo propio al
///   sistema de códigos de barras, y se lo dieron. Un ISBN de trece
///   dígitos *es* un EAN-13 que empieza con 978 o 979.
/// - **9790** es partitura. Comparte el 979 con los libros, así que hay
///   que mirar el cuarto dígito.
/// - **977** es revista o diario. Son los ISSN.
/// - Cualquier otro prefijo es un producto: la caja de galletitas que
///   quedó al lado del libro.
///
/// # Por qué distinguirlos
///
/// Para poder decir qué pasó. «No encontré ese libro» y «eso que apuntaste
/// no es un libro» son dos problemas distintos y tienen dos soluciones
/// distintas, y si la app dice lo mismo en los dos casos, la persona
/// vuelve a intentar con el mismo código y vuelve a fallar.
library;

/// Qué resultó ser lo que se leyó.
enum Codigo {
  libro,
  revista,
  partitura,

  /// Un código de barras válido, pero de otra cosa.
  producto,

  /// No son trece ni diez caracteres, o las cuentas no cierran.
  ilegible,
}

class Isbn {
  /// Deja solo lo que cuenta.
  ///
  /// La gente escribe los ISBN con guiones y espacios porque así vienen
  /// impresos —978-987-4063-65-6— y el lector de códigos a veces mete un
  /// espacio al final. La X del final de los ISBN de diez es un dígito de
  /// verdad: vale once, y por eso no es un número.
  static String limpiar(String crudo) {
    final buffer = StringBuffer();
    for (final c in crudo.trim().toUpperCase().split('')) {
      if (RegExp(r'[0-9X]').hasMatch(c)) buffer.write(c);
    }
    return buffer.toString();
  }

  /// ¿Las cuentas cierran?
  ///
  /// Los ISBN llevan un dígito de control al final que se calcula con los
  /// anteriores. Sirve para atajar un código mal leído **antes** de salir
  /// a preguntarle a internet por un libro que no existe: si el dígito no
  /// da, lo que se leyó está mal, punto.
  static bool valido(String crudo) {
    final isbn = limpiar(crudo);
    if (isbn.length == 13) return _control13(isbn);
    if (isbn.length == 10) return _control10(isbn);
    return false;
  }

  /// En un ISBN de trece, cada dígito pesa alterno: uno, tres, uno, tres.
  /// La suma de los trece tiene que ser múltiplo de diez.
  static bool _control13(String isbn) {
    if (RegExp(r'^\d{13}$').hasMatch(isbn) == false) return false;
    var suma = 0;
    for (var i = 0; i < 13; i++) {
      suma += int.parse(isbn[i]) * (i.isEven ? 1 : 3);
    }
    return suma % 10 == 0;
  }

  /// En uno de diez, los pesos van de diez a uno y la suma tiene que ser
  /// múltiplo de once. Once y no diez: por eso hace falta la X, que es la
  /// forma de escribir «diez» en un solo carácter.
  static bool _control10(String isbn) {
    if (RegExp(r'^\d{9}[0-9X]$').hasMatch(isbn) == false) return false;
    var suma = 0;
    for (var i = 0; i < 10; i++) {
      final v = isbn[i] == 'X' ? 10 : int.parse(isbn[i]);
      suma += v * (10 - i);
    }
    return suma % 11 == 0;
  }

  /// Pasa un ISBN viejo de diez dígitos al de trece.
  ///
  /// Los libros anteriores a 2007 tienen diez. Open Library los guarda de
  /// las dos formas según la ficha, así que conviene preguntar siempre por
  /// el de trece y no depender de con cuál lo hayan cargado.
  ///
  /// La cuenta es: se le pone 978 adelante, se tiran los diez viejos menos
  /// el dígito de control, y se calcula el control nuevo.
  static String? aTrece(String crudo) {
    final isbn = limpiar(crudo);
    if (isbn.length == 13) return _control13(isbn) ? isbn : null;
    if (isbn.length != 10 || !_control10(isbn)) return null;

    final cuerpo = '978${isbn.substring(0, 9)}';
    var suma = 0;
    for (var i = 0; i < 12; i++) {
      suma += int.parse(cuerpo[i]) * (i.isEven ? 1 : 3);
    }
    return '$cuerpo${(10 - suma % 10) % 10}';
  }

  /// Qué es lo que apuntó la cámara.
  static Codigo queEs(String crudo) {
    final codigo = limpiar(crudo);

    // Un ISBN de diez ya es un libro: ese formato no lo usa nada más.
    if (codigo.length == 10) {
      return _control10(codigo) ? Codigo.libro : Codigo.ilegible;
    }
    if (codigo.length != 13 || !_control13(codigo)) return Codigo.ilegible;

    if (codigo.startsWith('9790')) return Codigo.partitura;
    if (codigo.startsWith('978') || codigo.startsWith('979')) {
      return Codigo.libro;
    }
    if (codigo.startsWith('977')) return Codigo.revista;
    return Codigo.producto;
  }

  /// Cómo se le cuenta a la persona lo que pasó.
  ///
  /// En segunda persona y sin culpar a nadie: el código estaba bien leído,
  /// lo que pasa es que no es un libro.
  static String? porQueNoSirve(String crudo) => switch (queEs(crudo)) {
    Codigo.libro => null,
    Codigo.revista => 'Eso es una revista o un diario, no un libro.',
    Codigo.partitura => 'Eso es una partitura.',
    Codigo.producto => 'Ese código no es de un libro.',
    Codigo.ilegible => 'No pude leer bien ese código. Probá de nuevo.',
  };
}
