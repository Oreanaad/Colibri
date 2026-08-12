#!/usr/bin/env bash
#
# Comprueba que las consultas de reseñas sean válidas contra la base.
#
#     ./servidor/probar_resenas.sh
#
# # Lo que este script puede y lo que no
#
# Puede: confirmar que los nombres de columna y de relación existen, que
# las claves ajenas por las que se cruza están declaradas, y que **sin
# sesión no se ve ni una reseña ajena**.
#
# No puede: confirmar que la consulta traiga algo cuando sí hay reseñas.
# Eso necesita una sesión de verdad y datos de verdad, y ninguna de las dos
# debería manejarlas este script.
#
# Y ahí está la trampa que ya nos pasó una vez: una consulta puede ser
# perfectamente válida, contestar 200, devolver una lista vacía, y estar
# rota. La primera versión pedía `ediciones!inner` y `fanfics!inner` juntas,
# cuando el esquema tiene un check que dice que una lectura tiene una de las
# dos y nunca las dos: habría devuelto cero para siempre. El servidor jamás
# se habría quejado. Por eso el script además **lee el check del esquema** y
# revisa que ninguna consulta pida las dos con inner.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAVES="$RAIZ/colibri/claves.json"

[ -f "$CLAVES" ] || { echo "Falta colibri/claves.json"; exit 1; }

python3 - "$CLAVES" "$RAIZ/colibri/lib/nube.dart" "$RAIZ/servidor/esquema.sql" <<'PY'
import json, re, sys, urllib.error, urllib.parse, urllib.request

claves = json.load(open(sys.argv[1]))
url, clave = claves["SUPABASE_URL"], claves["SUPABASE_CLAVE"]
nube = open(sys.argv[2]).read()
esquema = open(sys.argv[3]).read()

fallos = 0

# Las consultas se leen del código, no se copian: dos copias se
# desincronizan y esto diría que todo está bien mientras la app usa otra.
comunes = re.search(r"const _comunes =\s*((?:\s*'[^']*'\s*)+);", nube)
partes = {}
for nombre in ["resenasDeUnLibro", "resenasDeUnFanfic"]:
    m = re.search(rf"const {nombre} = '([^']*)'", nube)
    if not m:
        print(f"  no encontré {nombre} en lib/nube.dart")
        sys.exit(1)
    base = "".join(re.findall(r"'([^']*)'", comunes.group(1))) if comunes else ""
    partes[nombre] = m.group(1).replace("$_comunes", base)


def pedir(consulta, filtro=""):
    p = urllib.request.Request(
        f"{url}/rest/v1/lecturas?select={urllib.parse.quote(consulta)}{filtro}&limit=5",
        headers={"apikey": clave, "Authorization": f"Bearer {clave}"},
    )
    try:
        with urllib.request.urlopen(p, timeout=30) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


print("Las consultas que usa la app:\n")
for nombre, consulta in partes.items():
    codigo, cuerpo = pedir(consulta)
    if codigo == 200:
        print(f"  {nombre:20} válida (200)")
    else:
        fallos += 1
        print(f"  {nombre:20} RECHAZADA {codigo}: {cuerpo.get('message','')[:60]}")

print()
print("El check del esquema, y lo que implica:")
check = re.search(r"check \(num_nonnulls\(edicion_id, fanfic_id\) = (\d)\)", esquema)
if not check:
    fallos += 1
    print("  no encontré el check una_cosa_por_lectura: ¿cambió el esquema?")
else:
    print(f"  num_nonnulls(edicion_id, fanfic_id) = {check.group(1)}")
    for nombre, consulta in partes.items():
        dos = "ediciones!inner" in consulta and "fanfics!inner" in consulta
        if dos:
            fallos += 1
            print(f"  {nombre}: pide las DOS con inner -> devolvería cero siempre")
        else:
            print(f"  {nombre:20} pide una sola con inner, bien")

print()
print("Lo que NO se pide, que es lo que más importa:")
for nombre, consulta in partes.items():
    if "nota" in consulta:
        fallos += 1
        print(f"  {nombre}: PIDE la nota privada")
    else:
        print(f"  {nombre:20} no pide la nota privada")

print()
print("Control, para que las de arriba signifiquen algo:")
codigo, cuerpo = pedir("resena,perfiles!inner(inventada)")
if codigo == 400:
    print("  una columna inventada da 400, como tiene que ser")
else:
    fallos += 1
    print(f"  una columna inventada dio {codigo}: las pruebas de arriba no valen")

print()
print("Lo que ve alguien sin sesión:")
vacias = all(pedir(c)[1] == [] for c in partes.values())
if vacias:
    print("  nada, ni una reseña ajena")
else:
    fallos += 1
    print("  ATENCIÓN: devolvió reseñas sin sesión")

print()
print("Todo bien." if fallos == 0 else f"{fallos} problema(s).")
sys.exit(1 if fallos else 0)
PY
