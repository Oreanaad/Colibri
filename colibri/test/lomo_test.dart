import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colibri/foto.dart';
import 'package:colibri/lomo.dart';
import 'package:colibri/modelos.dart';

/// La foto del lomo, y el color que la app le saca sola a la tapa.
///
/// # Qué se puede y qué no, comprobado
///
/// Lo primero que hice fue preguntar si «que la app lo busque automático»
/// era posible tal cual. No lo es: **ningún catálogo publica fotos de
/// lomos**. Contra Open Library, que es el que usa la app:
///
///     covers.openlibrary.org/b/id/8231856-spine.jpg   404
///     covers.openlibrary.org/b/id/8231856-back.jpg    404
///
/// El campo `covers` de una edición trae solo tapas de frente. Así que el
/// lomo de verdad —con su tipografía, su editorial, su desgaste— solo
/// entra si alguien le saca la foto al libro que tiene en la mano.
///
/// Lo que **sí** puede hacer sola la app es sacarle el color a la tapa y
/// pintar el lomo con eso. Una repisa donde cada lomo tiene el color de su
/// propio libro se parece muchísimo más a una biblioteca que una donde los
/// colores salen del hash del título.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('el color que manda en una tapa', () {
    test('una tapa roja da un color rojo', () {
      final tapa = img.Image(width: 100, height: 150);
      img.fill(tapa, color: img.ColorRgb8(190, 40, 40));

      final color = FotoDeLomo.colorQueManda(img.encodePng(tapa));

      expect(color, isNotNull);
      final r = (color! >> 16) & 0xFF;
      final g = (color >> 8) & 0xFF;
      final b = color & 0xFF;
      expect(r, greaterThan(g + 60), reason: 'el rojo tiene que dominar');
      expect(r, greaterThan(b + 60));
    });

    test('el color que más ocupa gana, no el del medio', () {
      // Una tapa mayormente verde con una mancha azul chica. El resultado
      // tiene que ser verde: lo que se ve de lejos es lo que más ocupa.
      final tapa = img.Image(width: 100, height: 100);
      img.fill(tapa, color: img.ColorRgb8(40, 150, 60));
      img.fillRect(
        tapa,
        x1: 40,
        y1: 40,
        x2: 60,
        y2: 60,
        color: img.ColorRgb8(30, 40, 200),
      );

      final color = FotoDeLomo.colorQueManda(img.encodePng(tapa));

      expect(color, isNotNull);
      expect((color! >> 8) & 0xFF, greaterThan(color & 0xFF));
    });

    test('una tapa blanca no da color', () {
      // Muchísimas tapas son casi blancas con letras. Si el blanco contara,
      // media repisa quedaría del mismo gris clarísimo, que es peor que el
      // color inventado del título: por lo menos ése los distingue.
      final tapa = img.Image(width: 60, height: 60);
      img.fill(tapa, color: img.ColorRgb8(252, 251, 250));

      expect(FotoDeLomo.colorQueManda(img.encodePng(tapa)), isNull);
    });

    test('una tapa gris tampoco', () {
      final tapa = img.Image(width: 60, height: 60);
      img.fill(tapa, color: img.ColorRgb8(128, 130, 129));

      expect(FotoDeLomo.colorQueManda(img.encodePng(tapa)), isNull);
    });

    test('un archivo que no es imagen no rompe nada', () {
      expect(FotoDeLomo.colorQueManda([1, 2, 3, 4, 5]), isNull);
    });
  });

  group('la foto del lomo se achica antes de guardarse', () {
    test('una foto de teléfono queda en 160 de ancho', () {
      // Una foto de iPhone son ~3 MB. Guardada tal cual en
      // SharedPreferences, veinte libros son 60 MB de base64 en el disco
      // del teléfono para dibujar rectángulos de 20 píxeles de ancho.
      final grande = img.Image(width: 3024, height: 4032);
      img.fill(grande, color: img.ColorRgb8(90, 60, 120));

      final chica = FotoDeLomo.preparar(img.encodeJpg(grande));

      expect(chica, isNotNull);
      final leida = img.decodeJpg(chica!)!;
      expect(leida.width, FotoDeLomo.ancho);
      // La proporción se respeta: un lomo es alto y angosto, y estirarlo a
      // un cuadrado le deforma el título.
      expect(leida.height, closeTo(4032 * 160 / 3024, 2));
    });

    test('pesa poco', () {
      final grande = img.Image(width: 2000, height: 3000);
      img.fill(grande, color: img.ColorRgb8(120, 30, 40));

      final chica = FotoDeLomo.preparar(img.encodeJpg(grande))!;

      expect(chica.length, lessThan(60 * 1024));
    });

    test('un archivo que no es foto devuelve null y no explota', () {
      expect(FotoDeLomo.preparar([0, 1, 2]), isNull);
    });
  });

  group('los lomos guardados', () {
    final libro = Libro(
      id: '1',
      titulo: 'Fourth Wing',
      autor: 'Yarros',
      tapaUrl: 'https://covers.openlibrary.org/b/id/1-M.jpg',
    );

    test('sin nada guardado, un libro no tiene ni foto ni color', () {
      final l = Lomos();
      expect(l.fotoDe('x'), isNull);
      expect(l.colorDe('x'), isNull);
      expect(l.tieneFoto('x'), isFalse);
      expect(l.yaSeMiro('x'), isFalse);
    });

    test('la tapa le da el color al lomo', () async {
      final tapa = img.Image(width: 80, height: 120);
      img.fill(tapa, color: img.ColorRgb8(30, 60, 170));

      final l = Lomos(cliente: _Falso(200, img.encodePng(tapa)));
      final aprendio = await l.mirarLaTapa(libro);

      expect(aprendio, isTrue);
      final color = l.colorDe(libro.clave)!;
      expect(color & 0xFF, greaterThan((color >> 16) & 0xFF));
    });

    test('mirar dos veces no pide dos veces', () async {
      final tapa = img.Image(width: 40, height: 60);
      img.fill(tapa, color: img.ColorRgb8(160, 50, 30));
      final cliente = _Falso(200, img.encodePng(tapa));

      final l = Lomos(cliente: cliente);
      await l.mirarLaTapa(libro);
      await l.mirarLaTapa(libro);

      expect(cliente.pedidos, 1, reason: 'una tapa se baja una sola vez');
    });

    test('sin red, el libro queda sin mirar y se reintenta', () async {
      // El caso «abrió la app en el subte». Si el fallo se anotara como
      // «este libro no tiene color», el lomo quedaría del color inventado
      // para siempre, sin forma de arreglarlo salvo desinstalando.
      final l = Lomos(cliente: _Roto());
      final aprendio = await l.mirarLaTapa(libro);

      expect(aprendio, isFalse);
      expect(
        l.yaSeMiro(libro.clave),
        isFalse,
        reason: 'un fallo de red no es una respuesta sobre el libro',
      );
    });

    test('un 503 tampoco lo marca', () async {
      final l = Lomos(cliente: _Falso(503, []));
      await l.mirarLaTapa(libro);

      expect(l.yaSeMiro(libro.clave), isFalse);
    });

    test('un 404 sí lo marca, para no pedirlo en cada arranque', () async {
      // Distinto: acá el servidor contestó. Esa tapa no existe y no va a
      // existir por preguntar de nuevo mañana.
      final cliente = _Falso(404, []);
      final l = Lomos(cliente: cliente);

      await l.mirarLaTapa(libro);
      await l.mirarLaTapa(libro);

      expect(l.yaSeMiro(libro.clave), isTrue);
      expect(l.colorDe(libro.clave), isNull);
      expect(cliente.pedidos, 1);
    });

    test('un libro sin tapa no genera ni un pedido', () async {
      final cliente = _Falso(200, []);
      final l = Lomos(cliente: cliente);
      final sinTapa = Libro(id: '2', titulo: 'Sin tapa', autor: 'Nadie');

      await l.mirarLaTapa(sinTapa);

      expect(cliente.pedidos, 0);
      expect(l.yaSeMiro(sinTapa.clave), isTrue);
    });

    test('la foto guardada se lee de vuelta', () async {
      final l = Lomos();
      await l.guardarFoto(libro.clave, 'unbase64');

      expect(l.tieneFoto(libro.clave), isTrue);

      // Otra instancia, como al abrir la app de nuevo.
      final otra = Lomos();
      await otra.cargar();
      expect(otra.fotoDe(libro.clave), 'unbase64');
    });

    test('quitar la foto la quita de verdad', () async {
      final l = Lomos();
      await l.guardarFoto(libro.clave, 'unbase64');
      await l.quitarFoto(libro.clave);

      final otra = Lomos();
      await otra.cargar();
      expect(otra.tieneFoto(libro.clave), isFalse);
    });

    test('la foto le gana al color de la tapa', () async {
      // No es una preferencia estética: la foto es el lomo de verdad, con
      // su tipografía y su editorial. El color es una aproximación.
      final tapa = img.Image(width: 40, height: 60);
      img.fill(tapa, color: img.ColorRgb8(30, 140, 60));

      final l = Lomos(cliente: _Falso(200, img.encodePng(tapa)));
      await l.mirarLaTapa(libro);
      await l.guardarFoto(libro.clave, 'unbase64');

      expect(l.fotoDe(libro.clave), isNotNull);
      expect(l.colorDe(libro.clave), isNotNull);
      // Las dos cosas conviven: quitar la foto tiene que devolver el color
      // de la tapa, no dejar el libro sin nada.
      await l.quitarFoto(libro.clave);
      expect(l.colorDe(libro.clave), isNotNull);
    });
  });

  group('un estante entero', () {
    test('solo se piden las tapas que faltan', () async {
      final tapa = img.Image(width: 40, height: 60);
      img.fill(tapa, color: img.ColorRgb8(120, 40, 90));
      final cliente = _Falso(200, img.encodePng(tapa));
      final l = Lomos(cliente: cliente);

      final libros = [
        for (var i = 0; i < 7; i++)
          Libro(
            id: '$i',
            titulo: 'Libro $i',
            autor: 'A',
            tapaUrl: 'https://covers.openlibrary.org/b/id/$i-M.jpg',
          ),
      ];

      expect(await l.mirarLasTapas(libros), isTrue);
      expect(cliente.pedidos, 7);

      // Volver a entrar al estante no baja nada.
      expect(await l.mirarLasTapas(libros), isFalse);
      expect(cliente.pedidos, 7);
    });
  });
}

/// Un cliente que contesta siempre lo mismo, y cuenta cuántas veces le
/// preguntaron.
class _Falso extends http.BaseClient {
  final int estado;
  final List<int> cuerpo;
  int pedidos = 0;

  _Falso(this.estado, this.cuerpo);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest pedido) async {
    pedidos++;
    return http.StreamedResponse(Stream.value(cuerpo), estado);
  }
}

/// Un cliente sin red.
class _Roto extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest pedido) async {
    throw http.ClientException('sin red');
  }
}
