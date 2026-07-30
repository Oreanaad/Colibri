import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/epub.dart';
import 'package:colibri/modelos.dart';

/// Arma un EPUB de verdad en memoria: un ZIP con la estructura que
/// tienen los libros reales. Así el test prueba el parser completo y no
/// una versión de mentira.
List<int> epubDePrueba({bool conSpine = true}) {
  final zip = Archive();

  void sumar(String nombre, String contenido) {
    final bytes = utf8.encode(contenido);
    zip.addFile(ArchiveFile(nombre, bytes.length, bytes));
  }

  sumar('mimetype', 'application/epub+zip');
  sumar('META-INF/container.xml', '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/libro.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''');

  sumar('OEBPS/libro.opf', '''
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Pedro Páramo</dc:title>
    <dc:creator>Juan Rulfo</dc:creator>
  </metadata>
  <manifest>
    <item id="c1" href="cap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="cap2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  ${conSpine ? '<spine><itemref idref="c1"/><itemref idref="c2"/></spine>' : ''}
</package>''');

  // Ojo con el orden: cap2 va primero en el ZIP, pero el spine dice que
  // el capítulo 1 se lee antes. El test verifica que gane el spine.
  sumar('OEBPS/cap2.xhtml', '''
<html><body>
  <h1>Segundo</h1>
  <p>Nada se puede hacer contra el olvido, salvo escribirlo todo de nuevo.</p>
  <style>.x { color: red; }</style>
</body></html>''');

  sumar('OEBPS/cap1.xhtml', '''
<html><body>
  <p>Vine a Comala porque me dijeron que ac&#225; viv&#237;a mi padre,
     un tal Pedro P&#225;ramo &mdash; y le promet&#237; que vendr&#237;a a verlo.</p>
  <p>Corto.</p>
  <script>var a = 1;</script>
</body></html>''');

  return ZipEncoder().encode(zip);
}

void main() {
  group('leer un EPUB', () {
    test('saca los párrafos y respeta el orden del spine', () {
      final epub = Epub.abrir(epubDePrueba())!;

      expect(epub.parrafos.length, 2, reason: '"Corto." queda afuera');
      expect(epub.parrafos.first, startsWith('Vine a Comala'),
          reason: 'el spine manda, no el orden dentro del ZIP');
      expect(epub.parrafos.last, contains('el olvido'));
    });

    test('traduce las entidades HTML', () {
      final epub = Epub.abrir(epubDePrueba())!;
      expect(epub.parrafos.first, contains('acá vivía'));
      expect(epub.parrafos.first, contains('Páramo —'));
    });

    test('no se cuela nada de script ni de style', () {
      final epub = Epub.abrir(epubDePrueba())!;
      final todo = epub.parrafos.join(' ');
      expect(todo, isNot(contains('var a')));
      expect(todo, isNot(contains('color: red')));
      expect(todo, isNot(contains('<')));
    });

    test('descarta los fragmentos cortos, que son títulos o notas', () {
      final epub = Epub.abrir(epubDePrueba())!;
      expect(epub.parrafos.any((p) => p == 'Corto.'), isFalse);
      expect(epub.parrafos.any((p) => p == 'Segundo'), isFalse);
    });

    test('lee el título y la autoría del propio archivo', () {
      final epub = Epub.abrir(epubDePrueba())!;
      expect(epub.titulo, 'Pedro Páramo');
      expect(epub.autor, 'Juan Rulfo');
    });

    test('si no hay spine, ordena por nombre de archivo', () {
      final epub = Epub.abrir(epubDePrueba(conSpine: false))!;
      expect(epub.parrafos.length, 2);
      expect(epub.parrafos.first, startsWith('Vine a Comala'),
          reason: 'cap1 antes que cap2, por nombre');
    });

    test('un archivo que no es EPUB devuelve null en vez de romper', () {
      expect(Epub.abrir(utf8.encode('esto no es un zip')), isNull);
    });
  });

  group('buscar una frase', () {
    late Epub epub;
    setUp(() => epub = Epub.abrir(epubDePrueba())!);

    test('encuentra sin acentos y sin mayúsculas', () {
      // Así se acuerda la gente: mal.
      final r = epub.buscar('ACA VIVIA MI PADRE');
      expect(r.length, 1);
      expect(r.first.parrafo, contains('acá vivía mi padre'));
    });

    test('devuelve el párrafo entero, no solo lo buscado', () {
      final r = epub.buscar('Comala');
      expect(r.first.parrafo, startsWith('Vine a Comala'));
      expect(r.first.parrafo, endsWith('a verlo.'));
    });

    test('con menos de cuatro letras no busca nada', () {
      expect(epub.buscar('de'), isEmpty,
          reason: 'si no, cualquier palabra devuelve el libro entero');
    });

    test('sabe en qué parte del libro está', () {
      final r = epub.buscar('olvido');
      expect(r.first.porcentaje(epub.parrafos.length), greaterThan(0));
    });
  });

  group('el tope de una frase', () {
    test('una frase larga se corta en el tope', () {
      final larguisimo = 'a' * 2000;
      final f = Frase(texto: larguisimo);

      expect(f.texto.length, lessThanOrEqualTo(Frase.topeDeCaracteres + 1));
      expect(f.texto, endsWith('…'));
    });

    test('una frase normal no se toca', () {
      const normal = 'Vine a Comala porque me dijeron que acá vivía mi padre.';
      expect(Frase(texto: normal).texto, normal);
    });
  });
}
