import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:colibri/cuenta.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/biblioteca.dart';
import 'package:colibri/widgets.dart';

const pantallas = [
  ('iPhone SE       320', Size(320, 568)),
  ('iPhone 13 mini  375', Size(375, 812)),
  ('iPhone 13       390', Size(390, 844)),
  ('iPhone 15 Pro M 430', Size(430, 932)),
];

void main() {
  testWidgets('geometría real de la grilla', (tester) async {
    // ignore: avoid_print
    print('\n--- la grilla de libros ---');
    for (final (etiqueta, tamano) in pantallas) {
      SharedPreferences.setMockInitialValues({});
      await biblioteca.cargar();
      for (final l in [...biblioteca.todos]) { await biblioteca.quitar(l); }
      await cuenta.crear(usuario: 'lectora', nombre: 'Lucía');

      for (var i = 0; i < 6; i++) {
        await biblioteca.agregar(
          Libro(id: '$i', titulo: 'Libro número $i', autor: 'Alguien'),
        );
      }

      await tester.binding.setSurfaceSize(tamano);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PantallaBiblioteca())),
      );
      await tester.pumpAndSettle();

      final tapas = find.byType(Tapa);
      if (tapas.evaluate().isEmpty) {
        // ignore: avoid_print
        print('  $etiqueta  sin tapas');
        continue;
      }

      // Cuántas caben en la primera fila: las que comparten el mismo y.
      final cajas = tapas.evaluate().map((e) => tester.getRect(find.byWidget(e.widget))).toList();
      final primerY = cajas.first.top;
      final enFila = cajas.where((c) => (c.top - primerY).abs() < 1).length;
      final ancho = cajas.first.width;

      // ignore: avoid_print
      print('  $etiqueta  ->  $enFila columnas, tapa de ${ancho.toStringAsFixed(0)} px');
    }
    await tester.binding.setSurfaceSize(null);
    // ignore: avoid_print
    print('--- fin ---\n');
  });
}
