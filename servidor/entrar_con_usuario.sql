-- Entrar con el @usuario en vez del correo.
--
-- Pegar entero en Supabase -> SQL Editor -> Run.
--
-- ============================================================
-- POR QUÉ HACE FALTA ESTO
-- ============================================================
--
-- Supabase autentica por correo y contraseña. No sabe qué es un
-- «@usuario»: eso es una idea nuestra, que vive en la tabla `perfiles`.
--
-- Para que alguien escriba `oreanaad` y entre, hay que traducir ese nombre
-- al correo con el que se creó la cuenta. Y esa traducción tiene que pasar
-- **antes** de iniciar sesión, o sea sin sesión: en ese momento las reglas
-- de `perfiles` no dejan ver nada, y encima el correo no está en `perfiles`
-- sino en `auth.users`, que la app no puede leer nunca.
--
-- `security definer` es lo que resuelve las dos cosas: la función corre con
-- los permisos de quien la creó, no de quien la llama.
--
-- ============================================================
-- LO QUE ESTO EXPONE, DICHO SIN VUELTAS
-- ============================================================
--
-- Quien sepa un @usuario puede averiguar el correo de esa persona. Los
-- @usuario son públicos —para eso existen, para que te encuentren— así que
-- esto convierte «te encuentro» en «sé tu correo».
--
-- Eso importa: un correo sirve para spam y para intentos de robo de cuenta.
--
-- Se evaluó la alternativa: que la función pida también la contraseña y
-- solo devuelva el correo si es correcta. Eso taparía la fuga, pero abre
-- una peor: un lugar donde probar contraseñas **sin el límite de intentos**
-- que Supabase le pone a iniciar sesión. Cambiar una fuga segura por un
-- probador de contraseñas sin freno es peor negocio.
--
-- Si algún día esto molesta, se borra con una línea y la app vuelve sola a
-- pedir el correo:
--
--     drop function if exists public.correo_de_usuario(text);
--
-- ============================================================

create or replace function public.correo_de_usuario(nombre text)
returns text
language sql
security definer
-- El camino de búsqueda fijo y vacío salvo lo que hace falta: sin esto,
-- alguien que pueda crear un esquema propio podría poner ahí una tabla
-- `perfiles` falsa y esta función la usaría. Es la precaución estándar
-- para cualquier función `security definer`.
set search_path = public, auth
as $$
  select u.email
  from public.perfiles p
  join auth.users u on u.id = p.id
  -- $1 y no `nombre`, y esto es un bug que ya pasó:
  --
  -- El parámetro se llamaba `nombre`, y `perfiles` **tiene una columna
  -- llamada `nombre`**. Postgres, ante la duda, prefiere la columna. Así
  -- que la función comparaba `usuario` contra el nombre de pila de cada
  -- fila —«oreanaad» contra «Ore»— y devolvía null siempre.
  --
  -- No dio ningún error: es SQL perfectamente válido que compara dos cosas
  -- equivocadas. Se vio probando la función con un usuario que existía.
  --
  -- `$1` es el parámetro por posición y no se puede confundir con nada.
  --
  -- Exacto y en minúsculas. La columna ya solo admite minúsculas por su
  -- check de formato, y `lower` acá es para que dé igual cómo lo escriban
  -- en el teclado del teléfono, que a veces pone la primera en mayúscula.
  --
  -- Sin `like` ni comodines a propósito: esto contesta por un nombre, no
  -- deja recorrer la lista.
  where p.usuario = lower(trim($1))
  limit 1;
$$;

-- Quién puede llamarla: cualquiera, incluso sin sesión. Es todo el punto,
-- porque se llama justo antes de iniciar sesión.
revoke all on function public.correo_de_usuario(text) from public;
grant execute on function public.correo_de_usuario(text) to anon, authenticated;

-- ============================================================
-- COMPROBACIÓN
-- ============================================================
--
-- Un nombre que no existe tiene que devolver nada, no un error.

do $$
declare
  alguno text;
begin
  if (select public.correo_de_usuario('no_existe_nadie_asi')) is not null then
    raise exception 'un usuario inexistente devolvió algo';
  end if;

  -- Y que uno que **sí** existe devuelva su correo.
  --
  -- Esta comprobación faltaba, y por eso el bug del parámetro llegó a la
  -- base: la de arriba pasaba igual, porque con el bug la función devolvía
  -- null para todo, incluso para los usuarios que existen.
  select usuario into alguno from perfiles limit 1;
  if alguno is not null then
    if (select public.correo_de_usuario(alguno)) is null then
      raise exception 'el usuario % existe y la función no lo encontró', alguno;
    end if;
    -- Con mayúsculas y espacios de más también.
    if (select public.correo_de_usuario('  ' || upper(alguno) || '  ')) is null then
      raise exception 'no aguanta mayúsculas ni espacios';
    end if;
  end if;

  raise notice 'correo_de_usuario: lista.';
end
$$;
