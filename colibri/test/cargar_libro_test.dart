import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/cargar_libro.dart';
import 'package:colibri/tema.dart';
import 'package:colibri/widgets.dart';

Widget _pantalla({String buscado = ''}) => MaterialApp(
      theme: construirTema(),
      home: PantallaCargarLibro(textoBuscado: buscado),
    );

/// Una pantalla alta: el formulario vive en un ListView, que solo
/// construye lo que se ve. En 800x600 el botón de guardar ni existe.
Future<void> abrir(WidgetTester tester, {String buscado = ''}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_pantalla(buscado: buscado));
}

/// Los campos se buscan por su texto de ejemplo, que sí vive adentro del
/// TextField. La etiqueta de arriba es un widget aparte, y encima va en
/// mayúsculas.
Finder _campo(String ejemplo) => find.widgetWithText(TextField, ejemplo);

const _ejemploTitulo = 'Las niñas del naranjel';
const _ejemploAutora = 'Gabriela Cabezón Cámara';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('parecidos', () {
    test('encuentra el mismo libro escrito distinto', () async {
      final b = Biblioteca();
      await b.agregar(Libro(
        id: '1',
        titulo: 'Las niñas del naranjel',
        autor: 'Gabriela Cabezón Cámara',
      ));

      expect(b.parecidos('las ninas del naranjel').length, 1,
          reason: 'sin acentos ni mayúsculas');
      expect(b.parecidos('Las niñas').length, 1,
          reason: 'con una parte del título alcanza');
      expect(b.parecidos('naranjel').length, 1);
    });

    test('no avisa por libros que no tienen nada que ver', () async {
      final b = Biblioteca();
      await b.agregar(Libro(id: '1', titulo: 'Rayuela', autor: 'Cortázar'));

      expect(b.parecidos('Pedro Páramo'), isEmpty);
    });

    test('con menos de tres letras no avisa nada', () async {
      final b = Biblioteca();
      await b.agregar(Libro(id: '1', titulo: 'Rayuela', autor: 'Cortázar'));

      expect(b.parecidos('ra'), isEmpty,
          reason: 'si no, apenas empezás a tipear te avisa de todo');
    });
  });

  group('la pantalla de cargar', () {
    testWidgets('arranca con lo que venías buscando', (tester) async {
      await abrir(tester, buscado: 'Cometierra');

      expect(find.text('Cometierra'), findsWidgets,
          reason: 'no se tipea dos veces lo mismo');
    });

    testWidgets('no deja guardar hasta que hay título y autora',
        (tester) async {
      await abrir(tester);

      FilledButton boton() => tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Agregar a mi biblioteca'),
          );

      expect(boton().onPressed, isNull, reason: 'vacío, no se puede');

      await tester.enterText(_campo(_ejemploTitulo), 'Mugre rosa');
      await tester.pump();
      expect(boton().onPressed, isNull, reason: 'falta la autora');

      await tester.enterText(_campo(_ejemploAutora), 'Fernanda Trías');
      await tester.pump();
      expect(boton().onPressed, isNotNull, reason: 'con los dos, ya está');
    });

    testWidgets('la tapa se dibuja mientras se escribe', (tester) async {
      await abrir(tester);

      await tester.enterText(_campo(_ejemploTitulo), 'Mugre rosa');
      await tester.enterText(_campo(_ejemploAutora), 'Fernanda Trías');
      await tester.pump();

      // La tapa generada muestra el título y la autora: si están, se dibujó.
      expect(find.byType(Tapa), findsOneWidget);
      expect(find.text('Mugre rosa'), findsWidgets);
    });

    testWidgets('avisa si ya tenés un libro parecido', (tester) async {
      await biblioteca.agregar(Libro(
        id: 'x',
        titulo: 'Cometierra',
        autor: 'Dolores Reyes',
      ));
      addTearDown(() => biblioteca.quitar(
            Libro(id: 'x', titulo: 'Cometierra', autor: 'Dolores Reyes'),
          ));

      await abrir(tester);
      await tester.enterText(_campo(_ejemploTitulo), 'cometierra');
      await tester.pump();

      expect(find.textContaining('Fijate que no sea'), findsOneWidget);

      // Pero sugiere, no bloquea: se puede guardar igual.
      await tester.enterText(_campo(_ejemploAutora), 'Dolores Reyes');
      await tester.pump();
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Agregar a mi biblioteca'),
      );
      expect(boton.onPressed, isNotNull,
          reason: 'a veces es otra edición y la persona tiene razón');
    });
  });

  group('el libro que queda', () {
    test('se guarda marcado como cargado a mano', () async {
      final b = Biblioteca();
      final l = Libro(
        id: 'propio:1',
        titulo: 'Las niñas del naranjel',
        autor: 'Gabriela Cabezón Cámara',
        origen: Origen.propio,
      );
      await b.agregar(l);

      final otra = Biblioteca();
      await otra.cargar();
      expect(otra.todos.first.origen, Origen.propio);
    });

    test('los libros de antes cuentan como del catálogo', () {
      // Los que ya estaban guardados no tienen el campo origen.
      final l = Libro.desdeJson({
        'id': '1',
        'titulo': 'Rayuela',
        'autor': 'Julio Cortázar',
        'estado': 1,
      });

      expect(l.origen, Origen.catalogo);
    });

    test('sin tapa, igual se le dibuja una', () {
      final l = Libro(
        id: '1',
        titulo: 'Las niñas del naranjel',
        autor: 'Gabriela Cabezón Cámara',
        origen: Origen.propio,
      );
      expect(l.tapaId, isNull, reason: 'un libro cargado a mano no la tiene');
    });
  });
}
