#!/usr/bin/env bash
#
# Le pregunta a tu Supabase de verdad, desde afuera, como lo haría
# cualquiera con la clave pública.
#
#     ./servidor/probar_conexion.sh
#
# Lee la URL y la clave de colibri/claves.json, que no está en el repo.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAVES="$RAIZ/colibri/claves.json"

[ -f "$CLAVES" ] || { echo "Falta colibri/claves.json"; exit 1; }

U=$(python3 -c "import json;print(json.load(open('$CLAVES'))['SUPABASE_URL'])")
K=$(python3 -c "import json;print(json.load(open('$CLAVES'))['SUPABASE_CLAVE'])")

pedir() {
  curl -s -o /tmp/colibri-r.json -w "%{http_code}" \
    -H "apikey: $K" -H "Authorization: Bearer $K" \
    "$U/rest/v1/$1" --max-time 20
}

fila() { printf "  %-34s %s\n" "$1" "$2"; }

echo "Preguntándole a $U"
echo
echo "El esquema entró:"
# En dos pasos: `pedir` escribe el código HTTP por salida estándar, y
# meterlo en la misma sustitución que la cuenta pegaba los dos números.
pedir 'animos?select=nombre' > /dev/null
n=$(python3 -c "import json;print(len(json.load(open('/tmp/colibri-r.json'))))" 2>/dev/null || echo 0)
fila "las doce etiquetas" "$([ "$n" = "12" ] && echo "sí, $n" || echo "MAL: $n")"

echo
echo "Sin cuenta se puede ver el catálogo:"
for t in obras ediciones fanfics; do
  fila "$t" "http $(pedir "$t?select=*&limit=1")"
done

echo
echo "Sin cuenta NO se puede ver lo de la gente:"
for t in perfiles lecturas notas frases estantes; do
  c=$(pedir "$t?select=*&limit=1")
  v=$(cat /tmp/colibri-r.json)
  fila "$t" "$([ "$v" = "[]" ] && echo "vacío, bien" || echo "MAL: $v")"
done

echo
echo "Sin cuenta no se puede escribir:"
c=$(curl -s -o /tmp/colibri-w.json -w "%{http_code}" -X POST \
  -H "apikey: $K" -H "Authorization: Bearer $K" \
  -H "Content-Type: application/json" \
  -d '{"titulo":"x","autor":"y","clave":"prueba|conexion"}' \
  "$U/rest/v1/obras" --max-time 20)
if grep -q "row-level security" /tmp/colibri-w.json; then
  fila "crear una obra" "rechazado por las reglas, bien"
else
  fila "crear una obra" "MAL: http $c $(head -c 60 /tmp/colibri-w.json)"
fi

echo
echo "Cómo está el registro:"
curl -s -H "apikey: $K" "$U/auth/v1/settings" --max-time 20 | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('  %-34s %s' % ('registro abierto', 'sí' if not d.get('disable_signup') else 'no'))
print('  %-34s %s' % ('pide confirmar el correo', 'sí' if d.get('mailer_autoconfirm') is False else 'NO — cualquiera entra con un correo inventado'))
"
