#!/usr/bin/env bash
#
# Compara los nombres de columna que usa lib/nube.dart contra los que
# tiene de verdad la base, sin necesitar ninguna clave privada.
#
#     ./servidor/probar_columnas_nube.sh
#
# Cómo funciona: PostgREST valida el parámetro `select=` contra las
# columnas reales de la tabla antes de mirar los permisos de fila. Pedir
# `select=columna_que_no_existe` contesta 400 aunque la fila esté vacía,
# así que sirve para cazar un nombre de columna mal escrito en el código
# Dart sin escribir un solo dato ni tener sesión abierta.
#
# Lo que NO prueba: que insertar y actualizar de verdad funcionen. Eso
# necesita una sesión autenticada, y no hay forma de conseguir una sin la
# clave service_role o sin confirmar un correo de verdad — ninguna de las
# dos cosas debería manejarlas quien escribe este script. Probarlo de
# punta a punta es un paso manual: crear la cuenta en la app y mirar que
# el libro aparezca en la tabla `lecturas` desde el panel de Supabase.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAVES="$RAIZ/colibri/claves.json"

[ -f "$CLAVES" ] || { echo "Falta colibri/claves.json"; exit 1; }

U=$(python3 -c "import json;print(json.load(open('$CLAVES'))['SUPABASE_URL'])")
K=$(python3 -c "import json;print(json.load(open('$CLAVES'))['SUPABASE_CLAVE'])")

python3 - "$U" "$K" <<'PY'
import sys, urllib.request, urllib.parse, urllib.error

U, K = sys.argv[1], sys.argv[2]

# Las mismas columnas que arman filaDeObra, filaDeEdicion, filaDeFanfic,
# filaDeLectura y los hijos, en lib/nube.dart. Si ese archivo cambia,
# esta lista tiene que cambiar con él.
esperado = {
    'obras': ['id', 'titulo', 'autor', 'clave'],
    'ediciones': ['id', 'obra_id', 'titulo', 'editorial', 'anio', 'paginas',
                  'tapa_url', 'isbn', 'origen', 'cargada_por'],
    'fanfics': ['id', 'identidad', 'enlace', 'titulo', 'autoria', 'fandom',
                'capitulos'],
    'lecturas': ['id', 'perfil_id', 'edicion_id', 'fanfic_id', 'estado',
                 'puntaje', 'lagrimas', 'romantico', 'picante',
                 'pagina_actual', 'empezado', 'terminado', 'resena',
                 'resena_con_spoilers'],
    'lectura_animos': ['lectura_id', 'animo'],
    'personajes': ['lectura_id', 'nombre'],
    'frases': ['id', 'lectura_id', 'texto', 'pagina', 'publica'],
    'estantes': ['id', 'perfil_id', 'nombre'],
    'estante_lecturas': ['estante_id', 'lectura_id'],
}

bien = True
for tabla, columnas in esperado.items():
    q = urllib.parse.urlencode({'select': ','.join(columnas), 'limit': '0'})
    url = f"{U}/rest/v1/{tabla}?{q}"
    req = urllib.request.Request(url, headers={'apikey': K, 'Authorization': f'Bearer {K}'})
    try:
        r = urllib.request.urlopen(req, timeout=20)
        print(f"  {tabla:20} bien · {len(columnas)} columnas")
    except urllib.error.HTTPError as e:
        print(f"  {tabla:20} MAL  · {e.read().decode()[:150]}")
        bien = False

print()
if bien:
    print("Todas las columnas que usa nube.dart existen en la base real.")
else:
    print("Hay un nombre de columna que no coincide. Ver arriba.")
    sys.exit(1)
PY
