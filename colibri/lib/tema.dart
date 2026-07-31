import 'package:flutter/material.dart';

/// La paleta de Colibrí.
///
/// Dos reglas que hay que respetar en toda la app:
///   - Si algo responde al dedo, va en [lila].
///   - Si hay otra persona del otro lado, va en [oro]. Nunca un botón.
class Paleta {
  static const noche = Color(0xFF171331);
  static const nocheAlta = Color(0xFF221B45);
  static const luz = Color(0xFFF0EBF5);
  static const lila = Color(0xFFB9A6E6);
  static const oro = Color(0xFFE9B44C);
  static const bruma = Color(0xFF9990B5);
  static const linea = Color(0xFF332A57);

  // Versiones translúcidas, escritas como ARGB para no depender de la API.
  static const oroTenue = Color(0x1CE9B44C); // 11%
  static const oroBorde = Color(0x66E9B44C); // 40%
  static const oroTexto = Color(0xFFEDDCB8);

  // ---- Las escalas de sensación ----
  //
  // Son la única excepción a la regla de que el oro es lo único cálido, y
  // se la ganaron: una lágrima dorada no dice "lloré" y un corazón gris no
  // dice "romance". Acá el color no decora, nombra.
  //
  // Están bajados de saturación a propósito. Un rojo puro y un azul puro
  // sobre este violeta pelean con el oro y con las tapas; así apagados se
  // leen igual de claro y no se llevan la pantalla por delante.
  static const agua = Color(0xFF6E9FE0); // lágrimas
  static const rojo = Color(0xFFE0596B); // corazones y el cuerpo del chile
  static const verde = Color(0xFF5FA85A); // el cabito del chile
}

/// Escala tipográfica. Un solo lugar donde cambiarla.
class Tipo {
  static const marca = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    color: Paleta.luz,
  );
  static const titulo = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: Paleta.luz,
    height: 1.2,
  );
  static const subtitulo = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: Paleta.luz,
    height: 1.25,
  );
  static const cuerpo = TextStyle(
    fontSize: 14,
    color: Paleta.luz,
    height: 1.45,
  );
  static const meta = TextStyle(fontSize: 12, color: Paleta.bruma, height: 1.4);
  static const rotulo = TextStyle(
    fontSize: 10,
    letterSpacing: 2.2,
    fontWeight: FontWeight.w500,
    color: Paleta.bruma,
  );
  static const lectura = TextStyle(
    fontSize: 15,
    height: 1.5,
    color: Paleta.luz,
    fontStyle: FontStyle.italic,
  );
}

/// Cómo se adapta la app al ancho de la pantalla.
///
/// El problema que resuelve: en una computadora, una app pensada para
/// teléfono se estira y queda una línea de texto de treinta centímetros,
/// imposible de leer, con tres tapas gigantes por fila.
///
/// La regla es simple y vale para todo: **el contenido no crece más allá
/// de lo cómodo; lo que crece es el margen a los costados.** Y las
/// grillas suman columnas en vez de agrandar cada tapa.
class Medidas {
  /// Lo más ancho que se pone una columna de contenido.
  ///
  /// Sale de la lectura, no del diseño: pasadas unas 70 letras por
  /// renglón, el ojo pierde el salto de línea y hay que releer.
  static const anchoComodo = 620.0;

  /// A partir de acá la pantalla se considera grande.
  static const pantallaGrande = 760.0;

  static bool esGrande(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= pantallaGrande;

  /// Cuánto aire a los costados. En un teléfono, lo justo; en una
  /// pantalla grande, lo que sobre después del ancho cómodo.
  static double margen(BuildContext c) =>
      MediaQuery.sizeOf(c).width < 400 ? 16 : 20;

  /// El ancho que le toca a cada tapa en una grilla.
  ///
  /// Al fijar el ancho de la tapa en vez de la cantidad de columnas, la
  /// grilla suma columnas sola cuando hay lugar: tres en un teléfono,
  /// cinco o seis en una computadora, y siempre tapas del mismo tamaño.
  static double anchoDeTapa(BuildContext c) =>
      MediaQuery.sizeOf(c).width < 380 ? 100 : 118;
}

/// Centra el contenido y le pone un techo de ancho.
///
/// Se usa en las pantallas que son una columna de contenido. Con esto,
/// la misma pantalla se ve bien en un teléfono y en un monitor sin
/// escribir dos veces el diseño.
class Columna extends StatelessWidget {
  final Widget hijo;
  final double ancho;

  const Columna({
    super.key,
    required this.hijo,
    this.ancho = Medidas.anchoComodo,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: ancho),
      child: hijo,
    ),
  );
}

ThemeData construirTema() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    // Transparente para que se vea el librero del fondo. El color de
    // verdad lo pone Fondo, una sola vez, detrás de toda la app.
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: const ColorScheme.dark(
      surface: Paleta.noche,
      primary: Paleta.lila,
      onPrimary: Paleta.noche,
      secondary: Paleta.oro,
      onSurface: Paleta.luz,
    ),
    dividerColor: Paleta.linea,
    splashColor: const Color(0x22B9A6E6),
    highlightColor: const Color(0x11B9A6E6),
  );
}
