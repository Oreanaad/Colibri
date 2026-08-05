import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'fondo.dart';
import 'cuenta.dart';
import 'nube.dart';
import 'servidor_supabase.dart';
import 'modelos.dart';
import 'pantallas/biblioteca.dart';
import 'pantallas/comunidad.dart';
import 'pantallas/fanfics.dart';
import 'pantallas/ficha.dart';
import 'pantallas/todas_las_frases.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La app es oscura siempre: los íconos de la barra de estado van claros.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark, // iOS
      statusBarIconBrightness: Brightness.light, // Android
      systemNavigationBarColor: Paleta.noche,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Si hay claves, la app habla con Supabase. Si no, funciona igual y
  // todo queda en el teléfono: es la misma app, con otra implementación
  // de la misma frontera.
  await prepararSupabase();
  if (haySupabase) {
    cuenta.servidor = const ServidorSupabase();
    // Biblioteca no se entera de que esto existe: nube se cuelga de sus
    // dos enganches y a partir de acá cada cambio intenta subirse solo.
    nube.conectar(biblioteca);
  }

  await biblioteca.cargar();
  await cuenta.cargar();
  await sesion.cargar();
  runApp(const AppColibri());
}

class AppColibri extends StatelessWidget {
  const AppColibri({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Colibrí',
      debugShowCheckedModeBanner: false,
      // copyWith y no dentro de construirTema porque el tema no puede
      // conocer al fondo: el fondo ya usa la paleta, y se harían un nudo.
      theme: construirTema().copyWith(
        pageTransitionsTheme: transicionesConFondo,
      ),

      // Sin esto, el calendario que elige las fechas aparece en inglés:
      // "Select date", "Cancel", los meses y hasta el orden de los días.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // El librero va acá y no en cada pantalla: envuelve todo lo que la
      // app dibuje, incluidas las que se abren encima.
      builder: (context, hijo) => Fondo(hijo: hijo ?? const SizedBox()),
      home: const Marco(),
    );
  }
}

class Marco extends StatefulWidget {
  const Marco({super.key});

  @override
  State<Marco> createState() => _MarcoState();
}

class _MarcoState extends State<Marco> {
  late int _indice = sesion.seccion.clamp(0, _pantallas.length - 1);

  static const _pantallas = [
    PantallaBiblioteca(),
    PantallaFanfics(),
    PantallaTodasLasFrases(),
    PantallaComunidad(),
  ];

  @override
  void initState() {
    super.initState();
    // Después del primer dibujo, no antes: hasta que la pantalla no
    // existe no hay a dónde apilar la ficha.
    WidgetsBinding.instance.addPostFrameCallback((_) => _volverAlLibro());
  }

  /// Si estabas mirando un libro, lo vuelve a abrir.
  ///
  /// Se busca por clave y no por posición: entre que cerraste y volviste,
  /// la biblioteca pudo cambiar de orden o el libro pudo no estar más.
  void _volverAlLibro() {
    final clave = sesion.libro;
    if (clave == null || !mounted) return;

    final libro = biblioteca.buscarPorClave(clave);
    if (libro == null) {
      sesion.anotar(cerrarLibro: true); // ya no está: limpiamos
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PantallaFicha(libro)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _indice, children: _pantallas),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Paleta.linea)),
        ),
        child: NavigationBar(
          selectedIndex: _indice,
          onDestinationSelected: (i) {
            setState(() => _indice = i);
            sesion.anotar(seccion: i);
          },
          backgroundColor: Paleta.noche,
          indicatorColor: const Color(0x22B9A6E6),
          height: 62,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined, color: Paleta.bruma),
              selectedIcon: Icon(Icons.menu_book_rounded, color: Paleta.lila),
              label: 'Biblioteca',
            ),
            // Sección propia y no una solapa de la biblioteca: los
            // fanfics se cargan distinto —con su enlace, que es lo que
            // impide que el mismo entre mil veces— y si el botón viviera
            // mezclado con el de buscar libros, la mitad de las veces
            // alguien cargaría un fic como si fuera un libro y ahí se
            // pierde la garantía.
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined, color: Paleta.bruma),
              selectedIcon: Icon(
                Icons.auto_stories_rounded,
                color: Paleta.lila,
              ),
              label: 'Fanfics',
            ),
            NavigationDestination(
              icon: Icon(Icons.format_quote_outlined, color: Paleta.bruma),
              selectedIcon: Icon(
                Icons.format_quote_rounded,
                color: Paleta.lila,
              ),
              label: 'Frases',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, color: Paleta.bruma),
              selectedIcon: Icon(Icons.people_rounded, color: Paleta.lila),
              label: 'Comunidad',
            ),
          ],
        ),
      ),
    );
  }
}
