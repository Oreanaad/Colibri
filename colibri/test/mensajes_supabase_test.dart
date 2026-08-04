import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:colibri/servidor_supabase.dart';

/// Los mensajes de error, en castellano.
///
/// Supabase contesta en inglés y escrito para quien programa: «Invalid
/// login credentials» no le dice a nadie que se equivocó de contraseña.
///
/// Los códigos de acá abajo son los que devuelve el proyecto de verdad,
/// preguntados con curl, no sacados de la documentación.
void main() {
  String deAuth(String codigo, [String mensaje = 'Something went wrong']) =>
      ServidorSupabase.mensajeDeAuth(AuthException(mensaje, code: codigo));

  group('errores de la cuenta', () {
    test('la contraseña equivocada se explica', () {
      // Este es el código que contestó el proyecto al probarlo.
      final m = deAuth('invalid_credentials', 'Invalid login credentials');

      expect(m, contains('no coinciden'));
      expect(m, isNot(contains('Invalid')));
    });

    test('el correo sin confirmar dice dónde mirar', () {
      final m = deAuth('email_not_confirmed');

      expect(m, contains('confirmaste'));
      // Se esconden ahí más seguido de lo que uno quisiera.
      expect(m, contains('no deseado'));
    });

    test('un correo ya usado manda a entrar, no a intentar de nuevo', () {
      for (final codigo in ['user_already_exists', 'email_exists']) {
        expect(deAuth(codigo), contains('entrando'), reason: codigo);
      }
    });

    test('la contraseña corta dice cuánto le falta', () {
      // «Password should be at least 6 characters» no dice cuántos son
      // seis si no sabés inglés.
      expect(deAuth('weak_password'), contains('seis'));
    });

    test('un código que no conocemos deja pasar el original', () {
      // Es a propósito: un «algo salió mal» no se puede ni buscar. Vale
      // más un mensaje en inglés que uno inútil en castellano.
      expect(
        deAuth('algo_nuevo_que_inventaron', 'Some new thing happened'),
        'Some new thing happened',
      );
    });

    test('todos los mensajes están en castellano y no repetidos', () {
      final mensajes = [
        'invalid_credentials',
        'email_not_confirmed',
        'user_already_exists',
        'weak_password',
        'over_email_send_rate_limit',
        'validation_failed',
      ].map(deAuth).toList();

      // Si dos códigos distintos dieran el mismo texto, uno de los dos
      // estaría mandando a la persona a arreglar lo que no es.
      expect(mensajes.toSet(), hasLength(mensajes.length));
      for (final m in mensajes) {
        expect(m, isNot(contains('Something')), reason: m);
      }
    });
  });

  group('errores de la base', () {
    String deLaBase(String codigo) => ServidorSupabase.mensajeDeLaBase(
      PostgrestException(message: 'duplicate key value', code: codigo),
    );

    test('un @usuario tomado se explica', () {
      // 23505 es «ya existe uno igual». En perfiles solo puede ser el
      // @usuario: es el único marcado como único.
      expect(deLaBase('23505'), contains('ya lo tiene'));
    });

    test('un @usuario que no cumple las reglas de la base', () {
      // 23514 es una regla check. Puede pasar si la app deja pasar algo
      // que la base no: las dos tienen las mismas reglas escritas, y esto
      // es la red por si alguna vez dejan de coincidir.
      expect(deLaBase('23514'), contains('reglas'));
    });

    test('un permiso denegado no dice «42501»', () {
      final m = deLaBase('42501');

      expect(m, contains('permiso'));
      expect(m, isNot(contains('42501')));
    });

    test('un código desconocido deja pasar el original', () {
      expect(deLaBase('XX999'), 'duplicate key value');
    });
  });
}
