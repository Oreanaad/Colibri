# La base de Colibrí

Postgres. Escrito para **Supabase**, que es Postgres con las cuentas ya
resueltas, pero corre igual en un Postgres pelado.

## Probarlo

    ./servidor/probar.sh

Levanta un servidor descartable, arma el esquema entero y corre 39
comprobaciones. No toca ninguna base tuya y se apaga solo al terminar.

Necesita Postgres instalado:

    brew install postgresql@16

## Los archivos

| | qué es |
|---|---|
| `esquema.sql` | Las trece tablas, las reglas y los permisos. **Esto es lo que va a Supabase.** |
| `pruebas.sql` | Las 39 comprobaciones. Si algo no cumple, se corta. |
| `local.sql` | Un remedo de lo que Supabase pone solo (`auth.users`, `auth.uid()`). **No va a Supabase**: allá ya existe. |
| `permisos_local.sql` | Los permisos de tabla que Supabase da solo. Tampoco va. |
| `probar.sh` | El ciclo entero en un comando. |

## Ponerlo en Supabase

1. Crear un proyecto en <https://supabase.com> (gratis para empezar).
2. Ir a **SQL Editor**.
3. Pegar `esquema.sql` entero y darle *Run*.
4. Nada más. `local.sql` y `permisos_local.sql` **no se pegan**.

## Las tres decisiones que explican el diseño

**Obra y edición son cosas distintas.** *Pedro Páramo* es una obra; la
edición del Fondo de Cultura de 2012 con tapa naranja es una edición. Vos
leíste una edición, pero cuando alguien busca el libro busca la obra.
Mezclarlas es el error que arruina estos catálogos.

**Lo que hiciste con un libro no es del libro, es tuyo.** Por eso
`lecturas` es una tabla aparte: mil personas leyeron la misma edición y
cada una lloró distinto.

**Lo privado vive en otra tabla, no en otra columna.** Postgres protege
filas, no columnas. Si las notas privadas fueran una columna de
`lecturas`, el permiso que deja ver tu estante dejaría ver tus notas.

## Tres cosas que encontraron las pruebas

No son anécdotas: las tres estaban mal en la primera versión y las tres
las encontró `pruebas.sql`, no yo.

1. **La identidad de los fanfics rechazaba AO3.** La regla pedía que el
   sitio fueran solo letras, y `ao3` tiene un número. Justo el sitio más
   usado.

2. **Un `update` sobre filas ajenas no da error.** Cambia cero filas y
   sigue. La prueba esperaba una excepción, así que habría pasado igual
   con los permisos apagados. Ahora mira el dato.

3. **Sin cuenta se veía el estante de todo el mundo.** «Público» tiene que
   querer decir *visible para quien tenga cuenta*, no *para todo
   internet*: lo que alguien lee dice muchísimo de esa persona, y una
   biblioteca abierta se baja entera, se indexa y se cruza. El catálogo sí
   queda abierto, porque hace falta para buscar un libro antes de
   registrarse.

Esa tercera es una decisión, no un arreglo: se puede abrir más con una
línea. **Al revés no**, porque los datos que se copiaron no se descopian.

## Y una trampa que conviene saber

En Postgres, **la dueña de una tabla se saltea las reglas de RLS**.
Probar los permisos conectada como ella es no probar nada: todo pasa. Por
eso `pruebas.sql` cambia de rol a `authenticated` y a `anon`, que son los
que usa la app de verdad.
