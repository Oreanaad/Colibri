#!/usr/bin/env bash
#
# Levanta un Postgres descartable, arma el esquema y corre las pruebas.
# No toca ninguna base tuya: crea un servidor propio en una carpeta
# temporal, lo usa y lo apaga.
#
#     ./servidor/probar.sh
#
set -euo pipefail

PG="${PG:-/opt/homebrew/opt/postgresql@16/bin}"
export PATH="$PG:$PATH"

command -v initdb >/dev/null || {
  echo "No encuentro Postgres. Instalalo con:  brew install postgresql@16"
  exit 1
}

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATOS="$(mktemp -d)/datos"
# El socket va en /tmp: Postgres no admite rutas de más de 103 caracteres
# y la carpeta temporal del sistema ya se come casi todas.
SOCK="$(mktemp -d /tmp/colibri-pg.XXXXXX)"
PUERTO="${PUERTO:-55432}"

limpiar() {
  pg_ctl -D "$DATOS" stop -m immediate >/dev/null 2>&1 || true
  rm -rf "$DATOS" "$SOCK"
}
trap limpiar EXIT

echo "Levantando un Postgres de prueba…"
initdb -D "$DATOS" -U colibri --auth=trust >/dev/null
pg_ctl -D "$DATOS" \
  -o "-p $PUERTO -k $SOCK -c listen_addresses=''" \
  -l "$DATOS/log" start >/dev/null
sleep 1

psql() { command psql -h "$SOCK" -p "$PUERTO" -U colibri -v ON_ERROR_STOP=1 "$@"; }

# `create database` no puede correr dentro de una transacción, así que va
# sin --single-transaction. Los archivos que siguen sí lo llevan: es lo
# que hace que el esquema entre entero o no entre.
psql -d postgres -qc "create database colibri;"

echo "Armando el esquema…"
for f in local esquema permisos_local; do
  psql -d colibri -q --single-transaction -f "$RAIZ/servidor/$f.sql" 2>&1 \
    | grep -v NOTICE || true
done

echo "Probando…"
psql -d colibri -q -f "$RAIZ/servidor/pruebas.sql" 2>&1 \
  | sed -E 's/^psql:.*: (NOTICE|ERROR):  //' \
  | grep -v '^ *$'
