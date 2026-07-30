import 'package:flutter/material.dart';

import '../modelos.dart';
import '../tema.dart';
import 'compartir.dart';
import 'ficha.dart';

/// Una frase junto al libro del que salió.
///
/// Existe porque las frases viven adentro de cada libro, y para mostrarlas
/// todas juntas hay que saber de dónde vino cada una.
class FraseConLibro {
  final Frase frase;
  final Libro libro;
  const FraseConLibro(this.frase, this.libro);
}

/// Todas las frases de todos los libros, juntas.
///
/// Es la pantalla que la gente va a abrir sin buscar nada: es su propia
/// antología, hecha sin darse cuenta.
class PantallaTodasLasFrases extends StatefulWidget {
  const PantallaTodasLasFrases({super.key});

  @override
  State<PantallaTodasLasFrases> createState() =>
      _PantallaTodasLasFrasesState();
}

class _PantallaTodasLasFrasesState extends State<PantallaTodasLasFrases> {
  final _buscador = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  List<FraseConLibro> get _todas {
    final lista = <FraseConLibro>[];
    for (final libro in biblioteca.todos) {
      for (final frase in libro.frases) {
        lista.add(FraseConLibro(frase, libro));
      }
    }
    // La más reciente primero, sin importar de qué libro venga.
    lista.sort((a, b) => b.frase.guardada.compareTo(a.frase.guardada));
    return lista;
  }

  List<FraseConLibro> _filtrar(List<FraseConLibro> todas) {
    if (_filtro.trim().length < 3) return todas;
    final aguja = _normalizar(_filtro);
    return todas
        .where((f) =>
            _normalizar(f.frase.texto).contains(aguja) ||
            _normalizar(f.libro.titulo).contains(aguja) ||
            _normalizar(f.libro.autor).contains(aguja))
        .toList();
  }

  static String _normalizar(String s) {
    const acentos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    };
    var r = s.toLowerCase();
    acentos.forEach((k, v) => r = r.replaceAll(k, v));
    return r;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: biblioteca,
      builder: (context, _) {
        final todas = _todas;
        final visibles = _filtrar(todas);

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Tus frases', style: Tipo.titulo),
                    if (todas.isNotEmpty)
                      Text(
                        todas.length == 1 ? '1 frase' : '${todas.length} frases',
                        style: Tipo.meta,
                      ),
                  ],
                ),
              ),
              if (todas.length >= 5)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  child: TextField(
                    controller: _buscador,
                    onChanged: (v) => setState(() => _filtro = v),
                    style: const TextStyle(color: Paleta.luz, fontSize: 14),
                    cursorColor: Paleta.lila,
                    decoration: InputDecoration(
                      hintText: 'Buscar en tus frases',
                      hintStyle: Tipo.meta,
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Paleta.bruma, size: 19),
                      isDense: true,
                      filled: true,
                      fillColor: Paleta.nocheAlta,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Paleta.linea),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Paleta.linea),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Paleta.lila),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: todas.isEmpty
                    ? const _SinFrases()
                    : visibles.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(32, 50, 32, 0),
                            child: Text(
                              'Ninguna frase tuya dice eso.',
                              style: Tipo.meta,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(20, 12, 20, 28),
                            itemCount: visibles.length,
                            itemBuilder: (_, i) => _Tarjeta(visibles[i]),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final FraseConLibro f;
  const _Tarjeta(this.f);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        color: Paleta.oroTenue,
        border: Border(left: BorderSide(color: Paleta.oro, width: 3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Un toque va directo a compartir: es lo que la gente quiere
          // hacer con una frase que le gustó.
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PantallaCompartir(f.libro, f.frase),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('“${f.frase.texto}”', style: Tipo.lectura),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PantallaFicha(f.libro),
                          ),
                        ),
                        child: Text(
                          '${f.libro.titulo} · ${f.libro.autor}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tipo.meta.copyWith(
                            fontSize: 11.5,
                            color: Paleta.oro,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.ios_share_rounded,
                        size: 15, color: Paleta.bruma),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SinFrases extends StatelessWidget {
  const _SinFrases();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 70, 36, 0),
      child: Column(
        children: [
          const Icon(Icons.format_quote_rounded,
              size: 40, color: Paleta.linea),
          const SizedBox(height: 18),
          Text(
            'Todavía no subrayaste nada.',
            style: Tipo.cuerpo,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Abrí un libro de tu biblioteca y entrá a «Tus frases». '
            'Con el tiempo esto se convierte en tu propia antología, '
            'armada sin darte cuenta.',
            style: Tipo.meta,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
