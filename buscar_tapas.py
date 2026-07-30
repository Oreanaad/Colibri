"""
Busca tapas de libros por titulo y autor, sin navegador y sin scraping.

Consulta dos fuentes publicas, se queda con las candidatas de mayor resolucion
y las descarga. Es el reemplazo de la extension de Chrome: lo mismo que hace
ella, pero con APIs, que es lo unico que puede correr adentro de una app.

    pip install requests
    pip install pillow      # opcional, solo para medir el tamano real

    python buscar_tapas.py "las ninas del naranjel" "cabezon camara"
"""

import os
import re
import sys
import json
import time
import requests

CARPETA = "tapas"
TIMEOUT = 12
UA = {"User-Agent": "Colibri/0.1 (app de lectura; contacto@ejemplo.com)"}

try:
    from PIL import Image
    from io import BytesIO
    HAY_PILLOW = True
except ImportError:
    HAY_PILLOW = False


def _limpiar(texto):
    """Deja un nombre de archivo sano."""
    texto = re.sub(r"[^\w\s-]", "", texto, flags=re.UNICODE).strip().lower()
    return re.sub(r"[\s]+", "_", texto)[:60]


def open_library(titulo, autor=None, isbn=None):
    """
    Open Library. Abierta, gratis, sin clave. Floja en ediciones
    latinoamericanas, pero es la primera que hay que probar.

    El ?default=false es importante: sin eso devuelve un pixel gris
    en vez de un 404 cuando no tiene la tapa, y terminas guardando basura.
    """
    candidatas = []

    if isbn:
        candidatas.append({
            "fuente": "openlibrary (isbn)",
            "url": f"https://covers.openlibrary.org/b/isbn/{isbn}-L.jpg?default=false",
            "edicion": f"ISBN {isbn}",
        })

    consulta = {"title": titulo, "limit": 5}
    if autor:
        consulta["author"] = autor

    try:
        r = requests.get("https://openlibrary.org/search.json",
                         params=consulta, headers=UA, timeout=TIMEOUT)
        r.raise_for_status()
        for doc in r.json().get("docs", []):
            cover_id = doc.get("cover_i")
            if not cover_id:
                continue
            candidatas.append({
                "fuente": "openlibrary",
                "url": f"https://covers.openlibrary.org/b/id/{cover_id}-L.jpg?default=false",
                "edicion": " · ".join(filter(None, [
                    doc.get("title"),
                    (doc.get("publisher") or [None])[0],
                    str(doc.get("first_publish_year") or ""),
                ])),
            })
    except Exception as e:
        print(f"  open library no respondio: {e}")

    return candidatas


def google_books(titulo, autor=None, isbn=None):
    """
    Google Books. Cubre mucho mas, sobre todo en castellano.
    Ojo: tiene condiciones de uso propias, hay que leerlas antes de
    publicar la app. Para probar y para sembrar el catalogo va bien.

    imageLinks trae varios tamanos; agarramos el mas grande que exista.
    """
    candidatas = []

    if isbn:
        q = f"isbn:{isbn}"
    else:
        q = f'intitle:"{titulo}"'
        if autor:
            q += f' inauthor:"{autor}"'

    try:
        r = requests.get("https://www.googleapis.com/books/v1/volumes",
                         params={"q": q, "maxResults": 5, "printType": "books"},
                         headers=UA, timeout=TIMEOUT)
        r.raise_for_status()
        for item in r.json().get("items", []):
            info = item.get("volumeInfo", {})
            links = info.get("imageLinks", {})
            if not links:
                continue

            # de mayor a menor
            for clave in ("extraLarge", "large", "medium", "small", "thumbnail"):
                if clave in links:
                    url = links[clave].replace("http://", "https://")
                    url = url.replace("&edge=curl", "").replace("zoom=1", "zoom=0")
                    candidatas.append({
                        "fuente": f"google books ({clave})",
                        "url": url,
                        "edicion": " · ".join(filter(None, [
                            info.get("title"),
                            info.get("publisher"),
                            (info.get("publishedDate") or "")[:4],
                        ])),
                    })
                    break
    except Exception as e:
        print(f"  google books no respondio: {e}")

    return candidatas


def medir(contenido):
    """Devuelve (ancho, alto) si esta Pillow; si no, aproxima por peso."""
    if HAY_PILLOW:
        try:
            img = Image.open(BytesIO(contenido))
            return img.size
        except Exception:
            return None
    return None


def buscar_tapas(titulo, autor=None, isbn=None, descargar=True):
    print(f"\nBuscando: {titulo}" + (f" — {autor}" if autor else ""))

    candidatas = open_library(titulo, autor, isbn) + google_books(titulo, autor, isbn)

    vistas = set()
    resultados = []

    for c in candidatas:
        if c["url"] in vistas:
            continue
        vistas.add(c["url"])

        try:
            r = requests.get(c["url"], headers=UA, timeout=TIMEOUT)
            if r.status_code != 200 or len(r.content) < 3000:
                # 3 KB o menos casi siempre es un placeholder, no una tapa
                continue
            c["peso"] = len(r.content)
            c["medidas"] = medir(r.content)
            c["contenido"] = r.content
            resultados.append(c)
        except Exception:
            continue

        time.sleep(0.3)  # no castigar a las APIs

    # la de mayor resolucion primero; si no hay Pillow, la mas pesada
    def puntaje(c):
        if c.get("medidas"):
            return c["medidas"][0] * c["medidas"][1]
        return c["peso"]

    resultados.sort(key=puntaje, reverse=True)

    if not resultados:
        print("  sin tapas. Toca sacarle una foto o generar una tipografica.")
        return []

    if descargar:
        os.makedirs(CARPETA, exist_ok=True)

    print(f"  {len(resultados)} candidatas\n")
    for i, c in enumerate(resultados):
        medida = f"{c['medidas'][0]}x{c['medidas'][1]}" if c.get("medidas") else f"{c['peso'] // 1024} KB"
        print(f"  [{i}] {medida:>12}  {c['fuente']}")
        print(f"       {c['edicion']}")

        if descargar:
            nombre = f"{_limpiar(titulo)}_{i}.jpg"
            with open(os.path.join(CARPETA, nombre), "wb") as f:
                f.write(c["contenido"])

    if descargar:
        print(f"\n  guardadas en ./{CARPETA}/")

    for c in resultados:
        c.pop("contenido", None)
    return resultados


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(0)

    titulo = sys.argv[1]
    autor = sys.argv[2] if len(sys.argv) > 2 else None
    buscar_tapas(titulo, autor)
