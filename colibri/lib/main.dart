import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'modelos.dart';
import 'pantallas/biblioteca.dart';
import 'pantallas/comunidad.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La app es oscura siempre: los íconos de la barra de estado van claros.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark, // iOS
    statusBarIconBrightness: Brightness.light, // Android
    systemNavigationBarColor: Paleta.noche,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await biblioteca.cargar();
  runApp(const AppColibri());
}

class AppColibri extends StatelessWidget {
  const AppColibri({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Colibrí',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
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
  int _indice = 0;

  static const _pantallas = [
    PantallaBiblioteca(),
    PantallaComunidad(),
  ];

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
          onDestinationSelected: (i) => setState(() => _indice = i),
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
