#!/usr/bin/env bash
#
# Aplica los cambios de estructura a la base de Supabase.
#
#     ./servidor/aplicar.sh [archivo.sql ...]
#
# Sin argumentos, aplica los que todavía no están puestos.
#
# # Por qué hace falta esto y no alcanza con la app
#
# La clave que la app lleva adentro sirve para leer y escribir **datos**:
# sumar un libro, guardar una reseña. No sirve para cambiar la **forma** de
# la base —agregar una columna, crear una función—, y eso está bien: si esa
# clave pudiera hacerlo, cualquiera que instale la app también podría.
#
# Cambiar la forma pide entrar a la base directamente, con la contraseña que
# Supabase da en Project Settings -> Database.
#
# # Dónde va esa contraseña
#
# En `servidor/.conexion`, que está en el .gitignore. Nunca en el código,
# nunca en un commit. Es la dirección completa que da Supabase:
#
#     postgresql://postgres:LACLAVE@db.xxxxx.supabase.co:5432/postgres
#
# Si algún día se filtra, se cambia desde el panel y este archivo se
# reemplaza. Es la única credencial del proyecto que abre la base entera,
# así que conviene tenerla en un solo lugar y saber cuál es.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONEXION="$RAIZ/servidor/.conexion"

export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

if [ ! -f "$CONEXION" ]; then
  cat <<'AYUDA'
Falta la dirección de la base.

  1. https://supabase.com/dashboard/project/fnyxbfvgizqxvakjbezt/settings/database
  2. Buscá "Connection string" y elegí la pestaña URI
  3. Copiala entera y pegala en servidor/.conexion

Va a tener esta forma, con tu contraseña adentro:

  postgresql://postgres:LACLAVE@db.fnyxbfvgizqxvakjbezt.supabase.co:5432/postgres

Ese archivo está en el .gitignore: no se sube a ningún lado.
AYUDA
  exit 1
fi

URL="$(tr -d '[:space:]' < "$CONEXION")"

# Supabase muestra la dirección con `[YOUR-PASSWORD]` escrito así, literal,
# y hay que reemplazarlo. Copiada tal cual, el error que llega es
# «password authentication failed», que no dice cuál es el problema.
case "$URL" in
  *"[YOUR-PASSWORD]"*|*"[TU-CONTRASEÑA]"*|*"[YOUR-PASSWORD"*)
    echo "La dirección todavía tiene el hueco de la contraseña:"
    echo
    echo "  $(echo "$URL" | sed 's/:[^:@]*@/:•••@/')"
    echo
    echo "Supabase escribe [YOUR-PASSWORD] literal y hay que reemplazarlo por"
    echo "la contraseña de la base —no la de tu cuenta de Supabase—."
    echo
    echo "Si no la tenés, en la misma pantalla hay «Reset database password»."
    echo "Cambiarla no rompe la app: la app usa las claves de la API, no ésta."
    exit 1
    ;;
esac

# Los que se aplican si no se pide ninguno en particular. En orden: el
# esquema base ya está puesto de antes, así que acá van solo los cambios.
if [ $# -gt 0 ]; then
  ARCHIVOS=("$@")
else
  ARCHIVOS=(
    "$RAIZ/servidor/perfil_completo.sql"
    "$RAIZ/servidor/entrar_con_usuario.sql"
  )
fi

echo "Conectando…"
# Una consulta trivial primero: si la contraseña está mal o la dirección no
# resuelve, es mejor enterarse antes de empezar a cambiar cosas.
if ! psql "$URL" -Atc "select 1" >/dev/null 2>/tmp/colibri-psql.err; then
  echo "No se pudo conectar:"
  sed 's/^/  /' /tmp/colibri-psql.err | head -4
  echo
  echo "  Si dice «password authentication failed», la contraseña está mal."
  echo "  Si dice «could not translate host name», falta parte de la dirección."
  exit 1
fi
echo "  bien."
echo

for archivo in "${ARCHIVOS[@]}"; do
  if [ ! -f "$archivo" ]; then
    echo "No existe: $archivo"
    exit 1
  fi

  echo "Aplicando $(basename "$archivo")…"
  # ON_ERROR_STOP para que un error corte en vez de seguir de largo
  # dejando la base a medio cambiar, y una transacción para que si algo
  # falla no quede nada aplicado.
  if psql "$URL" -v ON_ERROR_STOP=1 --single-transaction -q -f "$archivo" \
      2>&1 | sed 's/^/  /'; then
    echo "  listo."
  else
    echo "  FALLÓ. No se aplicó nada de ese archivo."
    exit 1
  fi
  echo
done

echo "Comprobando cómo quedó:"
psql "$URL" -At <<'SQL' | sed 's/^/  /'
select 'perfiles.' || column_name || ': está'
from information_schema.columns
where table_name = 'perfiles' and column_name in ('foto','libros','insignias')
union all
select 'correo_de_usuario: ' ||
  case when exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'correo_de_usuario'
  ) then 'está' else 'FALTA' end
order by 1;
SQL
