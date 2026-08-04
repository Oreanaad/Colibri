import 'package:flutter/material.dart';

import '../cuenta.dart';
import '../tema.dart';
import '../widgets.dart';
import 'cargar_libro.dart' show CampoDeTexto;

/// Armar tu perfil, o cambiarlo.
///
/// # Por qué acá no se pide contraseña
///
/// Una contraseña sirve para que alguien que no sos vos no pueda entrar a
/// tu cuenta. Para eso tiene que haber un «entrar», y para eso tiene que
/// haber un servidor. Hoy no lo hay.
///
/// Podríamos pedirla igual y guardarla en el teléfono, y se vería más
/// completo. Sería peor: la única forma segura de guardar una contraseña
/// es no guardarla, sino guardar una huella suya del otro lado. Y como
/// **la gente repite contraseñas**, guardarla acá sería dejar la de su
/// correo tirada en un archivo del teléfono a cambio de nada.
///
/// Así que no se pide, y la pantalla explica por qué. El día que haya
/// servidor se suma el campo y este mismo formulario sigue sirviendo.
class PantallaCrearCuenta extends StatefulWidget {
  /// Cambia los textos y el botón, no la pantalla: es el mismo formulario.
  final bool editando;

  const PantallaCrearCuenta({super.key, this.editando = false});

  @override
  State<PantallaCrearCuenta> createState() => _PantallaCrearCuentaState();
}

class _PantallaCrearCuentaState extends State<PantallaCrearCuenta> {
  late final _usuario = TextEditingController(
    text: cuenta.perfil?.usuario ?? '',
  );
  late final _nombre = TextEditingController(text: cuenta.perfil?.nombre ?? '');
  late final _presentacion = TextEditingController(
    text: cuenta.perfil?.presentacion ?? '',
  );

  String? _problema;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_usuario, _nombre]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_usuario, _nombre, _presentacion]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Lo que está mal con el @usuario, mientras se escribe.
  ///
  /// No se muestra hasta que hay algo escrito: un formulario que te reta
  /// antes de que empieces a completarlo es un formulario antipático.
  String? get _problemaDelUsuario =>
      _usuario.text.trim().isEmpty ? null : Usuario.queEstaMal(_usuario.text);

  bool get _sePuedeGuardar => Usuario.sirve(_usuario.text) && !_guardando;

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _problema = null;
    });

    final r = widget.editando
        ? await cuenta.editar(
            usuario: _usuario.text,
            nombre: _nombre.text,
            presentacion: _presentacion.text,
          )
        : await cuenta.crear(
            usuario: _usuario.text,
            nombre: _nombre.text,
            presentacion: _presentacion.text,
          );

    if (!mounted) return;

    if (!r.bien) {
      setState(() {
        _problema = r.problema;
        _guardando = false;
      });
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final limpio = Usuario.limpiar(_usuario.text);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: Text(
          widget.editando ? 'Editar tu perfil' : 'Armar tu perfil',
          style: const TextStyle(color: Paleta.luz, fontSize: 17),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Columna(
          hijo: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              CampoDeTexto(
                rotulo: 'Tu @usuario',
                controlador: _usuario,
                ejemplo: 'lu.lectora',
                obligatorio: true,
                largoMaximo: Usuario.largoMaximo + 1,
              ),
              const SizedBox(height: 8),
              _AvisoDelUsuario(problema: _problemaDelUsuario, usuario: limpio),

              const SizedBox(height: 20),
              CampoDeTexto(
                rotulo: 'Tu nombre',
                controlador: _nombre,
                ejemplo: 'como querés que te llamen',
                capitalizacion: TextCapitalization.words,
                largoMaximo: 40,
              ),
              const SizedBox(height: 18),
              CampoDeTexto(
                rotulo: 'Presentación',
                controlador: _presentacion,
                ejemplo: 'terror latinoamericano y poesía a las 3 a.m.',
                capitalizacion: TextCapitalization.sentences,
                largoMaximo: 140,
              ),

              if (_problema != null) ...[
                const SizedBox(height: 18),
                _Cartel(_problema!, esError: true),
              ],

              const SizedBox(height: 26),
              BotonLleno(
                _guardando
                    ? 'Guardando…'
                    : (widget.editando ? 'Guardar' : 'Listo'),
                alTocar: _sePuedeGuardar ? _guardar : null,
              ),

              if (!widget.editando) ...[
                const SizedBox(height: 28),
                const _PorQueNoHayContrasena(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo que pasa con el @usuario mientras se escribe.
class _AvisoDelUsuario extends StatelessWidget {
  final String? problema;
  final String usuario;

  const _AvisoDelUsuario({required this.problema, required this.usuario});

  @override
  Widget build(BuildContext context) {
    if (problema != null) return _Cartel(problema!, esError: true);

    if (usuario.isEmpty) {
      return Text(
        'Es la dirección de tu estante: por acá te van a encontrar. '
        'Minúsculas, números, puntos y guiones bajos.',
        style: Tipo.meta,
      );
    }

    return Text(
      'Vas a ser @$usuario.',
      style: Tipo.meta.copyWith(color: Paleta.lila),
    );
  }
}

/// La explicación de lo que falta, sin esconderla.
class _PorQueNoHayContrasena extends StatelessWidget {
  const _PorQueNoHayContrasena();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Paleta.nocheAlta,
        border: Border.all(color: Paleta.linea),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Rotulo('¿Y la contraseña?'),
          const SizedBox(height: 8),
          Text(
            'Todavía no hace falta, porque todavía no hay dónde entrar: tu '
            'perfil y tus libros están en este teléfono y en ningún otro '
            'lado.\n\n'
            'Cuando Colibrí tenga servidor vas a poder ponerle una '
            'contraseña a esto y llevártelo a cualquier teléfono. Mientras '
            'tanto no te la pedimos, porque una contraseña guardada acá no '
            'protegería nada y podría poner en riesgo la de tu correo.',
            style: Tipo.meta,
          ),
          const SizedBox(height: 12),
          BotonContorno(
            'Ya tengo cuenta',
            alTocar: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PantallaEntrar())),
          ),
        ],
      ),
    );
  }
}

/// Entrar a una cuenta que ya existe.
///
/// La pantalla está escrita y anda: le pide a [ServidorDeCuentas] que
/// entre, y muestra lo que conteste. Lo que todavía no existe es el
/// servidor, así que hoy contesta siempre lo mismo y lo dice con todas
/// las letras en vez de fallar callada.
///
/// Existe igual, y no es tiempo perdido: es la que dice qué falta y por
/// qué, y el día que haya servidor no hay que tocarla.
class PantallaEntrar extends StatefulWidget {
  const PantallaEntrar({super.key});

  @override
  State<PantallaEntrar> createState() => _PantallaEntrarState();
}

class _PantallaEntrarState extends State<PantallaEntrar> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  String? _problema;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final r = await cuenta.entrar(correo: _correo.text, clave: _clave.text);
    if (mounted) setState(() => _problema = r.problema);
  }

  @override
  Widget build(BuildContext context) {
    final hay = cuenta.servidor.disponible;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Paleta.lila,
        elevation: 0,
        title: const Text(
          'Entrar',
          style: TextStyle(color: Paleta.luz, fontSize: 17),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Columna(
          hijo: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              if (!hay) ...[
                const _Cartel(
                  'Todavía no hay cuentas.\n\n'
                  'Las cuentas viven en un servidor, y Colibrí todavía no '
                  'tiene uno. Es lo próximo que se construye: con eso, tu '
                  'biblioteca va a poder mudarse de teléfono y tu @usuario '
                  'va a ser tuyo y de nadie más.',
                  esError: true,
                ),
                const SizedBox(height: 24),
              ],

              CampoDeTexto(
                rotulo: 'Tu correo',
                controlador: _correo,
                ejemplo: 'lucia@correo.com',
              ),
              const SizedBox(height: 18),
              CampoDeTexto(
                rotulo: 'Tu contraseña',
                controlador: _clave,
                ejemplo: '',
                oculto: true,
              ),

              if (_problema != null) ...[
                const SizedBox(height: 18),
                _Cartel(_problema!, esError: true),
              ],

              const SizedBox(height: 26),
              BotonLleno('Entrar', alTocar: hay ? _entrar : null),
              const SizedBox(height: 14),
              Text(
                'Mientras tanto, tu perfil vive en este teléfono y funciona '
                'igual: podés armarlo, cambiarlo y usar toda la app.',
                style: Tipo.meta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cartel extends StatelessWidget {
  final String texto;
  final bool esError;
  const _Cartel(this.texto, {this.esError = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: esError ? Paleta.oroTenue : Paleta.nocheAlta,
        border: Border.all(color: esError ? Paleta.oroBorde : Paleta.linea),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: Tipo.meta.copyWith(color: esError ? Paleta.oroTexto : null),
      ),
    );
  }
}
