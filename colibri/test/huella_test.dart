import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/nube.dart';

/// La huella de un libro: cómo sabe «sincronizar» que algo ya subió.
///
/// Si da lo mismo para dos libros distintos, un cambio no sube nunca. Si
/// da distinto para el mismo libro, sincronizar sube todo cada vez, que es
/// justo lo que vino a evitar.
void main() {
  Libro libro() => Libro(id: '1', titulo: 'Cometierra', autor: 'Dolores Reyes');

  test('el mismo libro da la misma huella', () {
    expect(huellaDe(libro()), huellaDe(libro()));
  });

  test('sobrevive a guardarse y leerse de nuevo', () {
    // Es lo que pasa entre un arranque y el siguiente: si la huella
    // cambiara al releer el libro del disco, todo se resubiría siempre.
    final a = libro()..puntaje = 4;
    final b = Libro.desdeJson(a.aJson());
    expect(huellaDe(b), huellaDe(a));
  });

  group('cambia con cualquier cosa que se pueda tocar', () {
    final antes = huellaDe(libro());

    test('las estrellas', () {
      expect(huellaDe(libro()..puntaje = 5), isNot(antes));
    });

    test('el estado', () {
      expect(huellaDe(libro()..estado = Estado.leido), isNot(antes));
    });

    test('la reseña', () {
      expect(huellaDe(libro()..resena = 'Me voló la cabeza'), isNot(antes));
    });

    test('un estante', () {
      expect(huellaDe(libro()..estantes.add('Terror')), isNot(antes));
    });

    test('una frase', () {
      final l = libro()
        ..frases.add(Frase(texto: 'Tierra', guardada: DateTime(2026)));
      expect(huellaDe(l), isNot(antes));
    });
  });
}
