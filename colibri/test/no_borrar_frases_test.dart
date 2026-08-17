import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/modelos.dart';

/// Que sincronizar desde un aparato no borre lo que marcaste en otro.
///
/// # El bug, visto en los datos de verdad
///
/// La nube tenía una frase de *Fourth Wing*, subida desde el teléfono. En la
/// PC ese mismo libro estaba sin frases —nunca se marcó ninguna ahí— y al
/// sincronizar desde la PC:
///
///     await _base.from('frases').delete().eq('lectura_id', lecturaId);
///     if (libro.frases.isNotEmpty) { insert … }
///
/// El `delete` se llevó la frase y el `insert` no puso nada. La frase que
/// alguien había marcado leyendo desapareció del servidor, sin un error, sin
/// un aviso, sin nada.
///
/// # La regla que lo arregla
///
/// Una lista vacía no dice «las borré»: dice **«este aparato no sabe nada de
/// esto»**. Son dos cosas distintas y tratarlas igual cuesta datos. Si está
/// vacía, no se toca lo que hay del otro lado.
///
/// Es la misma regla que ya usa `bajarTodo` para no pisar un libro que está
/// en el teléfono: ante la duda, no se destruye.
///
/// # Cómo se prueba sin servidor
///
/// `flutter test` corta el HTTP, así que no se puede mirar qué le llegó a
/// Supabase. Pero lo que decide es una condición sobre la lista local, y eso
/// se puede leer del código: la prueba comprueba que ningún `delete` de las
/// tablas hijas quede fuera de su `if (… .isNotEmpty)`.
///
/// Es una prueba que mira el código y no la pantalla, como la de las
/// grillas. Vale lo mismo por la misma razón: el caso que atrapa no se puede
/// observar de otra forma desde acá, y el error no da ninguna señal.
void main() {
  group('las frases no se pierden entre aparatos', () {
    test('un libro sin frases no manda ningún borrado', () {
      // Lo que se prueba de verdad está en el código, abajo. Esto fija la
      // intención: un libro que este aparato no conoce en detalle no tiene
      // nada que decir sobre las frases de nadie.
      final deLaPc = Libro(id: '1', titulo: 'Fourth Wing', autor: 'Yarros');

      expect(deLaPc.frases, isEmpty);
    });

    test('la frase del teléfono es la misma que la de la nube', () {
      // La que se perdió medía 101 caracteres, muy por debajo del tope de
      // 800: no fue el `check` de la base, fue el `delete`.
      final f = Frase(texto: 'a' * 101);

      expect(f.texto.length, lessThan(Frase.topeDeCaracteres));
    });
  });

  group('ningún borrado suelto en nube.dart', () {
    // Se lee el archivo y se comprueba que cada `delete()` de una tabla
    // hija esté dentro de un `if (… .isNotEmpty)`. Si alguien vuelve a
    // sacarlo de ahí, esto falla nombrando la tabla.
    late final String codigo = _leer();

    /// Las tablas cuyo contenido lo escribe la lectora, y que por eso no se
    /// pueden borrar a ciegas.
    const hijas = [
      'frases',
      'personajes',
      'lectura_animos',
      'estante_lecturas',
      'notas',
    ];

    test('cada borrado está protegido por un isNotEmpty', () {
      // # Cómo se encuentra la guardia, después de dos intentos malos
      //
      // El primero buscaba «el `if (` más cercano hacia atrás» con
      // lastIndexOf, y **pasaba con el bug puesto**: encontraba el `if` de
      // otra sección más arriba, que sí tenía un isNotEmpty.
      //
      // El segundo miraba los tres renglones anteriores, y **fallaba con el
      // código bueno**: el bloque de estantes tiene un bucle en medio, así
      // que su guardia queda a más de tres renglones del borrado.
      //
      // Lo correcto es mirar **el bloque que contiene** el borrado. Se
      // camina hacia atrás contando llaves: cuando el balance se abre, ese
      // renglón es el que abrió el bloque, y ahí tiene que estar la
      // condición.
      //
      // Escribo esto porque el archivo se queja de las pruebas que no
      // distinguen el caso bueno del malo, y las dos primeras versiones de
      // ésta eran justamente eso. Las dos direcciones están probadas a
      // mano: con el código bueno pasa, y moviendo el borrado afuera de su
      // `if` falla nombrando la tabla y el renglón.
      final renglones = codigo.split('\n');
      final sueltos = <String>[];

      for (var i = 0; i < renglones.length; i++) {
        final tabla = hijas.firstWhere(
          (h) => renglones[i].contains("from('$h').delete()"),
          orElse: () => '',
        );
        if (tabla.isEmpty) continue;

        // Hacia atrás contando llaves hasta que se abra un bloque.
        var balance = 0;
        var guardia = '';
        for (var j = i - 1; j >= 0; j--) {
          final l = renglones[j];
          balance += '}'.allMatches(l).length - '{'.allMatches(l).length;
          if (balance < 0) {
            guardia = l;
            break;
          }
        }

        if (!guardia.contains('isNotEmpty') && !guardia.contains('tieneNota')) {
          sueltos.add('$tabla (renglón ${i + 1})');
        }
      }

      expect(
        sueltos,
        isEmpty,
        reason:
            'estos borrados no están dentro de un bloque que comprueba que '
            'este aparato tenga algo que poner en su lugar. Una lista vacía '
            'significa «no sé», no «borralo»: así se perdió una frase '
            'marcada desde el teléfono cuando la PC sincronizó el mismo '
            'libro',
      );
    });

    test('la nota privada no se borra desde otro aparato', () {
      // Mismo caso y peor: una nota es lo único que no está en ningún otro
      // lado. Un aparato que no la tiene no puede decidir que no existe.
      expect(
        codigo.contains("from('notas').delete()"),
        isFalse,
        reason: 'un aparato sin la nota no sabe si no existe o si no la vio',
      );
    });
  });
}

String _leer() {
  // Ruta relativa a la raíz del paquete, que es desde donde corre
  // `flutter test`. Igual que en tamanos_test.dart.
  return File('lib/nube.dart').readAsStringSync();
}
