import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('sin nada guardado, arranca en la biblioteca', () async {
    final s = Sesion();
    await s.cargar();

    expect(s.seccion, 0);
    expect(s.solapa, 0);
    expect(s.libro, isNull);
  });

  test('recuerda la sección, la solapa y el libro', () async {
    final s = Sesion();
    await s.anotar(seccion: 2, solapa: 3, libro: 'rayuela|cortazar julio');

    // Otra instancia: es lo que pasa al recargar la página.
    final otra = Sesion();
    await otra.cargar();

    expect(otra.seccion, 2);
    expect(otra.solapa, 3);
    expect(otra.libro, 'rayuela|cortazar julio');
  });

  test('cerrar el libro no borra en qué solapa estabas', () async {
    final s = Sesion();
    await s.anotar(seccion: 0, solapa: 2, libro: 'algo');
    await s.anotar(cerrarLibro: true);

    final otra = Sesion();
    await otra.cargar();

    expect(otra.libro, isNull);
    expect(otra.solapa, 2, reason: 'volvés a la lista donde estabas');
  });

  test('anotar de a una cosa no pisa las demás', () async {
    final s = Sesion();
    await s.anotar(seccion: 1, solapa: 3, libro: 'algo');
    await s.anotar(seccion: 2);

    final otra = Sesion();
    await otra.cargar();

    expect(otra.seccion, 2);
    expect(otra.solapa, 3);
    expect(otra.libro, 'algo');
  });

  test('una sesión guardada con basura no rompe la app', () async {
    SharedPreferences.setMockInitialValues({
      'colibri.sesion.v1': 'esto no es json',
    });

    final s = Sesion();
    await s.cargar();

    expect(s.seccion, 0, reason: 'arranca en la biblioteca y listo');
    expect(s.libro, isNull);
  });

  test('el libro se guarda por clave, no por posición', () async {
    // Entre que cerrás y volvés, la biblioteca puede cambiar de orden o
    // el libro puede no estar más. Por eso se guarda la clave y se busca.
    final b = Biblioteca();
    final l = Libro(id: '1', titulo: 'Rayuela', autor: 'Julio Cortázar');
    await b.agregar(l);

    final s = Sesion();
    await s.anotar(libro: l.clave);

    expect(b.buscarPorClave(s.libro!)?.titulo, 'Rayuela');

    await b.quitar(l);
    expect(
      b.buscarPorClave(s.libro!),
      isNull,
      reason: 'y si ya no está, la app lo detecta en vez de romperse',
    );
  });

  group('la solapa Todos y lo que ya estaba guardado', () {
    test('sin nada guardado se abre en Todos', () async {
      SharedPreferences.setMockInitialValues({});
      final s = Sesion();
      await s.cargar();

      // Todos es la primera y la que se abre por defecto: es tu estante
      // entero, que es lo que una espera ver al entrar a su biblioteca.
      expect(s.solapa, 0);
    });

    test('lo guardado con el formato viejo se corre un lugar', () async {
      // Antes las solapas eran leyendo, leídos, pendientes, estantes.
      // Ahora Todos va primera, así que cada una se movió un lugar. Sin
      // este corrimiento, quien dejó abierto «Estantes» volvía a
      // «Pendientes» sin entender por qué.
      for (final caso in {0: 1, 1: 2, 2: 3, 3: 4}.entries) {
        SharedPreferences.setMockInitialValues({
          'colibri.sesion.v1': '{"seccion":0,"solapa":${caso.key}}',
        });
        final s = Sesion();
        await s.cargar();

        expect(
          s.solapa,
          caso.value,
          reason: 'la solapa ${caso.key} de antes es la ${caso.value} de ahora',
        );
      }
    });

    test('del formato viejo también se rescata el libro abierto', () async {
      SharedPreferences.setMockInitialValues({
        'colibri.sesion.v1': '{"seccion":1,"solapa":0,"libro":"/works/OL1W"}',
      });
      final s = Sesion();
      await s.cargar();

      expect(s.seccion, 1);
      expect(s.libro, '/works/OL1W');
    });

    test('si hay formato nuevo, el viejo se ignora', () async {
      // Si se leyeran los dos, cada arranque volvería a correr la solapa
      // un lugar y terminarías siempre en Estantes.
      SharedPreferences.setMockInitialValues({
        'colibri.sesion.v1': '{"seccion":0,"solapa":3}',
        'colibri.sesion.v2': '{"seccion":0,"solapa":1}',
      });
      final s = Sesion();
      await s.cargar();

      expect(s.solapa, 1);
    });

    test('guardar dos veces no vuelve a correr la solapa', () async {
      SharedPreferences.setMockInitialValues({
        'colibri.sesion.v1': '{"seccion":0,"solapa":2}',
      });

      final primera = Sesion();
      await primera.cargar();
      expect(primera.solapa, 3);
      await primera.anotar(solapa: primera.solapa);

      // Al abrir de nuevo ya existe el formato nuevo y se queda quieta.
      final segunda = Sesion();
      await segunda.cargar();
      expect(segunda.solapa, 3);
    });
  });
}
