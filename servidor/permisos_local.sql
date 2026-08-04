-- Los permisos de tabla que Supabase da solo a los roles nuevos.
--
-- **Ojo con esto**: en Postgres, el dueño de una tabla **se saltea las
-- reglas de RLS**. Si se prueban los permisos conectada como la dueña,
-- todo pasa y parece que están bien puestos, cuando en realidad no se
-- probó nada. Por eso las pruebas cambian de rol.
grant select, insert, update, delete on all tables in schema public
  to authenticated;
grant select on all tables in schema public to anon;
