-- Un remedo mínimo de lo que Supabase pone solo.
--
-- Supabase trae un esquema `auth` con la tabla de usuarios y la función
-- `auth.uid()`, que devuelve quién está haciendo la consulta. En un
-- Postgres pelado no existen, así que para poder probar el esquema de
-- verdad —y sobre todo para poder probar los permisos— se arman acá.
--
-- **Esto no va a Supabase.** Allá ya existe, y mejor hecho.

create schema if not exists auth;

create table if not exists auth.users (
  id     uuid primary key default gen_random_uuid(),
  email  text unique
);

-- Quién está preguntando. Supabase la saca del token; acá se pone a mano
-- con `set local request.jwt.claim.sub = '...'`, que es justo lo que hace
-- falta para probar que los permisos dejan afuera a quien corresponde.
create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

-- Los dos roles con los que habla Supabase: `anon` para quien no entró y
-- `authenticated` para quien sí. Allá existen; acá se arman para poder
-- probar los permisos con el mismo rol que va a usar la app.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end $$;

grant usage on schema public to anon, authenticated;
