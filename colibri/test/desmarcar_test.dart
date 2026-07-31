import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';

Libro _libro() => Libro(id: '1', titulo: 'Cometierra', autor: 'Dolores Reyes');
final _hoy = DateTime(2026, 3, 12);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('deshacer un estado tocado sin querer', () {
    test('tocar "leído" dos veces lo vuelve a pendiente', () async {
      final b = Biblioteca();
      final l = _libro();
      await b.agregar(l);

      await b.cambiarEstado(l, Estado.leido, hoy: _hoy);
      expect(l.estado, Estado.leido);
      expect(l.terminado, isNotNull);

      await b.cambiarEstado(l, Estado.leido, hoy: _hoy);

      expect(l.estado, Estado.pendiente);
      expect(l.terminado, isNull,
          reason: 'sin esto queda un "lo leíste en un día" que nunca pasó');
    });

    test('tocar "leyendo" dos veces también', () async {
      final b = Biblioteca();
      final l = _libro();
      await b.agregar(l);

      await b.cambiarEstado(l, Estado.leyendo, hoy: _hoy);
      await b.cambiarEstado(l, Estado.leyendo, hoy: _hoy);

      expect(l.estado, Estado.pendiente);
      expect(l.empezado, isNull);
    });

    test('deshacer "leído" no borra la fecha de inicio', () async {
      final b = Biblioteca();
      final l = _libro();
      await b.agregar(l);

      await b.cambiarEstado(l, Estado.leyendo, hoy: DateTime(2026, 3, 1));
      await b.cambiarEstado(l, Estado.leido, hoy: _hoy);
      await b.cambiarEstado(l, Estado.leido, hoy: _hoy);

      expect(l.empezado, DateTime(2026, 3, 1),
          reason: 'lo empezó de verdad, eso no se toca');
      expect(l.terminado, isNull);
    });

    test('pendiente no se deshace: siempre hay que estar en alguno', () async {
      final b = Biblioteca();
      final l = _libro();
      await b.agregar(l);

      await b.cambiarEstado(l, Estado.pendiente, hoy: _hoy);
      expect(l.estado, Estado.pendiente);
    });

    test('cambiar a otro estado sigue funcionando normal', () async {
      final b = Biblioteca();
      final l = _libro();
      await b.agregar(l);

      await b.cambiarEstado(l, Estado.leyendo, hoy: _hoy);
      await b.cambiarEstado(l, Estado.leido, hoy: _hoy);

      expect(l.estado, Estado.leido);
      expect(l.terminado, isNotNull);
    });
  });

  group('varios personajes favoritos', () {
    test('se guardan todos y sobreviven al reinicio', () async {
      final b = Biblioteca();
      final l = _libro()
        ..personajes.addAll(['Cometierra', 'Walter', 'La Tía']);
      await b.agregar(l);

      final otra = Biblioteca();
      await otra.cargar();

      expect(otra.todos.first.personajes, ['Cometierra', 'Walter', 'La Tía']);
    });

    test('un libro guardado cuando era uno solo no pierde el dato', () {
      // Antes el campo era 'personaje', en singular.
      final l = Libro.desdeJson({
        'id': '1',
        'titulo': 'Pedro Páramo',
        'autor': 'Juan Rulfo',
        'personaje': 'Susana San Juan',
      });

      expect(l.personajes, ['Susana San Juan']);
    });

    test('un libro sin personajes arranca con la lista vacía', () {
      final l = Libro.desdeJson({
        'id': '1',
        'titulo': 'Rayuela',
        'autor': 'Julio Cortázar',
      });

      expect(l.personajes, isEmpty);
    });
  });
}
