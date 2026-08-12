#!/usr/bin/env bash
#
# Comprueba que las categorías de Descubrir sigan trayendo libros.
#
#     ./servidor/probar_categorias.sh
#
# # Por qué esto no puede ser un test de Dart
#
# `flutter test` corta toda petición HTTP, así que desde ahí no se puede
# saber si `romantasy` sigue existiendo en Open Library. Y estas etiquetas
# **no son nuestras**: las escribe la gente que carga libros al catálogo,
# así que pueden vaciarse o renombrarse sin que nadie nos avise. El día
# que eso pase, en la app la categoría se ve, se toca, y no trae nada.
#
# Las etiquetas se leen del propio destacados.dart, no se copian acá: dos
# listas separadas se desincronizan y esto diría que todo está bien
# mientras la app usa otras.
#
# # Qué se mira de cada una
#
# Cuántas obras devuelve, cuántas con tapa, y **cuántas son de este
# siglo**. Lo último es el criterio que salió de medir: las categorías
# amplias de Open Library devuelven dominio público —«Poesía» contesta
# Robinson Crusoe, «Manga» contesta La letra escarlata— porque ordenan por
# peso del catálogo, y lo más pesado son los libros de hace cien años. Una
# categoría que pasa a devolver puros clásicos está rota para lo que la
# usamos, aunque técnicamente conteste.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$RAIZ/colibri/lib/pantallas/destacados.dart" <<'PY'
import json, re, sys, urllib.error, urllib.request
from concurrent.futures import ThreadPoolExecutor

texto = open(sys.argv[1]).read()
bloque = re.search(r"_categorias = <\(String, String\)>\[(.*?)\n  \];", texto, re.S)
if not bloque:
    print("  no encontré _categorias en destacados.dart")
    sys.exit(1)

categorias = re.findall(r"\('([^']+)',\s*'([^']+)'\)", bloque.group(1))
print(f"Las {len(categorias)} categorías que usa la app:\n")


def probar(par):
    nombre, etiqueta = par
    url = f"https://openlibrary.org/subjects/{etiqueta}.json?limit=10"
    p = urllib.request.Request(url, headers={"User-Agent": "Colibri/1.0"})
    try:
        with urllib.request.urlopen(p, timeout=40) as r:
            d = json.load(r)
    except Exception as ex:
        return nombre, etiqueta, -1, 0, 0, str(ex)[:26]

    obras = d.get("works", [])
    return (
        nombre,
        etiqueta,
        len(obras),
        sum(1 for w in obras if w.get("cover_id")),
        sum(1 for w in obras if (w.get("first_publish_year") or 0) >= 1960),
        obras[0].get("title", "?")[:30] if obras else "—",
    )


with ThreadPoolExecutor(max_workers=4) as ex:
    filas = list(ex.map(probar, categorias))

print(f"{'categoría':20} {'obras':>6} {'tapas':>6} {'>=1960':>7}   primera")
print("-" * 76)

problemas = []
for nombre, etiqueta, n, tapas, modernos, primera in filas:
    # Ocho obras es lo mínimo para llenar una fila que se desliza; siete
    # con tapa porque una tapa dibujada de vez en cuando está bien pero
    # una fila entera dibujada no se ve como un catálogo; y cinco de este
    # siglo y medio, que es el criterio de que no viró a dominio público.
    mal = n < 8 or tapas < 7 or modernos < 5
    print(f"{'X ' if mal else '  '}{nombre:18} {n:6} {tapas:6} {modernos:7}   {primera}")
    if mal:
        problemas.append(f"{nombre} ({etiqueta})")

print()
if problemas:
    print(f"{len(problemas)} categoría(s) para revisar:")
    for p in problemas:
        print(f"  · {p}")
    print()
    print("  Buscá un reemplazo con:")
    print("    curl -s 'https://openlibrary.org/subjects/<etiqueta>.json?limit=10' \\")
    print("      | python3 -m json.tool | grep -E '\"title\"|work_count'")
    print("  y cambialo en _categorias, en destacados.dart.")
    sys.exit(1)

print("Todas traen libros.")
PY
