import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/insignias.dart';

/// Las insignias: casa, facción, cabaña.
void main() {
  Insignia buscar(String saga, String nombre) =>
      Insignia.todas.firstWhere((i) => i.saga == saga && i.nombre == nombre);

  final slytherin = buscar('Harry Potter', 'Slytherin');
  final gryffindor = buscar('Harry Potter', 'Gryffindor');
  final osadia = buscar('Divergente', 'Osadía');

  group('una por saga', () {
    test('elegir otra de la misma saga reemplaza a la anterior', () {
      // No estás en dos casas. Si se pudieran acumular, la insignia
      // dejaría de decir nada.
      var puestas = Insignia.alternar(const [], slytherin);
      puestas = Insignia.alternar(puestas, gryffindor);

      expect(puestas, [gryffindor.clave]);
    });

    test('de sagas distintas conviven', () {
      var puestas = Insignia.alternar(const [], slytherin);
      puestas = Insignia.alternar(puestas, osadia);

      expect(puestas, hasLength(2));
      expect(puestas, contains(slytherin.clave));
      expect(puestas, contains(osadia.clave));
    });

    test('tocar la que tenés puesta la saca', () {
      // Es la única forma de quedarse sin ninguna sin un botón aparte.
      var puestas = Insignia.alternar(const [], slytherin);
      puestas = Insignia.alternar(puestas, slytherin);

      expect(puestas, isEmpty);
    });

    test('cambiar de casa no toca las otras sagas', () {
      var puestas = Insignia.alternar(const [], osadia);
      puestas = Insignia.alternar(puestas, slytherin);
      puestas = Insignia.alternar(puestas, gryffindor);

      expect(puestas, contains(osadia.clave));
      expect(puestas, contains(gryffindor.clave));
      expect(puestas, isNot(contains(slytherin.clave)));
    });
  });

  group('el catálogo', () {
    test('están las sagas que lee esta comunidad', () {
      for (final saga in [
        'Harry Potter',
        'Divergente',
        'Campamento Mestizo',
        'Los juegos del hambre',
        'Cazadores de sombras',
      ]) {
        expect(Insignia.sagas, contains(saga));
        expect(Insignia.deLaSaga(saga), isNotEmpty);
      }
    });

    test('las cuatro casas de Hogwarts, ni una más', () {
      expect(Insignia.deLaSaga('Harry Potter').map((i) => i.nombre), [
        'Gryffindor',
        'Slytherin',
        'Ravenclaw',
        'Hufflepuff',
      ]);
    });

    test('las cinco facciones de Divergente', () {
      expect(Insignia.deLaSaga('Divergente'), hasLength(5));
    });

    test('ninguna clave se repite', () {
      // Si dos insignias tuvieran la misma clave, elegir una pondría la
      // otra y sería imposible de entender.
      final claves = Insignia.todas.map((i) => i.clave).toList();

      expect(claves.toSet(), hasLength(claves.length));
    });

    test('todas tienen color propio dentro de su saga', () {
      // Dos casas del mismo color en la misma fila no se distinguen, que
      // es justo lo único que tienen que hacer.
      for (final saga in Insignia.sagas) {
        final colores = Insignia.deLaSaga(saga).map((i) => i.color).toSet();
        expect(
          colores,
          hasLength(Insignia.deLaSaga(saga).length),
          reason: 'hay colores repetidos en $saga',
        );
      }
    });
  });

  group('lo guardado', () {
    test('la clave se puede leer a ojo', () {
      // El día que haya que mirar la base a mano, «hp:3» no le dice nada
      // a nadie.
      expect(slytherin.clave, 'Harry Potter|Slytherin');
    });

    test('una insignia que ya no existe no rompe nada', () {
      // Puede pasar si alguien la guardó y después se sacó de la lista.
      expect(Insignia.porClave('Saga Vieja|Algo'), isNull);
      expect(Insignia.porClave(''), isNull);
    });

    test('alternar sobre una clave desconocida no la pierde', () {
      // Una insignia guardada de otra versión no tiene por qué
      // desaparecer solo porque hoy no la reconocemos.
      final puestas = Insignia.alternar(['Saga Vieja|Algo'], slytherin);

      expect(puestas, contains('Saga Vieja|Algo'));
      expect(puestas, contains(slytherin.clave));
    });
  });
}
