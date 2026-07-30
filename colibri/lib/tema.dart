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
  static const cuerpo = TextStyle(fontSize: 14, color: Paleta.luz, height: 1.45);
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

ThemeData construirTema() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Paleta.noche,
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
