#!/usr/bin/env bash
#
# Comprueba que la consulta con la que se baja la biblioteca sea válida
# contra la base de verdad, sin necesitar ninguna clave privada.
#
#     ./servidor/probar_bajada.sh
#
# # Por qué hace falta un script y no alcanza un test
#
# `flutter test` corta toda petición HTTP, así que desde ahí no se puede
# saber si `todoLoDeUnaLectura` es una consulta que el servidor entiende.
# Lo que sí se prueba en Dart es la conversión —ver test/bajar_test.dart,
# que es puro— pero eso da igual si el pedido nunca llega a hacerse.
#
# # Cómo funciona sin credenciales
#
# PostgREST valida el `select=` —nombres de columna y de relación— antes
# de mirar los permisos de fila. Una columna inventada contesta 400 con
# su nombre; una relación que no existe contesta 400 diciendo que no
# encontró la clave ajena. Un 200 con la lista vacía significa que la
# consulta entera es válida y que las reglas hicieron su trabajo: sin
# sesión, no se ve la biblioteca de nadie.
#
# Eso último es lo que se prueba al final, y es la parte que importa más:
# una consulta que trae libros ajenos sería peor que una que no anda.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAVES="$RAIZ/colibri/claves.json"
NUBE="$RAIZ/colibri/lib/nube.dart"

[ -f "$CLAVES" ] || { echo "Falta colibri/claves.json"; exit 1; }

U=$(python3 -c "import json;print(json.load(open('$CLAVES'))['SUPABASE_URL'])")
K=$(python3 -c "import json;print(json.load(open('$CLAVES'))['SUPABASE_CLAVE'])")

python3 - "$U" "$K" "$NUBE" <<'PY'
import json, re, sys, urllib.error, urllib.parse, urllib.request

url, clave, nube = sys.argv[1], sys.argv[2], sys.argv[3]


def pedir(consulta):
    """Devuelve (código, cuerpo) de un select contra lecturas."""
    p = urllib.request.Request(
        f"{url}/rest/v1/lecturas?select={urllib.parse.quote(consulta)}&limit=1",
        headers={"apikey": clave, "Authorization": f"Bearer {clave}"},
    )
    try:
        with urllib.request.urlopen(p, timeout=25) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


# La consulta se lee del código Dart, no se copia acá. Copiarla sería
# probar una consulta que se parece a la que usa la app en vez de la que
# usa la app: el día que cambie una, la otra seguiría diciendo que todo
# está bien.
texto = open(nube).read()
bloque = re.search(
    r"const todoLoDeUnaLectura\s*=\s*((?:\s*'[^']*'\s*)+);", texto
)
if not bloque:
    print("  no encontré todoLoDeUnaLectura en lib/nube.dart")
    sys.exit(1)
consulta = "".join(re.findall(r"'([^']*)'", bloque.group(1)))

fallos = 0

print("La consulta que usa la app:")
print(f"  {consulta}")
print()

codigo, cuerpo = pedir(consulta)
if codigo == 200:
    print("  válida  (200)")
else:
    fallos += 1
    try:
        print(f"  RECHAZADA ({codigo}): {json.loads(cuerpo).get('message')}")
    except Exception:
        print(f"  RECHAZADA ({codigo}): {cuerpo[:200]}")

# Cada tabla embebida, por separado: así un fallo dice cuál es y no
# obliga a mirar una consulta de siete líneas.
print()
print("Cada parte por su lado:")
for parte in re.findall(r"[a-z_]+\([^()]*(?:\([^()]*\))?[^()]*\)", consulta):
    codigo, cuerpo = pedir(parte)
    nombre = parte.split("(")[0]
    if codigo == 200:
        print(f"  {nombre:20} bien")
    else:
        fallos += 1
        try:
            print(f"  {nombre:20} MAL: {json.loads(cuerpo).get('message')}")
        except Exception:
            print(f"  {nombre:20} MAL ({codigo})")

# La prueba de que la de arriba no es vacía: si un nombre inventado
# también diera 200, todo lo anterior no probaría nada.
print()
print("Control, para que las de arriba signifiquen algo:")
codigo, _ = pedir("*,personajes(nombre_que_no_existe)")
if codigo == 400:
    print("  una columna inventada da 400, como tiene que ser")
else:
    fallos += 1
    print(f"  una columna inventada dio {codigo}: las pruebas de arriba no valen")

# Y lo más importante de todo.
print()
print("Lo que ve alguien sin sesión:")
codigo, cuerpo = pedir(consulta)
if codigo == 200 and json.loads(cuerpo) == []:
    print("  nada, ni una lectura ajena")
else:
    fallos += 1
    print(f"  ATENCIÓN: devolvió datos sin sesión ({codigo})")
    print(f"  {cuerpo[:300]}")

print()
print("Todo bien." if fallos == 0 else f"{fallos} problema(s).")
sys.exit(1 if fallos else 0)
PY
