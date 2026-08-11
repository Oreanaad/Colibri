import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:colibri/servidor_supabase.dart';

/// A dónde vuelve la lectora después de tocar el enlace del correo.
///
/// # El bug que esto atrapa
///
/// El primero fue que el correo llegaba con un enlace a `localhost:3000`,
/// que es lo que Supabase pone de fábrica: apuntaba a la computadora de
/// quien abría el correo, donde no hay nada corriendo. Se arregló pasando
/// la dirección de la app publicada.
///
/// El segundo aparece recién en el teléfono, y es más silencioso: esa
/// dirección es `https://`, así que el teléfono la abre con el navegador.
/// La cuenta queda confirmada —el enlace funcionó— pero la lectora termina
/// en Safari mirando la versión web, mientras la app que tiene abierta
/// sigue esperando en la pantalla de registro. Parece que no pasó nada.
///
/// # Por qué se prueban los archivos y no solo el código
///
/// El esquema `ar.colibri.colibri://` no lo entiende internet: lo entiende
/// el sistema operativo, y solo si está declarado en el Info.plist de iOS
/// y en el AndroidManifest. Son tres lugares que dicen la misma cadena, y
/// cambiar uno solo no da ningún error: simplemente el enlace no abre la
/// app, en un teléfono, después de compilar. Acá se comparan los tres.
void main() {
  group('la dirección de vuelta', () {
    test('en el teléfono vuelve a la app, no al navegador', () {
      final vuelta = vueltaDelCorreo(enLaWeb: false);

      expect(vuelta, startsWith('$esquemaPropio://'));
      expect(
        vuelta,
        isNot(startsWith('http')),
        reason: 'una dirección web la abre el navegador, no la app',
      );
    });

    test('en la web sigue siendo la dirección web', () {
      // Sin claves al compilar queda vacía, y entonces no se le pasa nada
      // a Supabase. Lo que importa es que no le llegue el esquema propio:
      // un navegador no sabe qué hacer con eso.
      expect(vueltaDelCorreo(enLaWeb: true), isNot(contains('://login')));
    });
  });

  group('los tres lugares dicen lo mismo', () {
    test('iOS declara el esquema', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(
        plist,
        contains('CFBundleURLSchemes'),
        reason: 'sin esto, iOS no sabe que este esquema abre Colibrí',
      );
      expect(plist, contains('<string>$esquemaPropio</string>'));
    });

    test('Android declara el esquema', () {
      final manifiesto = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifiesto, contains('android:scheme="$esquemaPropio"'));
      expect(
        manifiesto,
        contains('android.intent.category.BROWSABLE'),
        reason: 'sin BROWSABLE, un enlace tocado desde el correo no entra',
      );
    });

    test('el esquema es el mismo nombre que la app', () {
      // No es obligatorio que coincidan, pero sí conviene: un esquema
      // corto como `colibri://` lo puede reclamar cualquier otra app del
      // teléfono, y el sistema no avisa quién se lo queda.
      final proyecto = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      expect(proyecto, contains('PRODUCT_BUNDLE_IDENTIFIER = $esquemaPropio;'));
    });
  });
}
