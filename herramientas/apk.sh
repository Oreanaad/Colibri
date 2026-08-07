#!/usr/bin/env bash
#
# Compila el APK de Android.
#
#     ./herramientas/apk.sh
#
# Android no pide cuenta de desarrollador ni nada que caduque: el APK se
# instala y queda. Distinto de iOS, donde con Apple ID gratis la app se
# borra a los 7 días.
#
# Se firma con el certificado de depuración, que es lo que Flutter usa
# cuando no hay uno propio configurado. Alcanza para instalar a mano;
# para publicar en Google Play haría falta uno de verdad.
set -euo pipefail

export PATH="$PATH:/Users/oreanaad/flutter/bin"
# El SDK y el Java quedaron instalados con Homebrew, sin permisos de
# administrador: el instalador oficial de Java pedía contraseña.
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
export PATH="$JAVA_HOME/bin:$PATH"

cd "$(dirname "${BASH_SOURCE[0]}")/../colibri"

# --split-per-abi y no un APK universal: el universal mete las tres
# arquitecturas en el mismo archivo y pesa 74 MB, cuando cada teléfono
# usa una sola. El de arm64 son 27 MB.
flutter build apk --release --split-per-abi --dart-define-from-file=claves.json

echo
ls -la build/app/outputs/flutter-apk/*.apk \
  | awk '{printf "  %-30s %6.1f MB\n", $9, $5/1048576}'
echo
echo "El de arm64 es el que sirve para cualquier teléfono actual."
