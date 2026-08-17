#!/usr/bin/env bash
#
# Deja la renovación de la firma corriendo sola, todos los días.
#
#     ./herramientas/instalar_renovacion.sh          instala
#     ./herramientas/instalar_renovacion.sh --sacar  saca
#
# # Qué instala, exactamente
#
# Un «agente» de macOS: un archivo en ~/Library/LaunchAgents que le dice al
# sistema «corré este script una vez por día». Es el mecanismo propio del
# sistema, el mismo que usan las apps para sus tareas de fondo. No es un
# programa que queda prendido: el sistema lo despierta, corre y termina.
#
# Lo que corre es `herramientas/renovar.sh`, que casi todos los días no hace
# nada —solo mira cuántos días quedan— y solo compila cuando faltan dos o
# menos.
#
# # Se saca con un comando
#
#     ./herramientas/instalar_renovacion.sh --sacar
#
# No deja nada atrás: un archivo que se borra y un registro de texto.
#
# # Lo que NO puede hacer
#
# Renovar sin el teléfono. Instalar en un iPhone pide que esté encendido,
# desbloqueado y en la misma wifi. Si no está, lo anota, **avisa con una
# notificación** y reintenta al día siguiente. Como se dispara con dos días
# de margen, hay tres intentos antes de que la app deje de abrir.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ETIQUETA="ar.colibri.renovar"
PLIST="$HOME/Library/LaunchAgents/$ETIQUETA.plist"

if [ "${1:-}" = "--sacar" ]; then
  launchctl bootout "gui/$(id -u)/$ETIQUETA" 2>/dev/null || true
  rm -f "$PLIST"
  echo "Sacado. La firma vuelve a renovarse solo cuando corras"
  echo "  ./herramientas/iphone.sh"
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$ETIQUETA</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$RAIZ/herramientas/renovar.sh</string>
  </array>

  <!-- Una vez por día, a las 11. No de madrugada a propósito: a esa hora
       el teléfono está durmiendo y lejos de la compu, y renovar necesita
       las dos cosas despiertas y en la misma wifi. -->
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>11</integer>
    <key>Minute</key><integer>0</integer>
  </dict>

  <!-- Si la Mac estaba apagada a esa hora, corre al prenderse. Sin esto,
       un fin de semana con la compu cerrada se saltea los tres intentos. -->
  <key>RunAtLoad</key>
  <true/>

  <key>StandardErrorPath</key>
  <string>$RAIZ/servidor/.renovacion.err</string>
</dict>
</plist>
PLIST

# bootout antes de bootstrap: si ya estaba cargado, cargarlo de nuevo falla.
launchctl bootout "gui/$(id -u)/$ETIQUETA" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Listo. Se va a fijar todos los días a las 11."
echo
echo "  qué instaló:   $PLIST"
echo "  qué corre:     herramientas/renovar.sh"
echo "  qué anota:     servidor/.renovacion.log"
echo "  cómo sacarlo:  ./herramientas/instalar_renovacion.sh --sacar"
echo
launchctl print "gui/$(id -u)/$ETIQUETA" 2>/dev/null \
  | grep -E "state = |program = " | sed 's/^/  /' || true
