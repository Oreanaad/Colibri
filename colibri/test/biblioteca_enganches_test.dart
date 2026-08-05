import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';

/// Los enganches de Biblioteca hacia afuera.
///
/// Biblioteca no sabe que existe una nube: por eso nunca importa
/// `nube.dart` acá. Lo que se prueba es el enganche en sí —que cada
/// mutación avise, con el libro correcto, en el momento correcto— con un
/// callback que solo anota lo que recibió.
void main() {
  late List<Libro> avisados;
  late List<String> quitados;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
    avisados = [];
    quitados = [];
    biblioteca.alGuardarUnLibro = avisados.add;
    biblioteca.alQuitarUnLibro = quitados.add;
  });

  tearDown(() {
    biblioteca.alGuardarUnLibro = null;
    biblioteca.alQuitarUnLibro = null;
  });

  Libro libro(String id) => Libro(id: id, titulo: 'Libro $id', autor: 'x');

  group('agregar', () {
    test('avisa con el libro que se agregó', () async {
      final l = libro('1');
      await biblioteca.agregar(l);

      expect(avisados, [l]);
    });

    test('uno repetido no avisa dos veces', () async {
      final l = libro('1');
      await biblioteca.agregar(l);
      await biblioteca.agregar(libro('1')); // misma clave

      expect(avisados, hasLength(1));
    });
  });

  group('agregarVarios', () {
    test('avisa uno por cada libro nuevo', () async {
      await biblioteca.agregarVarios([libro('1'), libro('2'), libro('3')]);

      expect(avisados, hasLength(3));
    });

    test('los que ya estaban no avisan', () async {
      await biblioteca.agregar(libro('1'));
      avisados.clear();

      await biblioteca.agregarVarios([libro('1'), libro('2')]);

      // Solo el nuevo. Si el repetido también avisara, se subiría de
      // nuevo un libro que no cambió.
      expect(avisados, hasLength(1));
      expect(avisados.single.id, '2');
    });
  });

  group('quitar', () {
    test('avisa con la clave, no con el libro', () async {
      final l = libro('1');
      await biblioteca.agregar(l);
      avisados.clear();

      await biblioteca.quitar(l);

      expect(quitados, [l.clave]);
    });
  });

  group('actualizar', () {
    test('sin lista, no avisa nada', () async {
      final l = libro('1');
      await biblioteca.agregar(l);
      avisados.clear();

      await biblioteca.actualizar();

      expect(avisados, isEmpty);
    });

    test('con el libro, avisa ese libro', () async {
      final l = libro('1');
      await biblioteca.agregar(l);
      avisados.clear();

      l.resena = 'algo';
      await biblioteca.actualizar([l]);

      expect(avisados, [l]);
    });
  });

  group('cambiarEstado', () {
    test('avisa, incluso cuando deshace un toque sin querer', () async {
      final l = libro('1');
      await biblioteca.agregar(l);
      avisados.clear();

      await biblioteca.cambiarEstado(l, Estado.leido);
      await biblioteca.cambiarEstado(l, Estado.leido); // lo deshace

      // Los dos toques cambiaron algo de verdad —el estado, después las
      // fechas— y los dos tienen que llegar a la nube.
      expect(avisados, hasLength(2));
    });
  });

  group('los estantes', () {
    test('alternarEstante avisa el libro tocado', () async {
      final l = libro('1');
      await biblioteca.agregar(l);
      avisados.clear();

      await biblioteca.alternarEstante(l, 'Favoritos');

      expect(avisados, [l]);
    });

    test('borrarEstante avisa solo a los libros que lo tenían', () async {
      final con = libro('1');
      final sin = libro('2');
      await biblioteca.agregar(con);
      await biblioteca.agregar(sin);
      await biblioteca.alternarEstante(con, 'Favoritos');
      avisados.clear();

      await biblioteca.borrarEstante('Favoritos');

      expect(avisados, [con]);
    });

    test('renombrarEstante avisa a los que lo tenían puesto', () async {
      final con = libro('1');
      final sin = libro('2');
      await biblioteca.agregar(con);
      await biblioteca.agregar(sin);
      await biblioteca.crearEstante('Viejo');
      await biblioteca.alternarEstante(con, 'Viejo');
      avisados.clear();

      await biblioteca.renombrarEstante('Viejo', 'Nuevo');

      expect(avisados, [con]);
    });
  });
}
