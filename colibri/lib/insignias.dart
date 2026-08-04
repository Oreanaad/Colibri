/// Las insignias: a qué casa, facción o cabaña perteneces.
///
/// # Por qué esto no es una etiqueta más
///
/// «Me destruyó» dice cómo te dejó un libro. «Slytherin» dice **quién
/// sos**, y se contesta sin pensar. Es la primera pregunta que se hacen
/// dos lectoras que se acaban de conocer, y la que más rápido las junta.
///
/// # Una por saga
///
/// No estás en dos casas. Elegir otra de la misma saga reemplaza a la
/// anterior en vez de sumarse: si se pudieran acumular, la insignia
/// dejaría de decir nada.
///
/// # Los colores: la única otra excepción a la paleta
///
/// La app tiene una regla —lo que se toca va en lila, lo que involucra a
/// otra persona va en oro— y hasta ahora la única excepción eran las
/// escalas: lágrimas azules, chiles rojos, corazones rojos.
///
/// Las insignias son la segunda, y por un motivo distinto: **estos
/// colores no son de la app, son de la persona.** Slytherin es verde. Una
/// insignia de Slytherin en lila no es una insignia de Slytherin, es un
/// chip. Todo el valor está en que se reconozca de lejos.
///
/// # Nombres, no escudos
///
/// A propósito. Un escudo dibujado sería copiar el arte de otra persona;
/// el nombre de una casa es nombrar una historia, que es lo que hace
/// cualquiera que la cuenta. Por eso acá hay texto y color, y no va a
/// haber dibujos.
library;

class Insignia {
  /// De qué saga. Se usa para agrupar y para la regla de una por saga.
  final String saga;

  /// Cómo se llama, tal cual lo diría alguien.
  final String nombre;

  /// El color del fandom, en hexadecimal.
  final int color;

  const Insignia({
    required this.saga,
    required this.nombre,
    required this.color,
  });

  /// Cómo se guarda: «Harry Potter|Slytherin».
  ///
  /// Con el nombre adentro y no un número, para que lo guardado se pueda
  /// leer. El día que haya que mirar la base a mano, «hp:3» no le dice
  /// nada a nadie.
  String get clave => '$saga|$nombre';

  static const todas = <Insignia>[
    // Harry Potter
    Insignia(saga: 'Harry Potter', nombre: 'Gryffindor', color: 0xFFAE0001),
    Insignia(saga: 'Harry Potter', nombre: 'Slytherin', color: 0xFF2A623D),
    Insignia(saga: 'Harry Potter', nombre: 'Ravenclaw', color: 0xFF222F5B),
    Insignia(saga: 'Harry Potter', nombre: 'Hufflepuff', color: 0xFFE0A800),

    // Divergente
    Insignia(saga: 'Divergente', nombre: 'Abnegación', color: 0xFF9AA0A6),
    Insignia(saga: 'Divergente', nombre: 'Osadía', color: 0xFFB3261E),
    Insignia(saga: 'Divergente', nombre: 'Erudición', color: 0xFF1E6FB8),
    Insignia(saga: 'Divergente', nombre: 'Cordialidad', color: 0xFFE0A800),
    Insignia(saga: 'Divergente', nombre: 'Verdad', color: 0xFF2B2B2B),

    // Percy Jackson · las cabañas del campamento
    Insignia(saga: 'Campamento Mestizo', nombre: 'Zeus', color: 0xFF6C8EBF),
    Insignia(saga: 'Campamento Mestizo', nombre: 'Poseidón', color: 0xFF1E7A8C),
    Insignia(saga: 'Campamento Mestizo', nombre: 'Hades', color: 0xFF3B3245),
    Insignia(saga: 'Campamento Mestizo', nombre: 'Atenea', color: 0xFF7E8C4E),
    Insignia(saga: 'Campamento Mestizo', nombre: 'Ares', color: 0xFF9C2B2B),
    Insignia(saga: 'Campamento Mestizo', nombre: 'Apolo', color: 0xFFE0A31E),
    Insignia(saga: 'Campamento Mestizo', nombre: 'Artemisa', color: 0xFF8E97A8),
    Insignia(saga: 'Campamento Mestizo', nombre: 'Deméter', color: 0xFF5C8C4A),
    Insignia(saga: 'Campamento Mestizo', nombre: 'Hefesto', color: 0xFFA85B2B),
    Insignia(saga: 'Campamento Mestizo', nombre: 'Afrodita', color: 0xFFC96A9B),
    Insignia(saga: 'Campamento Mestizo', nombre: 'Hermes', color: 0xFF6FA8A0),
    Insignia(saga: 'Campamento Mestizo', nombre: 'Dioniso', color: 0xFF7A4B8C),

    // Los juegos del hambre
    Insignia(
      saga: 'Los juegos del hambre',
      nombre: 'Distrito 12',
      color: 0xFF5A5048,
    ),
    Insignia(
      saga: 'Los juegos del hambre',
      nombre: 'Distrito 13',
      color: 0xFF44505C,
    ),
    Insignia(
      saga: 'Los juegos del hambre',
      nombre: 'Distrito 4',
      color: 0xFF2E7D8C,
    ),
    Insignia(
      saga: 'Los juegos del hambre',
      nombre: 'Distrito 1',
      color: 0xFFC0A24A,
    ),
    Insignia(
      saga: 'Los juegos del hambre',
      nombre: 'El Capitolio',
      color: 0xFFB0508C,
    ),

    // Cazadores de sombras
    Insignia(
      saga: 'Cazadores de sombras',
      nombre: 'Nefilim',
      color: 0xFF9A9AA8,
    ),
    Insignia(saga: 'Cazadores de sombras', nombre: 'Brujo', color: 0xFF7A4B8C),
    Insignia(
      saga: 'Cazadores de sombras',
      nombre: 'Vampiro',
      color: 0xFF8C2B3B,
    ),
    Insignia(
      saga: 'Cazadores de sombras',
      nombre: 'Licántropo',
      color: 0xFF6B5340,
    ),
    Insignia(saga: 'Cazadores de sombras', nombre: 'Hada', color: 0xFF4F8C6B),

    // Canción de hielo y fuego
    Insignia(saga: 'Juego de tronos', nombre: 'Stark', color: 0xFF7E8794),
    Insignia(saga: 'Juego de tronos', nombre: 'Targaryen', color: 0xFF8C2B2B),
    Insignia(saga: 'Juego de tronos', nombre: 'Lannister', color: 0xFFC0912B),
    Insignia(saga: 'Juego de tronos', nombre: 'Baratheon', color: 0xFF3B6B4A),
    Insignia(saga: 'Juego de tronos', nombre: 'Greyjoy', color: 0xFF3F5560),
    Insignia(saga: 'Juego de tronos', nombre: 'Martell', color: 0xFFC97A2B),

    // El señor de los anillos
    Insignia(saga: 'La Tierra Media', nombre: 'Hobbit', color: 0xFF7A8C4A),
    Insignia(saga: 'La Tierra Media', nombre: 'Elfo', color: 0xFF8CA8B0),
    Insignia(saga: 'La Tierra Media', nombre: 'Enano', color: 0xFFA8642B),
    Insignia(saga: 'La Tierra Media', nombre: 'Mago', color: 0xFF9A8CB0),
  ];

  /// Las sagas, en el orden en que se muestran.
  static List<String> get sagas {
    final vistas = <String>[];
    for (final i in todas) {
      if (!vistas.contains(i.saga)) vistas.add(i.saga);
    }
    return vistas;
  }

  static List<Insignia> deLaSaga(String saga) =>
      todas.where((i) => i.saga == saga).toList();

  static Insignia? porClave(String clave) {
    for (final i in todas) {
      if (i.clave == clave) return i;
    }
    // Puede pasar si alguien guardó una insignia y después se sacó de la
    // lista. Se devuelve nada y quien la muestre la saltea, en vez de
    // dibujar un chip sin nombre.
    return null;
  }

  /// Poner o sacar una insignia, respetando una por saga.
  ///
  /// Devuelve la lista nueva. Si tocaste la que ya tenías puesta, la saca:
  /// es la única forma de quedarse sin ninguna sin un botón aparte.
  static List<String> alternar(List<String> puestas, Insignia elegida) {
    if (puestas.contains(elegida.clave)) {
      return puestas.where((c) => c != elegida.clave).toList();
    }
    // Fuera cualquier otra de la misma saga: no estás en dos casas.
    final sinLaDeSuSaga = puestas
        .where((c) => porClave(c)?.saga != elegida.saga)
        .toList();
    return [...sinLaDeSuSaga, elegida.clave];
  }
}
