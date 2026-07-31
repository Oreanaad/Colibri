import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/modelos.dart';
import 'package:colibri/pantallas/biblioteca.dart';
import 'package:colibri/pantallas/ficha.dart';
import 'package:colibri/tema.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('abrir un libro no debe trabar la pantalla', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (var i = 0; i < 9; i++) {
      await biblioteca.agregar(
        Libro(id: '/works/$i', titulo: 'Libro número $i', autor: 'Autora $i'),
      );
    }

    final llave = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: llave,
        theme: construirTema(),
        home: const Scaffold(body: PantallaBiblioteca()),
      ),
    );
    await tester.pumpAndSettle();
    debugPrint('MEDIDA · biblioteca: ${tester.allWidgets.length} widgets');

    Future<int> empujar(WidgetBuilder pantalla) async {
      final reloj = Stopwatch()..start();
      llave.currentState!.push(MaterialPageRoute(builder: pantalla));
      await tester.pump(); // el primer dibujado, el que se siente
      reloj.stop();
      await tester.pumpAndSettle();
      final ms = reloj.elapsedMilliseconds;
      llave.currentState!.pop();
      await tester.pumpAndSettle();
      return ms;
    }

    // Referencia: sin esto el número de la ficha no dice nada, porque
    // podría ser todo costo del propio Flutter.
    final vacia = await empujar(
      (_) => const Scaffold(body: Center(child: Text('nada'))),
    );
    final ficha = await empujar((_) => PantallaFicha(biblioteca.todos.first));

    debugPrint('pantalla vacía: $vacia ms · ficha: $ficha ms');

    // Un techo, para que no se vuelva a ir de las manos sin que nadie se
    // entere. La ficha es la pantalla más pesada de la app y la que más
    // se abre: si un día alguien le suma una sección que se construye
    // entera de entrada, este test lo va a cantar.
    //
    // El número sale de medir: con las secciones perezosas queda en
    // menos del triple de una pantalla vacía. Con todo construido de
    // golpe estaba en más de seis veces.
    expect(
      ficha,
      lessThan(vacia * 6),
      reason:
          'abrir un libro se está poniendo lento: \$ficha ms contra '
          '$vacia ms de una pantalla vacía',
    );
  });
}
