#!/usr/bin/env bash
#
# Publica la app en GitHub Pages.
#
#     ./herramientas/publicar.sh
#
# Compila con las claves de colibri/claves.json y sube el resultado a la
# rama gh-pages. La rama se reescribe entera cada vez: no guarda
# historia, porque es un resultado y no un fuente.
#
# Para bajarla:  gh api -X DELETE repos/Oreanaad/Colibri/pages
set -euo pipefail

export PATH="$PATH:/Users/oreanaad/flutter/bin"

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$RAIZ/colibri"
CLAVES="$APP/claves.json"

[ -f "$CLAVES" ] || { echo "Falta colibri/claves.json"; exit 1; }

echo "Compilando…"
cd "$APP"
# --base-href porque Pages sirve en /Colibri/ y no en la raíz. Sin esto
# la app busca sus archivos donde no están y la pantalla queda en blanco.
flutter build web --release \
  --base-href /Colibri/ \
  --dart-define-from-file=claves.json >/dev/null

echo "Subiendo…"
TMP="$(mktemp -d)"
cp -R "$APP/build/web/." "$TMP/"

# .nojekyll: sin esto GitHub ignora las carpetas que empiezan con guión
# bajo, y Flutter genera varias.
touch "$TMP/.nojekyll"

# El ayudante de credenciales del repo, copiado a esta carpeta temporal.
#
# Sin esto el push falla con un 403: la carpeta temporal es un repo
# nuevo, no hereda nada, y git cae en el llavero del sistema, que
# apunta a la otra cuenta de GitHub que hay en esta máquina.
AYUDANTE="$(cd "$RAIZ" && git config --local --get credential.helper)"
ORIGEN="$(cd "$RAIZ" && git remote get-url origin)"

cd "$TMP"
git init -q
# Primero se vacía la cadena y después se pone el propio. Sin el vaciado,
# el llavero del sistema —que es global— queda primero en la lista, y git
# usa el primero que le conteste: el de la otra cuenta de GitHub que hay
# en esta máquina.
git config credential.helper ""
git config --add credential.helper "$AYUDANTE"
git checkout -qb gh-pages
git add -A
git -c user.email=colibri@local -c user.name=Colibri \
  commit -qm "Publicado $(date +%Y-%m-%d\ %H:%M)"
git push -qf "$ORIGEN" gh-pages

cd "$RAIZ"
rm -rf "$TMP"

echo
echo "Listo:  https://oreanaad.github.io/Colibri/"
