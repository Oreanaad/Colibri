#!/usr/bin/env bash
#
# Publica la app en internet, con https.
#
#     ./herramientas/publicar.sh
#
# Va a Netlify y no a GitHub Pages. La primera vez se intentó con Pages
# —está en el mismo repo, no hace falta otra cuenta— pero se quedó
# colgado en "building" media hora y terminó en "errored", con un
# incidente abierto de GitHub: "Pages - Deployment Lag", con Actions y
# Pages en interrupción mayor. Netlify tarda siete segundos.
#
# El sitio ya existe y la sesión ya está iniciada en esta máquina. Si
# alguna vez pide entrar de nuevo:  netlify login
set -euo pipefail

export PATH="$PATH:/Users/oreanaad/flutter/bin"

SITIO=c0414df9-173c-483b-b14c-40689c53854f
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$RAIZ/colibri"

[ -f "$APP/claves.json" ] || { echo "Falta colibri/claves.json"; exit 1; }

echo "Compilando…"
cd "$APP"
# --base-href / porque Netlify sirve en la raíz del dominio. Con GitHub
# Pages había que poner /Colibri/, y si se deja ese valor acá la app
# busca sus archivos en una carpeta que no existe y queda en blanco.
flutter build web --release \
  --base-href / \
  --dart-define-from-file=claves.json >/dev/null

echo "Publicando…"
netlify deploy --prod --dir=build/web --site="$SITIO" 2>&1 \
  | grep -E "Production URL|Deploy complete|Error" || true

echo
echo "Listo:  https://colibri-lectoras.netlify.app"
