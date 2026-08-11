#!/usr/bin/env bash
#
# Cuántos días le quedan a la firma de la app del iPhone.
#
#     ./herramientas/dias.sh
#
# # Por qué existe
#
# Con un Apple ID gratis la firma dura una semana, y cuando se vence la
# app no abre: toca el ícono y vuelve a la pantalla de inicio, sin decir
# nada. No hay ningún aviso antes. Sabiendo cuántos días quedan, reinstalar
# es algo que se hace un martes; sin saberlo, es algo que se descubre
# cuando querés anotar un libro y no podés.
#
# # De dónde sale la fecha
#
# No se asume que son siete días desde la instalación: se lee la fecha que
# tiene escrita adentro el perfil de aprovisionamiento —el archivo con el
# que Apple autoriza esa app en ese teléfono—. Es la fecha que de verdad
# va a hacer que la app deje de abrir.
#
# `security cms -D` lo desempaqueta, porque viene firmado y no es un plist
# a secas.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERFIL="$RAIZ/colibri/build/ios/iphoneos/Runner.app/embedded.mobileprovision"

if [ ! -f "$PERFIL" ]; then
  echo "Todavía no hay ninguna app compilada para iPhone."
  echo "  ./herramientas/iphone.sh"
  exit 0
fi

VENCE=$(security cms -D -i "$PERFIL" 2>/dev/null \
  | plutil -extract ExpirationDate raw -o - - 2>/dev/null) || true

if [ -z "${VENCE:-}" ]; then
  echo "No pude leer la fecha del perfil de firma."
  echo "  el archivo está en: $PERFIL"
  exit 1
fi

python3 - "$VENCE" <<'PY'
import datetime as dt
import sys

# La fecha viene en UTC, con Z al final.
vence = dt.datetime.fromisoformat(sys.argv[1].replace("Z", "+00:00"))
faltan = (vence - dt.datetime.now(dt.timezone.utc)).days

cuando = vence.astimezone().strftime("%d/%m a las %H:%M")

if faltan < 0:
    print(f"La firma venció el {cuando}. La app no abre.")
    print("  ./herramientas/iphone.sh   con el cable")
elif faltan == 0:
    print(f"La firma vence hoy, {cuando}.")
    print("  ./herramientas/iphone.sh   con el cable")
elif faltan <= 2:
    print(f"Quedan {faltan} día(s): vence el {cuando}.")
    print("  conviene reinstalar antes de que te agarre desprevenida")
else:
    print(f"Quedan {faltan} días. Vence el {cuando}.")
PY
