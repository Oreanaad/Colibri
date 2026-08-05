import 'package:flutter/material.dart';

import '../cuenta.dart';
import '../tema.dart';
import '../widgets.dart';
import 'crear_cuenta.dart';

/// La frontera entre explorar y ser parte.
///
/// # Qué se puede hacer sin cuenta, y qué no
///
/// Se puede explorar: buscar libros, abrir una ficha, leer de qué se
/// trata. Lo que no —agregar, escribir una reseña, ver tu propia
/// biblioteca— pide esto primero.
///
/// # Por qué no bloquea todo desde el arranque
///
/// Nadie decide si le interesa una app leyendo un formulario de alta:
/// decide usándola. Bloquear todo hasta iniciar sesión —y encima Colibrí
/// pide confirmar el correo— dejaría a alguien que recién abrió la app
/// sin ver un solo libro antes de tener que revisar su mail. Explorar
/// primero es lo que hace que valga la pena crear la cuenta después.
///
/// # Cómo se usa
///
/// Se llama siempre, sin preguntar antes si hay sesión: si ya la hay,
/// devuelve `true` al instante y no muestra nada. Eso es lo que permite
/// poner esta línea delante de cada acción que lo necesita sin tener que
/// bifurcar el código en "con cuenta" y "sin cuenta" en cada pantalla.
///
///     Future<void> _agregar() async {
///       if (!await exigirCuenta(context, motivo: 'agregar un libro')) return;
///       ...
///     }
///
/// Devuelve `true` si al cerrarse ya hay perfil —se acaba de crear, ya
/// existía, o se entró a una cuenta—. Quien llama tiene que frenar si
/// devuelve `false`.
Future<bool> exigirCuenta(
  BuildContext context, {
  required String motivo,
}) async {
  if (cuenta.hayPerfil) return true;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Paleta.nocheAlta,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _HojaDeSesion(motivo: motivo),
  );

  return cuenta.hayPerfil;
}

class _HojaDeSesion extends StatelessWidget {
  final String motivo;
  const _HojaDeSesion({required this.motivo});

  Future<void> _ir(BuildContext context, Widget pantalla) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => pantalla));
    // Se cierra al volver, sea que haya funcionado o que se haya vuelto
    // atrás: quien llamó a exigirCuenta ya sabe leer la diferencia
    // mirando si ahora hay perfil.
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Paleta.linea,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Hace falta tu perfil', style: Tipo.subtitulo),
            const SizedBox(height: 8),
            Text(
              'Para $motivo hace falta tu perfil. Podés seguir mirando y '
              'buscando libros sin él.',
              style: Tipo.meta,
            ),
            const SizedBox(height: 22),
            BotonLleno(
              'Crear mi perfil',
              alTocar: () => _ir(context, const PantallaCrearCuenta()),
            ),
            const SizedBox(height: 10),
            BotonContorno(
              'Ya tengo cuenta',
              alTocar: () => _ir(context, const PantallaEntrar()),
            ),
          ],
        ),
      ),
    );
  }
}

/// La pantalla entera, para las secciones que no tienen nada que explorar.
///
/// Fanfics y Frases son cien por ciento tuyas: no hay catálogo que mirar
/// ahí adentro sin que sea tu biblioteca. Por eso no tienen un modo
/// "explorar" como la búsqueda de libros: sin perfil, muestran esto en
/// vez de su contenido.
class NecesitaCuenta extends StatelessWidget {
  final String titulo;
  final String motivo;

  const NecesitaCuenta({super.key, required this.titulo, required this.motivo});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: Paleta.bruma,
                size: 30,
              ),
              const SizedBox(height: 16),
              Text(titulo, style: Tipo.titulo, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(motivo, style: Tipo.meta, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: BotonLleno(
                  'Crear mi perfil',
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PantallaCrearCuenta(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 220,
                child: BotonContorno(
                  'Ya tengo cuenta',
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PantallaEntrar()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
