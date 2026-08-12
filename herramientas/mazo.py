#!/usr/bin/env python3
"""Resuelve el mazo de Descubrir y lo escribe como código Dart.

    python3 herramientas/mazo.py

# Por qué se hornea en vez de pedirse

El carrusel de Descubrir mostraba cinco libros de un mazo curado de
treinta títulos. Para cada uno hacía una búsqueda a Open Library, y
aunque las cinco salían en paralelo, la más lenta manda: medido, entre 2
y 10 segundos antes de ver la primera tapa. Cada «mostrame otros cinco»
eran cinco búsquedas más.

Y esas búsquedas devuelven siempre lo mismo, porque los treinta títulos
son fijos. Se estaba preguntando en cada teléfono, cada vez, algo cuya
respuesta ya se sabía.

Este script pregunta una sola vez, acá, y escribe el resultado como una
constante de Dart. El carrusel pasa a ser instantáneo y sin red: lo único
que queda por bajar son las imágenes de las tapas.

# Qué hacer cuando se agregue un título al mazo

Agregarlo a MAZO, acá abajo, y volver a correr esto. Si algún día un
libro no se encuentra, se escribe igual con lo que se sabe —título y
autoría— y en la app sale con la tapa dibujada, que es lo que ya hacía.
"""
import json
import pathlib
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

# Los mismos treinta de destacados.dart: narrativa latinoamericana —los
# que se midió que el catálogo encuentra bien por título— más las sagas
# que ya cubren las insignias.
MAZO = [
    ('Cometierra', 'Dolores Reyes'),
    ('Las malas', 'Camila Sosa Villada'),
    ('Cien años de soledad', 'Gabriel García Márquez'),
    ('Pedro Páramo', 'Juan Rulfo'),
    ('Nuestra parte de noche', 'Mariana Enriquez'),
    ('Chicas muertas', 'Selva Almada'),
    ('La uruguaya', 'Pedro Mairal'),
    ('Catedrales', 'Claudia Piñeiro'),
    ('Rayuela', 'Julio Cortázar'),
    ('Distancia de rescate', 'Samanta Schweblin'),
    ('Los detectives salvajes', 'Roberto Bolaño'),
    ('La casa de los espíritus', 'Isabel Allende'),
    ('Como agua para chocolate', 'Laura Esquivel'),
    ('Ficciones', 'Jorge Luis Borges'),
    ('Kentukis', 'Samanta Schweblin'),
    ('La virgen cabeza', 'Gabriela Cabezón Cámara'),
    ('Mugre rosa', 'Fernanda Trías'),
    ('Temporada de huracanes', 'Fernanda Melchor'),
    ('The Hunger Games', 'Suzanne Collins'),
    ('Divergent', 'Veronica Roth'),
    ('Percy Jackson and the Lightning Thief', 'Rick Riordan'),
    ('City of Bones', 'Cassandra Clare'),
    ('A Court of Thorns and Roses', 'Sarah J. Maas'),
    ('Fourth Wing', 'Rebecca Yarros'),
    ('It Ends With Us', 'Colleen Hoover'),
    ('The Seven Husbands of Evelyn Hugo', 'Taylor Jenkins Reid'),
    ('A Game of Thrones', 'George R. R. Martin'),
    ('The Fellowship of the Ring', 'J. R. R. Tolkien'),
    ('Pride and Prejudice', 'Jane Austen'),
]

CABECERAS = {"User-Agent": "Colibri/1.0 (herramienta de build)"}


def buscar(par):
    """El primer resultado de Open Library para un título y autoría."""
    titulo, autor = par
    q = urllib.parse.quote(f"{titulo} {autor}")
    url = (
        f"https://openlibrary.org/search.json?q={q}&limit=3"
        "&fields=key,title,author_name,cover_i,first_publish_year,"
        "publisher,number_of_pages_median"
    )
    for intento in range(3):
        try:
            with urllib.request.urlopen(
                urllib.request.Request(url, headers=CABECERAS), timeout=30
            ) as r:
                docs = json.load(r).get("docs", [])
            if not docs:
                return titulo, autor, None
            return titulo, autor, docs[0]
        except Exception:
            # Open Library devuelve 503 de vez en cuando; se reintenta con
            # una pausa en vez de dejar el libro sin tapa para siempre.
            time.sleep(2 + intento * 3)
    return titulo, autor, None


def dart(texto: str) -> str:
    """Un string de Dart con comillas simples, escapando lo que hace falta."""
    return "'" + texto.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def num(v) -> str:
    """Un número de Dart, o `null`. Sin esto se escribía el `None` de
    Python, que Dart no entiende."""
    return "null" if v is None else str(v)


if __name__ == "__main__":
    print(f"Resolviendo {len(MAZO)} títulos…")
    with ThreadPoolExecutor(max_workers=4) as ex:
        resueltos = list(ex.map(buscar, MAZO))

    encontrados = sum(1 for _, _, d in resueltos if d)
    conTapa = sum(1 for _, _, d in resueltos if d and d.get("cover_i"))
    print(f"  encontrados: {encontrados}/{len(MAZO)}   con tapa: {conTapa}")

    if conTapa < len(MAZO) * 0.7:
        print("  Muy pocos con tapa. Open Library debe estar caída; probá más tarde.")
        print("  No se escribió nada: mejor dejar el mazo viejo que romperlo.")
        sys.exit(1)

    lineas = []
    for titulo, autor, d in resueltos:
        if not d:
            lineas.append(
                f"  ({dart(titulo)}, {dart(autor)}, null, null, null, null),"
            )
            continue
        tapa = d.get("cover_i")
        anio = d.get("first_publish_year")
        paginas = d.get("number_of_pages_median")
        # Nuestro título y no el del catálogo: Open Library devuelve
        # «COMETIERRA» en mayúsculas, y en el carrusel eso grita. El
        # catálogo aporta la tapa y los datos; el nombre lo escribimos
        # nosotras, que es parte de lo que significa curar el mazo.
        lineas.append(
            f"  ({dart(titulo)}, {dart(autor)}, "
            f"{dart(d.get('key') or titulo)}, {num(tapa)}, {num(anio)}, "
            f"{num(paginas)}),"
        )

    salida = pathlib.Path(__file__).parent.parent / "colibri" / "lib" / "mazo.dart"
    salida.write_text(
        '''// GENERADO POR herramientas/mazo.py — no editar a mano.
//
// Para cambiarlo: editá MAZO en ese script y correlo de nuevo.

/// El mazo de Descubrir, ya resuelto contra Open Library.
///
/// # Por qué está horneado y no se pide
///
/// El carrusel hacía una búsqueda por título para cada libro que mostraba.
/// Aunque salían en paralelo, la más lenta manda: medido contra Open
/// Library, entre 2 y 10 segundos antes de ver la primera tapa, y otros
/// cinco pedidos en cada «mostrame otros cinco».
///
/// Y la respuesta siempre era la misma, porque los títulos son fijos. Se
/// preguntaba en cada teléfono, cada vez, algo que ya se sabía. Ahora se
/// pregunta una sola vez, al compilar.
///
/// Lo único que queda por bajar son las imágenes de las tapas, que van al
/// caché de 30 días.
///
/// # Qué es cada campo
///
/// El título como lo escribe el catálogo, la autoría como la escribimos
/// nosotras, la clave de la obra —`/works/OL…`, la que necesita elegir
/// edición—, el número de tapa, el año y las páginas. Cualquiera puede
/// ser null: un libro que el catálogo no encontró sale con la tapa
/// dibujada, igual que antes.
const mazoDeDescubrir =
    <(String, String, String?, int?, int?, int?)>[
'''
        + "\n".join(lineas)
        + "\n];\n"
    )
    print(f"escrito: {salida.relative_to(salida.parent.parent.parent)}")
