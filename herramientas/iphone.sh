#!/usr/bin/env bash
#
# Instala Colibrí en un iPhone conectado por cable.
#
#     ./herramientas/iphone.sh
#
# # Por qué nativo y no la web
#
# La versión web en el iPhone tiene un techo que no se puede levantar
# escribiendo mejor código: el navegador tiene que bajar y arrancar
# 1 MB de JavaScript, 2,6 MB de CanvasKit —el motor que dibuja— y 1 MB
# más de WebAssembly solo para el escáner. Recién después empieza la app.
#
# Nativo no baja nada de eso. El código va compilado a instrucciones del
# procesador en vez de interpretado, dibuja con Metal directo contra la
# GPU, y el escáner es el de Apple, el mismo que usa la app de Cámara.
#
# # Lo que hace falta una sola vez
#
# 1. Xcode, del App Store. Son unos 15 GB y es lo único que no se puede
#    automatizar: lo pide Apple con su cuenta.
# 2. Abrir Xcode una vez y aceptar la licencia.
# 3. En Xcode: Settings -> Accounts -> agregar el Apple ID (el común, no
#    hace falta pagar nada).
# 4. Abrir ios/Runner.xcworkspace y en Signing & Capabilities elegir el
#    equipo "Personal Team". Sin eso no hay firma y el iPhone no instala.
# 5. En el iPhone, la primera vez: Ajustes -> General -> VPN y
#    administración de dispositivos -> confiar en el desarrollador.
#
# # Los 7 días
#
# Con un Apple ID gratis, la firma dura una semana. A los 7 días la app
# no abre más y hay que volver a correr esto con el cable. Los libros no
# se pierden: quedan en el teléfono, y si hay cuenta, en la nube.
#
# Con el programa de desarrollador de Apple —99 dólares por año— la
# firma dura un año y se puede repartir por TestFlight, que es como se
# le daría a alguien más para probar sin cable.
set -euo pipefail

export PATH="$PATH:/Users/oreanaad/flutter/bin"
export PATH="/opt/homebrew/bin:$PATH" # CocoaPods, instalado con brew

cd "$(dirname "${BASH_SOURCE[0]}")/../colibri"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Falta Xcode."
  echo
  echo "  1. App Store -> buscar Xcode -> Obtener  (unos 15 GB)"
  echo "  2. Abrirlo una vez y aceptar la licencia"
  echo "  3. sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  echo "  4. sudo xcodebuild -runFirstLaunch"
  echo
  echo "Mientras baja, la app anda igual en Android:"
  echo "  ./herramientas/apk.sh"
  exit 1
fi

[ -f claves.json ] || { echo "Falta colibri/claves.json"; exit 1; }

# Las dependencias nativas de los plugins. Flutter lo corre solo al
# compilar, pero la primera vez baja el índice entero de CocoaPods y
# tarda varios minutos: mejor que se vea qué está pasando.
if [ ! -d ios/Pods ]; then
  echo "Preparando las dependencias nativas (la primera vez tarda)…"
  flutter precache --ios
  (cd ios && pod install)
fi

# Un iPhone de verdad, no el simulador: el simulador no tiene cámara, y
# el escáner es justo lo que hay que probar en el teléfono.
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
")

if [ -z "$TELEFONO" ]; then
  echo "No veo ningún iPhone conectado."
  echo
  echo "  - Cable, y desbloqueado"
  echo "  - Si aparece 'Confiar en esta computadora', confiar"
  echo "  - flutter devices  para ver qué detecta"
  exit 1
fi

# El candado que Apple agregó en iOS 16, y que no se parece a un candado.
#
# Confiar en la computadora no alcanza: el teléfono además tiene que estar
# en "modo de desarrollador", y hasta que lo esté, Apple **no registra el
# teléfono** y por lo tanto no emite la firma. El error que llega es
# "Your team has no devices from which to generate a provisioning
# profile", que suena a que el cable no está puesto y no tiene nada que
# ver: el cable estaba puesto, el teléfono aparecía en `flutter devices`,
# y el problema estaba en Ajustes.
#
# Se revisa antes de compilar porque compilar tarda minutos y el error
# aparece recién al final, después de todo el trabajo, diciendo otra cosa.
MODO=$(xcrun devicectl device info details --device "$TELEFONO" 2>/dev/null \
  | grep -i "developerModeStatus" | head -1)

if echo "$MODO" | grep -qi "disabled"; then
  echo "El iPhone no está en modo de desarrollador."
  echo
  echo "  En el teléfono:"
  echo "  1. Ajustes -> Privacidad y seguridad"
  echo "  2. Abajo del todo: Modo de desarrollador -> activar"
  echo "  3. Te pide reiniciar. Reiniciá."
  echo "  4. Al encender sale '¿Activar el modo de desarrollador?' -> Activar"
  echo
  echo "  El paso 4 aparece una sola vez, después de reiniciar."
  exit 1
fi

echo "Compilando…"
# --release y no debug: en debug el código Dart va interpretado y la app
# se siente casi tan lenta como la web, que es justo lo que se quiere
# dejar atrás. En release va compilado a instrucciones arm64.
flutter build ios --release --dart-define-from-file=claves.json

# Y la instalación aparte, con devicectl.
#
# `flutter run` también instala, pero después **queda enganchado a la
# app**: se queda esperando que alguien apriete `q` para desconectarse.
# Está bien cuando querés ver los mensajes de la app mientras la usás; no
# está bien cuando lo único que querés es dejarla instalada, porque el
# comando no termina nunca.
echo "Instalando en ${TELEFONO}…"
xcrun devicectl device install app --device "$TELEFONO" \
  build/ios/iphoneos/Runner.app 2>&1 | grep -E "App installed|bundleID|error|Error" || true

# Y antes de soltar el cable, cuánto dura esta firma. Es el dato que hace
# que reinstalar sea algo que se agenda en vez de algo que se descubre
# cuando la app no abre.
echo
"$(dirname "${BASH_SOURCE[0]}")/dias.sh" || true
