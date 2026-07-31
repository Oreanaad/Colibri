import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';

Libro _libro([String titulo = 'Cometierra']) =>
    Libro(id: titulo, titulo: titulo, autor: 'Dolores Reyes');

final _hoy = DateTime(2026, 3, 12);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('fechas', () {
    test('marcar "leyendo" anota la fecha de inicio sola', () async {
      final b = Biblioteca();
      final l = _libro();
      await b.agregar(l);

      await b.cambiarEstado(l, Estado.leyendo, hoy: _hoy);

      expect(l.empezado, DateTime(2026, 3, 12));
      expect(l.terminado, isNull, reason: 'todavía no lo terminó');
    });

    test('marcar "leído" anota las dos si faltaban', () async {
      final b = Biblioteca();
      final l = _libro();
      await b.agregar(l);

      await b.cambiarEstado(l, Estado.leido, hoy: _hoy);

      expect(l.empezado, DateTime(2026, 3, 12));
      expect(l.terminado, DateTime(2026, 3, 12));
    });

    test('nunca pisa una fecha que ya estaba puesta', () async {
      final b = Biblioteca();
      final l = _libro()..empezado = DateTime(2026, 1, 5);
      await b.agregar(l);

      await b.cambiarEstado(l, Estado.leido, hoy: _hoy);

      expect(
        l.empezado,
        DateTime(2026, 1, 5),
        reason: 'lo empezó en enero, no hoy',
      );
      expect(l.terminado, DateTime(2026, 3, 12));
    });

    test('se guarda solo la fecha, sin la hora', () async {
      final b = Biblioteca();
      final l = _libro();
      await b.agregar(l);

      await b.cambiarEstado(
        l,
        Estado.leyendo,
        hoy: DateTime(2026, 3, 12, 23, 47),
      );

      expect(l.empezado!.hour, 0);
      expect(l.empezado!.minute, 0);
    });

    test('los días de lectura cuentan el primero y el último', () {
      final l = _libro()
        ..empezado = DateTime(2026, 3, 1)
        ..terminado = DateTime(2026, 3, 12);
      expect(l.diasDeLectura, 12);

      final enUnDia = _libro()
        ..empezado = DateTime(2026, 3, 1)
        ..terminado = DateTime(2026, 3, 1);
      expect(enUnDia.diasDeLectura, 1, reason: 'un día es 1, no 0');

      expect(_libro().diasDeLectura, isNull, reason: 'sin fechas, no hay dato');
    });

    test('fechaCorta escribe el mes en castellano', () {
      expect(fechaCorta(DateTime(2026, 3, 12)), '12 mar 2026');
      expect(fechaCorta(DateTime(2025, 12, 1)), '1 dic 2025');
    });
  });

  group('reseña propia', () {
    test('una reseña en blanco no cuenta como reseña', () {
      expect(_libro().tieneResena, isFalse);
      expect((_libro()..resena = '   ').tieneResena, isFalse);
      expect((_libro()..resena = 'Buenísimo').tieneResena, isTrue);
    });

    test(
      'la reseña, los spoilers y el personaje sobreviven al reinicio',
      () async {
        final b = Biblioteca();
        final l = _libro('Pedro Páramo')
          ..resena = 'Me lo leí de un tirón.'
          ..resenaConSpoilers = true
          ..personajes.add('Susana San Juan')
          ..empezado = DateTime(2026, 2, 1)
          ..terminado = DateTime(2026, 2, 4);
        await b.agregar(l);

        final otra = Biblioteca();
        await otra.cargar();
        final guardado = otra.todos.first;

        expect(guardado.resena, 'Me lo leí de un tirón.');
        expect(guardado.resenaConSpoilers, isTrue);
        expect(guardado.personajes, ['Susana San Juan']);
        expect(guardado.empezado, DateTime(2026, 2, 1));
        expect(guardado.diasDeLectura, 4);
      },
    );

    test(
      'un libro guardado antes de que existieran estos campos se lee bien',
      () {
        final l = Libro.desdeJson({
          'id': '1',
          'titulo': 'Rayuela',
          'autor': 'Julio Cortázar',
          'estado': 1,
        });

        expect(l.empezado, isNull);
        expect(l.resena, isNull);
        expect(l.resenaConSpoilers, isFalse);
        expect(l.personajes, isEmpty);
      },
    );
  });
}
