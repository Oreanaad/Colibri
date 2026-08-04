-- ¿Quedó bien?
--
-- Se pega en el editor de Supabase después del esquema. Devuelve una
-- fila por cosa comprobada, con «bien» o «MAL». Si hay un solo MAL,
-- algo no entró.

select 'tablas' as que,
       count(*)::text as hay,
       '13' as esperado,
       case when count(*) = 13 then 'bien' else 'MAL' end as estado
from pg_tables where schemaname = 'public'

union all
select 'tablas con permisos prendidos',
       count(*)::text, '13',
       case when count(*) = 13 then 'bien' else 'MAL' end
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity

union all
select 'reglas de permisos',
       count(*)::text, '22 o más',
       case when count(*) >= 22 then 'bien' else 'MAL' end
from pg_policies where schemaname = 'public'

union all
select 'etiquetas de cómo te dejó',
       count(*)::text, '12',
       case when count(*) = 12 then 'bien' else 'MAL' end
from animos

union all
-- Quince, contadas de la base y no de memoria: la primera versión de
-- esta consulta esperaba veinte y marcaba MAL un esquema que estaba
-- perfecto. Postgres no cuenta los `not null` acá.
select 'reglas de la base (checks)',
       count(*)::text, '15 o más',
       case when count(*) >= 15 then 'bien' else 'MAL' end
from pg_constraint c join pg_class t on t.oid = c.conrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public' and c.contype = 'c'

union all
select 'el perfil apunta a las cuentas de Supabase',
       count(*)::text, '1',
       case when count(*) = 1 then 'bien' else 'MAL' end
from pg_constraint c
join pg_class t on t.oid = c.conrelid
join pg_class f on f.oid = c.confrelid
join pg_namespace fn on fn.oid = f.relnamespace
where t.relname = 'perfiles' and c.contype = 'f'
  and fn.nspname = 'auth' and f.relname = 'users'

order by 1;
