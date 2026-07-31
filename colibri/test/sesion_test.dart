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
    expect(b.buscarPorClave(s.libro!), isNull,
        reason: 'y si ya no está, la app lo detecta en vez de romperse');
  });
}
