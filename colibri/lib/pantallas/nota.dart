import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// Tus notas de un libro: lo que anotás para vos.
///
/// # Por qué no es «la reseña, pero privada»
///
/// Porque son dos cosas que se escriben distinto. Una reseña se escribe
/// para alguien: se cuida el tono, se avisa de los spoilers, se piensa si
/// conviene contar el final. Una nota se escribe para una misma —«la
/// escena del tren me hizo acordar a mi abuela», «releer el capítulo 12»,
/// «¿por qué nadie habla de la hermana?»— y nada de eso se escribe igual
/// si existe la posibilidad de que se publique.
///
/// Por eso son dos lugares y no un interruptor. Un interruptor te obliga a
/// acordarte de mirarlo cada vez, y el día que te olvides, lo que escribiste
/// para vos queda del lado de afuera.
///
/// # Cómo se ve que es privado
///
/// Sin oro y sin lila. En Colibrí el oro es el encuentro con otra persona
/// y el lila es lo que se puede tocar y compartir; las notas van en gris,
/// con el borde punteado, que es como se ve un papel doblado adentro del
/// libro. Y lo dice con palabras arriba, porque el color solo no alcanza
/// para prometer algo así.
///
/// # Y del lado del servidor
///
/// Están en su propia tabla, `notas`, y esa decisión está explicada en
/// `servidor/esquema.sql`: **Postgres protege filas, no columnas.** Si
/// fueran una columna de `lecturas`, el permiso que deja a otra persona
/// ver tu estante dejaría ver también tus notas.
class PantallaNota extends StatefulWidget {
  final Libro libro;
  const PantallaNota(this.libro, {super.key});

  @override
  State<PantallaNota> createState() => _PantallaNotaState();
}

class _PantallaNotaState extends State<PantallaNota> {
  late final TextEditingController _texto = TextEditingController(
    text: widget.libro.nota ?? '',
  );

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final limpio = _texto.text.trim();
    widget.libro.nota = limpio.isEmpty ? null : limpio;

    // El mensajero y el navegador se guardan antes de cerrar: después del
    // pop este contexto ya no existe.
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    await biblioteca.actualizar([widget.libro]);
    if (!mounted) return;

    navegador.pop();
    avisar(
      mensajero,
      limpio.isEmpty ? 'Nota borrada' : 'Tu nota quedó guardada, solo para vos',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Paleta.bruma,
        elevation: 0,
        title: const Text(
          'Tus notas',
          style: TextStyle(color: Paleta.luz, fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: _guardar,
            style: TextButton.styleFrom(foregroundColor: Paleta.bruma),
            child: const Text(
              'Guardar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Columna(
          hijo: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.libro.titulo, style: Tipo.subtitulo),
                Text(widget.libro.autor, style: Tipo.meta),
                const SizedBox(height: 12),

                // Dicho con palabras y no solo con el color. Prometer
                // privacidad con un tono de gris es pedirle a alguien que
                // adivine una promesa.
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: Paleta.bruma,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Esto no se comparte nunca. No sale en tu estante ni '
                        'lo ve nadie que entre a tu perfil.',
                        style: Tipo.meta.copyWith(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: TextField(
                    controller: _texto,
                    autofocus: true,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: Paleta.bruma,
                    style: const TextStyle(
                      color: Paleta.luz,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Lo que quieras acordarte. Una escena, una duda, '
                          'a quién se lo vas a prestar.',
                      hintStyle: Tipo.meta.copyWith(fontSize: 15),
                      filled: true,
                      fillColor: Paleta.nocheAlta,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Paleta.linea),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Paleta.linea),
                      ),
                      // Gris y no lila al enfocarse: el lila en esta app es
                      // lo que se toca y se comparte.
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Paleta.bruma),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                BotonContorno('Guardar nota', alTocar: _guardar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La nota ya escrita, como se ve dentro de la ficha.
///
/// # Por qué no arranca tapada como la reseña con spoilers
///
/// Porque la reseña se tapa para proteger a **quien la lee** de un final
/// que no quería saber. Una nota la lee la misma persona que la escribió:
/// no hay nadie a quien proteger, y tapar lo tuyo de vos mismo es un
/// candado sin llave.
class NotaPropia extends StatelessWidget {
  final Libro libro;
  final VoidCallback alTocar;

  const NotaPropia(this.libro, {super.key, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    if (!libro.tieneNota) {
      return BotonContorno('Anotar algo para mí', alTocar: alTocar);
    }

    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Paleta.nocheAlta,
          // Punteado y no lleno: se ve como un papel doblado adentro del
          // libro y no como una tarjeta publicada.
          border: Border.all(color: Paleta.linea),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 12,
                  color: Paleta.bruma,
                ),
                const SizedBox(width: 5),
                Text(
                  'SOLO VOS VES ESTO',
                  style: Tipo.rotulo.copyWith(fontSize: 9.5),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(libro.nota!, style: Tipo.lectura),
            const SizedBox(height: 8),
            Text('Tocá para editarla', style: Tipo.meta.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
