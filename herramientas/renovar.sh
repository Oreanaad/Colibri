#!/usr/bin/env bash
#
# Renueva la firma de la app del iPhone si le queda poco.
#
#     ./herramientas/renovar.sh
#
# Pensado para correrse solo, todos los días, desde launchd. Ver
# `herramientas/instalar_renovacion.sh`.
#
# # Por qué hace falta que corra solo
#
# Con Apple ID gratis la firma dura siete días. A los siete la app no abre:
# se toca el ícono y vuelve al escritorio, sin decir nada. No hay aviso
# previo ni forma de enterarse desde el teléfono.
#
# Acordarse cada siete días de correr un comando es exactamente la clase de
# cosa que no se sostiene. Y el día que se olvida, la app está muerta hasta
# que alguien se acuerde.
#
# # Qué hace y qué no
#
# - Si le quedan más de dos días, **no hace nada** y se va callado. Correr
#   una compilación diaria para nada gastaría batería y el cupo de la cuenta
#   gratis, que admite diez identificadores de app por semana.
# - Si le quedan dos o menos, compila e instala. Eso pide el teléfono
#   encendido, desbloqueado y en la misma wifi.
# - Si algo falla, **avisa**. Fallar en silencio sería lo peor de los dos
#   mundos: la app se muere igual y encima nadie se enteró de que había un
#   plan para evitarlo.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRO="$RAIZ/servidor/.renovacion.log"

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$PATH:/Users/oreanaad/flutter/bin"

anotar() {
  echo "$(date '+%Y-%m-%d %H:%M')  $1" >> "$REGISTRO"
}

# Un aviso del sistema, de los que aparecen arriba a la derecha.
#
# `|| true` porque si la Mac está en modo de concentración esto falla, y un
# aviso que no se pudo mostrar no es motivo para abortar la renovación.
avisar() {
  osascript -e "display notification \"$2\" with title \"Colibrí\" subtitle \"$1\"" \
    >/dev/null 2>&1 || true
}

PERFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
QUEDAN=99

if [ -d "$PERFILES" ]; then
  for perfil in "$PERFILES"/*.mobileprovision; do
    [ -f "$perfil" ] || continue
    vence=$(security cms -D -i "$perfil" 2>/dev/null \
      | plutil -extract ExpirationDate raw -o - - 2>/dev/null) || continue
    d=$(python3 -c "
import datetime as dt
try:
    v = dt.datetime.fromisoformat('$vence'.replace('Z', '+00:00'))
    print((v - dt.datetime.now(dt.timezone.utc)).days)
except Exception:
    print(99)
")
    [ "$d" -lt "$QUEDAN" ] && QUEDAN=$d
  done
fi

# Sin app instalada tampoco hay nada que renovar.
if [ ! -f "$RAIZ/colibri/build/ios/iphoneos/Runner.app/embedded.mobileprovision" ] \
   && [ "$QUEDAN" -eq 99 ]; then
  anotar "no hay app compilada todavía: nada que renovar"
  exit 0
fi

if [ "$QUEDAN" -gt 2 ]; then
  anotar "quedan $QUEDAN días: no hace falta"
  exit 0
fi

anotar "quedan $QUEDAN días: renovando"

# ¿Está el teléfono? Si no, se avisa y se vuelve a intentar mañana. Con dos
# días de margen hay dos intentos más antes de que se muera.
TELEFONO=$(flutter devices --machine 2>/dev/null \
  | python3 -c "
import json, sys
try:
    equipos = json.load(sys.stdin)
except Exception:
    equipos = []
for e in equipos:
    if e.get('targetPlatform', '').startswith('ios') and not e.get('emulator'):
        print(e['id']); break
" 2>/dev/null)

if [ -z "$TELEFONO" ]; then
  anotar "no encontré el iPhone: reintento mañana"
  avisar "Faltan $QUEDAN días de firma" \
    "No encuentro el iPhone. Dejalo desbloqueado y en esta wifi, o corré ./herramientas/iphone.sh"
  exit 1
fi

if "$RAIZ/herramientas/iphone.sh" >>"$REGISTRO" 2>&1; then
  nueva=$("$RAIZ/herramientas/dias.sh" 2>/dev/null | head -1)
  anotar "renovada: $nueva"
  avisar "Firma renovada" "$nueva"
else
  anotar "FALLÓ la renovación"
  avisar "No pude renovar la firma" \
    "Quedan $QUEDAN días. Corré ./herramientas/iphone.sh a mano."
  exit 1
fi
