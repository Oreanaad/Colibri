import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/isbn.dart';

/// Los códigos de barras de la contratapa.
///
/// Todos los números de acá están verificados aparte: los de trece son
/// ISBN reales que Open Library reconoce, y los demás se armaron
/// calculando el dígito de control, no de memoria. Importa porque un
/// número inventado que casualmente no cierra haría pasar un test que
/// prueba lo contrario de lo que dice.
void main() {
  group('leer lo que viene', () {
    test('saca guiones, espacios y lo que sobre', () {
      expect(Isbn.limpiar('978-987-4063-65-6'), '9789874063656');
      expect(Isbn.limpiar('  9789874063656 '), '9789874063656');
      expect(Isbn.limpiar('ISBN 978-987-4063-65-6'), '9789874063656');
    });

    test('la X de los ISBN viejos no se pierde', () {
      // No es una letra suelta: en un ISBN de diez, X vale once y es el
      // dígito de control. Tirarla rompe el número.
      expect(Isbn.limpiar('80-85955-6X'), '80859556X');
      expect(Isbn.limpiar('80-85955-6x'), '80859556X');
    });
  });

  group('el dígito de control', () {
    test('acepta ISBN de trece reales', () {
      for (final i in [
        '9789874063656', // Cometierra
        '9781514385968', // Pedro Páramo
        '9789500767170', // Cien años de soledad
      ]) {
        expect(Isbn.valido(i), isTrue, reason: '$i es un ISBN real');
      }
    });

    test('acepta ISBN de diez', () {
      for (final i in ['9681637720', '8420437484', '0140449132']) {
        expect(Isbn.valido(i), isTrue, reason: '$i tiene control correcto');
      }
    });

    test('rechaza uno con un dígito cambiado', () {
      // Este es Cometierra con el último dígito distinto. Es la razón de
      // ser del dígito de control: atajar la lectura mala antes de salir
      // a preguntarle a internet por un libro que no existe.
      expect(Isbn.valido('9789874063657'), isFalse);
    });

    test('rechaza lo que no tiene diez ni trece caracteres', () {
      for (final i in ['', '978', '97898740636561', 'hola']) {
        expect(Isbn.valido(i), isFalse, reason: '«$i» no puede ser un ISBN');
      }
    });
  });

  group('de diez a trece', () {
    test('convierte poniéndole 978 y recalculando el control', () {
      expect(Isbn.aTrece('9681637720'), '9789681637729');
      expect(Isbn.aTrece('8420437484'), '9788420437484');
      expect(Isbn.aTrece('0140449132'), '9780140449136');
    });

    test('uno de trece se devuelve igual', () {
      expect(Isbn.aTrece('9789874063656'), '9789874063656');
    });

    test('lo inválido no se convierte, devuelve nada', () {
      expect(Isbn.aTrece('9789874063657'), isNull);
      expect(Isbn.aTrece('123'), isNull);
    });
  });

  group('qué es lo que apuntó la cámara', () {
    test('978 y 979 son libros', () {
      expect(Isbn.queEs('9789874063656'), Codigo.libro);
      expect(Isbn.queEs('0140449132'), Codigo.libro); // de diez
    });

    test('977 es una revista', () {
      expect(Isbn.queEs('9770148200006'), Codigo.revista);
    });

    test('9790 es una partitura, aunque empiece con 979', () {
      // Comparten los tres primeros dígitos con los libros: si solo se
      // mirara el prefijo de tres, una partitura pasaría por libro.
      expect(Isbn.queEs('9790123450004'), Codigo.partitura);
    });

    test('cualquier otro prefijo es un producto', () {
      expect(Isbn.queEs('7790123450006'), Codigo.producto);
    });

    test('lo que no cierra es ilegible', () {
      expect(Isbn.queEs('9789874063657'), Codigo.ilegible);
      expect(Isbn.queEs('hola'), Codigo.ilegible);
    });
  });

  group('lo que se le dice a la persona', () {
    test('un libro no tiene nada que explicar', () {
      expect(Isbn.porQueNoSirve('9789874063656'), isNull);
    });

    test('cada problema tiene su propio motivo', () {
      // «No lo encontré» y «eso no es un libro» son cosas distintas: si
      // la app dijera lo mismo en los dos casos, la persona volvería a
      // apuntar al mismo código, que es lo único que seguro no funciona.
      final motivos = {
        Isbn.porQueNoSirve('9770148200006'),
        Isbn.porQueNoSirve('9790123450004'),
        Isbn.porQueNoSirve('7790123450006'),
        Isbn.porQueNoSirve('hola'),
      };
      expect(motivos, hasLength(4));
      expect(motivos.every((m) => m != null && m.isNotEmpty), isTrue);
    });
  });
}
