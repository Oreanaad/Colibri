import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cómo armaste **tu** estante: cuántas repisas, de qué color y qué le
/// pusiste encima.
///
/// # Por qué esto existe aparte de la biblioteca
///
/// Un estante ya era una lista de libros con nombre. Esto es otra cosa: es
/// cómo se ve. Una lista contesta «qué tengo acá»; una vitrina contesta
/// «cómo lo muestro», que es la pregunta que se hace alguien que quiere
/// sacarle una foto a su biblioteca.
///
/// Van separadas a propósito. Sacar un libro del estante no puede borrarte
/// las plantas, y cambiar el color no puede tocar los libros.
///
/// # Por qué se guarda por estante y no una sola para todo
///
/// Porque un estante de terror y uno de poesía no se decoran igual, y esa
/// es la mitad de la gracia.

/// El fondo de la vitrina.
///
/// Pocos y con nombre, no un selector de colores. Un selector deja elegir
/// cualquiera de dieciséis millones, y casi todos quedan mal detrás de unos
/// libros: los que se ven bien son los que tienen poca luz y poco color,
/// porque las tapas tienen que poder brillar encima.
enum FondoDeVitrina { noche, madera, bosque, vino, niebla }

extension DatosDeFondo on FondoDeVitrina {
  String get nombre => switch (this) {
    FondoDeVitrina.noche => 'Noche',
    FondoDeVitrina.madera => 'Madera',
    FondoDeVitrina.bosque => 'Bosque',
    FondoDeVitrina.vino => 'Vino',
    FondoDeVitrina.niebla => 'Niebla',
  };

  /// La pared del fondo.
  Color get pared => switch (this) {
    FondoDeVitrina.noche => const Color(0xFF171331),
    FondoDeVitrina.madera => const Color(0xFF2A1E14),
    FondoDeVitrina.bosque => const Color(0xFF14231B),
    FondoDeVitrina.vino => const Color(0xFF2A1219),
    FondoDeVitrina.niebla => const Color(0xFF2B2B33),
  };

  /// La tabla de la repisa. Siempre más clara que la pared: si fueran del
  /// mismo tono, los libros parecerían flotar.
  Color get tabla => switch (this) {
    FondoDeVitrina.noche => const Color(0xFF3A2E1F),
    FondoDeVitrina.madera => const Color(0xFF5A3E28),
    FondoDeVitrina.bosque => const Color(0xFF3B2E1D),
    FondoDeVitrina.vino => const Color(0xFF432A22),
    FondoDeVitrina.niebla => const Color(0xFF4A4A55),
  };
}

/// Lo que se le puede poner a una repisa además de libros.
///
/// Cada uno se dibuja apoyado en una punta de la repisa, no en el medio:
/// los adornos van donde no hay libros, que es lo que pasa en un estante de
/// verdad.
enum Adorno { luces, planta, gato, hojas, vela, caracol }

extension DatosDeAdorno on Adorno {
  String get nombre => switch (this) {
    Adorno.luces => 'Luces',
    Adorno.planta => 'Planta',
    Adorno.gato => 'Gato',
    Adorno.hojas => 'Hojas',
    Adorno.vela => 'Vela',
    Adorno.caracol => 'Caracoles',
  };

  /// Las luces van colgadas arriba de la repisa; el resto, apoyado al lado
  /// de los libros. Es la diferencia entre una guirnalda y un objeto.
  bool get cuelga => this == Adorno.luces;
}

/// Cómo se para un libro en la repisa.
///
/// De lomo es como están los libros en un estante. De tapa es como se pone
/// el que una quiere que se vea: en las bibliotecas de verdad siempre hay
/// dos o tres de frente, y son los favoritos.
enum Postura { lomo, tapa }

/// La vitrina de un estante.
class Vitrina {
  /// Cuántas repisas tiene el mueble.
  ///
  /// Entre dos y seis. Con una no es un mueble; con más de seis, en un
  /// teléfono cada repisa queda tan baja que los libros no se ven.
  final int repisas;

  final FondoDeVitrina fondo;
  final Set<Adorno> adornos;

  /// Qué libros están de tapa. Los que no estén acá van de lomo, que es lo
  /// normal en un estante.
  ///
  /// Se guarda por clave de libro y no por posición: si mañana sacás un
  /// libro del estante, los demás no cambian de postura.
  final Set<String> deTapa;

  const Vitrina({
    this.repisas = 3,
    this.fondo = FondoDeVitrina.noche,
    this.adornos = const {Adorno.luces},
    this.deTapa = const {},
  });

  static const minimoDeRepisas = 2;
  static const maximoDeRepisas = 6;

  Postura posturaDe(String claveDeLibro) =>
      deTapa.contains(claveDeLibro) ? Postura.tapa : Postura.lomo;

  Vitrina copiarCon({
    int? repisas,
    FondoDeVitrina? fondo,
    Set<Adorno>? adornos,
    Set<String>? deTapa,
  }) => Vitrina(
    repisas: (repisas ?? this.repisas).clamp(minimoDeRepisas, maximoDeRepisas),
    fondo: fondo ?? this.fondo,
    adornos: adornos ?? this.adornos,
    deTapa: deTapa ?? this.deTapa,
  );

  Vitrina alternarAdorno(Adorno a) => copiarCon(
    adornos: adornos.contains(a) ? ({...adornos}..remove(a)) : {...adornos, a},
  );

  Vitrina alternarPostura(String clave) => copiarCon(
    deTapa: deTapa.contains(clave)
        ? ({...deTapa}..remove(clave))
        : {...deTapa, clave},
  );

  Map<String, dynamic> aJson() => {
    'repisas': repisas,
    'fondo': fondo.name,
    'adornos': [for (final a in adornos) a.name],
    'deTapa': deTapa.toList(),
  };

  /// Todo con valor de fábrica si falta o si no se entiende.
  ///
  /// Un estante que no abre porque se guardó con un nombre de adorno que la
  /// app ya no conoce sería perder la decoración **y** el estante.
  factory Vitrina.desdeJson(Map<String, dynamic> j) => Vitrina(
    repisas: ((j['repisas'] as int?) ?? 3).clamp(
      minimoDeRepisas,
      maximoDeRepisas,
    ),
    fondo: FondoDeVitrina.values.firstWhere(
      (f) => f.name == j['fondo'],
      orElse: () => FondoDeVitrina.noche,
    ),
    adornos: {
      for (final n in (j['adornos'] as List?) ?? const [])
        ...Adorno.values.where((a) => a.name == n),
    },
    deTapa: {
      for (final c in (j['deTapa'] as List?) ?? const [])
        if (c is String) c,
    },
  );
}

/// Dónde se guardan las vitrinas.
///
/// Una por estante, en el teléfono. Todavía no viajan a la nube: son
/// decoración, y lo que más importa que no se pierda ya viaja. Cuando
/// viajen, la tabla es una columna de `estantes`.
class Vitrinas {
  static const _clave = 'colibri.vitrinas.v1';

  final Map<String, Vitrina> _porEstante = {};

  Vitrina de(String estante) => _porEstante[estante] ?? const Vitrina();

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _porEstante.clear();

    final crudo = prefs.getString(_clave);
    if (crudo == null) return;

    try {
      final j = jsonDecode(crudo) as Map<String, dynamic>;
      j.forEach((estante, v) {
        _porEstante[estante] = Vitrina.desdeJson(
          (v as Map).cast<String, dynamic>(),
        );
      });
    } catch (_) {
      // Formato roto: se arranca con las de fábrica, que es un estado
      // válido. Perder la decoración es molesto; no abrir el estante es
      // peor.
    }
  }

  Future<void> guardar(String estante, Vitrina v) async {
    _porEstante[estante] = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode({for (final e in _porEstante.entries) e.key: e.value.aJson()}),
    );
  }

  /// Cuando se borra o se renombra un estante.
  Future<void> renombrar(String viejo, String nuevo) async {
    final v = _porEstante.remove(viejo);
    if (v != null) await guardar(nuevo, v);
  }

  Future<void> olvidar(String estante) async {
    _porEstante.remove(estante);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode({for (final e in _porEstante.entries) e.key: e.value.aJson()}),
    );
  }
}

final vitrinas = Vitrinas();
