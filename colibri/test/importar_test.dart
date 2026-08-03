import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/goodreads.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/importar.dart';

/// Sumar la biblioteca entera de una.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await biblioteca.cargar();
    for (final l in [...biblioteca.todos]) {
      await biblioteca.quitar(l);
    }
  });

  Libro libro(String titulo, {String autor = 'Alguien'}) =>
      Libro(id: titulo, titulo: titulo, autor: autor);

  group('sumar muchos de una', () {
    test('entran todos y dice cuántos', () async {
      final entraron = await biblioteca.agregarVarios([
        libro('Cometierra'),
        libro('Las malas'),
        libro('Catedrales'),
      ]);

      expect(entraron, 3);
      expect(biblioteca.todos, hasLength(3));
    });

    test('los que ya tenías no se duplican ni se pisan', () async {
      // Lo más importante de todo esto. Si ya tenías Cometierra con cinco
      // estrellas y tu reseña, lo que trae Goodreads no puede reemplazarla:
      // esa reseña la escribiste acá.
      final mio = libro('Cometierra')
        ..puntaje = 5
        ..resena = 'Lo leí de un tirón';
      await biblioteca.agregar(mio);

      final entraron = await biblioteca.agregarVarios([
        libro('cometierra'), // mismo libro, otra forma de escribirlo
        libro('Las malas'),
      ]);

      expect(entraron, 1);
      expect(biblioteca.todos, hasLength(2));
      expect(
        biblioteca.buscarPorClave(mio.clave)!.resena,
        'Lo leí de un tirón',
      );
      expect(biblioteca.buscarPorClave(mio.clave)!.puntaje, 5);
    });

    test('una lista vacía no hace nada', () async {
      expect(await biblioteca.agregarVarios(const []), 0);
      expect(biblioteca.todos, isEmpty);
    });

    test('sobreviven a cerrar y volver a abrir la app', () async {
      final archivo =
          'Title,Author,Exclusive Shelf,My Rating,Bookshelves\n'
          '"Cometierra","Dolores Reyes",read,5,"favoritos"\n'
          '"Las malas","Camila Sosa Villada",to-read,0,""\n';

      await biblioteca.agregarVarios(Goodreads.leer(archivo).libros);

      // La prueba de fuego: cerrar y volver a entrar.
      final otra = Biblioteca();
      await otra.cargar();

      expect(otra.todos, hasLength(2));
      final cometierra = otra.todos.firstWhere((l) => l.titulo == 'Cometierra');
      expect(cometierra.estado, Estado.leido);
      expect(cometierra.puntaje, 5);
      expect(cometierra.estantes, {'favoritos'});
    });
  });

  group('la pantalla', () {
    testWidgets('explica cómo sacar el archivo antes de pedirlo', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: PantallaImportar()));
      await tester.pumpAndSettle();

      // Nadie sabe de memoria dónde está el export en Goodreads. Si la
      // pantalla solo dice «elegí el archivo», no se puede usar.
      expect(find.textContaining('Import and Export'), findsOneWidget);
      expect(find.textContaining('Export Library'), findsOneWidget);
      expect(find.text('Elegir el archivo'), findsOneWidget);
    });

    testWidgets('promete que nada sale del teléfono', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PantallaImportar()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nada sale de tu teléfono'), findsOneWidget);
    });
  });
}
