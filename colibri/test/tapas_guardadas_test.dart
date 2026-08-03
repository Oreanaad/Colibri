import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/api.dart';
import 'package:colibri/modelos.dart';
import 'package:colibri/widgets.dart';

/// Las tapas, guardadas para no bajarlas de nuevo.
///
/// Medido antes de escribir esto: la tapa de la grilla pesa 25 KB y la de
/// la ficha 68 KB, los servidores dan permiso de guardarlas tres horas y no
/// mandan `etag`, así que al vencerse se bajan enteras otra vez. Con
/// sesenta libros, un mega y medio cada vez.
void main() {
  Future<void> dibujar(
    WidgetTester tester,
    Libro libro, {
    String tamano = 'M',
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Tapa(libro, tamano: tamano)),
        ),
      ),
    );
  }

  testWidgets('una tapa de Open Library se pide por el guardado', (
    tester,
  ) async {
    await dibujar(tester, Libro(id: '1', titulo: 't', autor: 'a', tapaId: 42));

    // Si esto vuelve a ser un Image.network, cada vez que alguien abra la
    // app en el teléfono se bajan todas las tapas de nuevo.
    expect(find.byType(CachedNetworkImage), findsWidgets);
  });

  testWidgets('una tapa de Google también', (tester) async {
    await dibujar(
      tester,
      Libro(
        id: '2',
        titulo: 't',
        autor: 'a',
        tapaUrl: 'https://books.google.com/tapa.jpg',
      ),
    );

    expect(find.byType(CachedNetworkImage), findsWidgets);
  });

  testWidgets('un libro sin tapa no pide nada a internet', (tester) async {
    final sinTapa = Libro(id: '3', titulo: 'Cometierra', autor: 'Dolores');
    expect(Api.tapaDe(sinTapa), isNull);

    await dibujar(tester, sinTapa);

    // Debajo siempre está la tapa dibujada, así que no hay rectángulo
    // vacío ni pedido inútil.
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.textContaining('Cometierra'), findsWidgets);
  });

  testWidgets('en la ficha se pide la grande y la mediana de puente', (
    tester,
  ) async {
    await dibujar(
      tester,
      Libro(id: '4', titulo: 't', autor: 'a', tapaId: 42),
      tamano: 'L',
    );

    // La mediana ya está guardada de haber pasado por la lista, así que
    // se ve al instante mientras baja la grande. Son dos, no una.
    expect(find.byType(CachedNetworkImage), findsNWidgets(2));
  });
}
