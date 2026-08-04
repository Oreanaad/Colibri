-- Colibrí · pruebas del esquema
--
--     psql -v ON_ERROR_STOP=1 -f servidor/pruebas.sql
--
-- Se corre después de `local.sql`, `esquema.sql` y `permisos_local.sql`,
-- sobre una base recién creada. Si algo no cumple, el script se corta.
--
-- # Por qué las pruebas cambian de rol
--
-- En Postgres, **la dueña de una tabla se saltea las reglas de RLS**.
-- Probar los permisos conectada como la dueña es no probar nada: todo
-- pasa. Así que la mitad de abajo se corre como `authenticated`, que es
-- el rol con el que habla la app de verdad.

\set ON_ERROR_STOP on
\timing off

-- ============================================================
-- DOS PERSONAS
-- ============================================================

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'lucia@correo.com'),
  ('22222222-2222-2222-2222-222222222222', 'sofia@correo.com');

insert into perfiles (id, usuario, nombre) values
  ('11111111-1111-1111-1111-111111111111', 'lucia', 'Lucía'),
  ('22222222-2222-2222-2222-222222222222', 'sofia', 'Sofía');

-- ============================================================
-- LO QUE LA BASE NO TIENE QUE DEJAR PASAR
-- ============================================================

create procedure debe_fallar(sentencia text, que text)
language plpgsql as $$
begin
  begin
    execute sentencia;
  exception when others then
    raise notice '  ok · %', que;
    return;
  end;
  raise exception 'DEBERÍA HABER FALLADO: %', que;
end $$;

\pset tuples_only on

\echo ''
\echo '=== nombres de usuario ==='

call debe_fallar($$
  insert into auth.users (id) values ('33333333-3333-3333-3333-333333333333');
  insert into perfiles (id, usuario) values
    ('33333333-3333-3333-3333-333333333333', 'lu')$$,
  'uno de dos letras no entra');

call debe_fallar($$insert into perfiles (id, usuario) values
    ('33333333-3333-3333-3333-333333333333', '1lucia')$$,
  'uno que empieza con número tampoco');

call debe_fallar($$insert into perfiles (id, usuario) values
    ('33333333-3333-3333-3333-333333333333', 'lucia.')$$,
  'uno que termina en punto tampoco');

call debe_fallar($$insert into perfiles (id, usuario) values
    ('33333333-3333-3333-3333-333333333333', 'lu..cia')$$,
  'dos puntos seguidos tampoco');

call debe_fallar($$insert into perfiles (id, usuario) values
    ('33333333-3333-3333-3333-333333333333', 'admin')$$,
  'un nombre reservado tampoco');

call debe_fallar($$insert into perfiles (id, usuario) values
    ('33333333-3333-3333-3333-333333333333', 'LUCIA')$$,
  'uno con mayúsculas no entra: los @usuario son en minúscula');

\echo ''
\echo '=== el catálogo no se duplica ==='

insert into obras (id, titulo, autor, clave) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Cometierra', 'Dolores Reyes',
   'cometierra|dolores reyes');

insert into ediciones (id, obra_id, titulo, isbn, idioma) values
  ('bbbbbbbb-0000-0000-0000-000000000001',
   'aaaaaaaa-0000-0000-0000-000000000001', 'Cometierra',
   '9789874063656', 'spa');

call debe_fallar($$insert into ediciones (obra_id, titulo, isbn) values
    ('aaaaaaaa-0000-0000-0000-000000000001', 'COMETIERRA', '9789874063656')$$,
  'el mismo ISBN no entra dos veces');

call debe_fallar($$insert into ediciones (obra_id, titulo, isbn) values
    ('aaaaaaaa-0000-0000-0000-000000000001', 'x', '97898740636')$$,
  'un ISBN que no tiene trece dígitos no entra');

call debe_fallar($$insert into obras (titulo, autor, clave) values
    ('Cometierra', 'Dolores Reyes', 'cometierra|dolores reyes')$$,
  'la misma obra no entra dos veces');

\echo ''
\echo '=== el mismo fanfic, una sola vez ==='

insert into fanfics (id, identidad, enlace, titulo) values
  ('cccccccc-0000-0000-0000-000000000001', 'ao3:1234567',
   'https://archiveofourown.org/works/1234567', 'Todo lo que somos');

call debe_fallar($$insert into fanfics (identidad, enlace, titulo) values
    ('ao3:1234567', 'https://archiveofourown.org/works/1234567/chapters/9',
     'todo lo q somos [Drarry]')$$,
  'el mismo fic con otro título no entra dos veces');

call debe_fallar($$insert into fanfics (identidad, enlace, titulo) values
    ('sin-sitio', 'https://x.com/y', 'x')$$,
  'una identidad sin sitio no entra');

\echo ''
\echo '=== una lectura es de una sola cosa ==='

call debe_fallar($$insert into lecturas (perfil_id) values
    ('11111111-1111-1111-1111-111111111111')$$,
  'una lectura de nada no entra');

call debe_fallar($$insert into lecturas (perfil_id, edicion_id, fanfic_id)
  values ('11111111-1111-1111-1111-111111111111',
          'bbbbbbbb-0000-0000-0000-000000000001',
          'cccccccc-0000-0000-0000-000000000001')$$,
  'una lectura de un libro y un fanfic a la vez tampoco');

insert into lecturas (id, perfil_id, edicion_id, estado, puntaje,
                      empezado, terminado, resena)
values ('dddddddd-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111',
        'bbbbbbbb-0000-0000-0000-000000000001',
        'leido', 5, '2026-03-01', '2026-03-04',
        'Lo leí de un tirón.');

call debe_fallar($$insert into lecturas (perfil_id, edicion_id) values
    ('11111111-1111-1111-1111-111111111111',
     'bbbbbbbb-0000-0000-0000-000000000001')$$,
  'el mismo libro dos veces en la misma biblioteca no');

call debe_fallar($$update lecturas set puntaje = 6
  where id = 'dddddddd-0000-0000-0000-000000000001'$$,
  'seis estrellas no existen');

call debe_fallar($$update lecturas set terminado = '2026-02-01'
  where id = 'dddddddd-0000-0000-0000-000000000001'$$,
  'no se puede terminar antes de empezar');

\echo ''
\echo '=== el tope de las frases ==='

insert into frases (lectura_id, texto) values
  ('dddddddd-0000-0000-0000-000000000001', repeat('a', 800));

call debe_fallar($$insert into frases (lectura_id, texto) values
    ('dddddddd-0000-0000-0000-000000000001', repeat('a', 801))$$,
  'una frase de 801 caracteres no entra');

call debe_fallar($$insert into frases (lectura_id, texto) values
    ('dddddddd-0000-0000-0000-000000000001', '')$$,
  'una frase vacía tampoco');

\echo ''
\echo '=== las doce etiquetas ==='

do $$
declare cuantas int;
begin
  select count(*) into cuantas from animos;
  assert cuantas = 12, 'tienen que ser doce y son ' || cuantas;
  raise notice '  ok · están las doce';
end $$;

call debe_fallar($$insert into lectura_animos (lectura_id, animo) values
    ('dddddddd-0000-0000-0000-000000000001', 'me dio hambre')$$,
  'una etiqueta que no está en la lista no entra');

insert into lectura_animos (lectura_id, animo) values
  ('dddddddd-0000-0000-0000-000000000001', 'me destruyó');

-- Lo privado de Lucía, para probar los permisos abajo.
insert into notas (lectura_id, texto) values
  ('dddddddd-0000-0000-0000-000000000001', 'esto no lo lee nadie');

insert into frases (lectura_id, texto, publica) values
  ('dddddddd-0000-0000-0000-000000000001', 'una frase que sí comparto', true);

-- ============================================================
-- QUIÉN VE QUÉ
-- ============================================================
--
-- De acá para abajo se cambia de rol. Como `colibri` es la dueña de las
-- tablas, se saltea todas las reglas: probar acá arriba habría dado bien
-- sin probar nada.

\echo ''
\echo '=== Sofía mirando el estante de Lucía ==='

begin;
  set local role authenticated;
  set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

  do $$
  declare n int;
  begin
    select count(*) into n from lecturas;
    assert n = 1, 'Sofía debería ver la lectura pública de Lucía, ve ' || n;
    raise notice '  ok · ve el estante de Lucía, que es público';

    select count(*) into n from notas;
    assert n = 0, 'Sofía NO tendría que ver las notas privadas, ve ' || n;
    raise notice '  ok · NO ve las notas privadas';

    select count(*) into n from frases;
    assert n = 1, 'Sofía debería ver solo la frase publicada, ve ' || n;
    raise notice '  ok · ve la frase publicada y no la guardada';

    select count(*) into n from lectura_animos;
    assert n = 1, 'debería ver las etiquetas de una lectura pública';
    raise notice '  ok · ve las etiquetas';
  end $$;

  -- Y no puede escribir en lo de Lucía.
  --
  -- Ojo con cómo se prueba esto. Un `update` sobre filas que no ves **no
  -- da error**: cambia cero filas y sigue. Si se probara esperando una
  -- excepción, el test pasaría igual con los permisos apagados y no
  -- estaría probando nada. Hay que mirar el dato.
  update lecturas set puntaje = 1
    where perfil_id = '11111111-1111-1111-1111-111111111111';

  set local role colibri;
  do $$
  declare p int;
  begin
    select puntaje into p from lecturas
      where perfil_id = '11111111-1111-1111-1111-111111111111';
    assert p = 5, 'Sofía le cambió el puntaje a Lucía: quedó en ' || p;
    raise notice '  ok · su update no tocó nada de Lucía';
  end $$;
  set local role authenticated;

  -- Y meterle una lectura a nombre de Lucía sí da error, porque eso es
  -- una fila nueva y la regla la mira antes de dejarla entrar.
  call debe_fallar($$insert into lecturas (perfil_id, fanfic_id) values
      ('11111111-1111-1111-1111-111111111111',
       'cccccccc-0000-0000-0000-000000000001')$$,
    'no puede agregar lecturas a nombre de Lucía');
rollback;

\echo ''
\echo '=== Lucía con el perfil en privado ==='

begin;
  update perfiles set publico = false
    where id = '11111111-1111-1111-1111-111111111111';

  set local role authenticated;
  set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

  do $$
  declare n int;
  begin
    select count(*) into n from perfiles
      where id = '11111111-1111-1111-1111-111111111111';
    assert n = 0, 'un perfil privado no se ve';
    raise notice '  ok · el perfil no se ve';

    select count(*) into n from lecturas;
    assert n = 0, 'el estante de un perfil privado tampoco, ve ' || n;
    raise notice '  ok · el estante tampoco';
  end $$;
rollback;

\echo ''
\echo '=== Lucía en su propia casa ==='

begin;
  set local role authenticated;
  set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

  do $$
  declare n int;
  begin
    select count(*) into n from notas;
    assert n = 1, 'Lucía tiene que ver sus notas, ve ' || n;
    raise notice '  ok · ve sus notas privadas';

    select count(*) into n from frases;
    assert n = 2, 'Lucía ve sus dos frases, ve ' || n;
    raise notice '  ok · ve todas sus frases';
  end $$;

  update lecturas set puntaje = 4
    where perfil_id = '11111111-1111-1111-1111-111111111111';
  \echo '  ok · puede cambiar su propio puntaje'
rollback;

\echo ''
\echo '=== quien todavía no se registró ==='

begin;
  set local role anon;

  do $$
  declare n int;
  begin
    select count(*) into n from ediciones;
    assert n = 1, 'el catálogo se lee sin cuenta, ve ' || n;
    raise notice '  ok · puede buscar libros sin registrarse';

    -- Esto lo encontró esta misma prueba: la primera versión de los
    -- permisos dejaba que cualquiera, sin cuenta, se bajara el estante de
    -- todo el mundo. «Público» tiene que querer decir «para quien tenga
    -- cuenta», no «para todo internet».
    select count(*) into n from lecturas;
    assert n = 0, 'sin cuenta no se ven lecturas, ve ' || n;
    raise notice '  ok · no ve el estante de nadie';

    select count(*) into n from perfiles;
    assert n = 0, 'sin cuenta no se ven perfiles, ve ' || n;
    raise notice '  ok · no ve los perfiles';

    select count(*) into n from frases;
    assert n = 0, 'sin cuenta no se ven frases, ve ' || n;
    raise notice '  ok · no ve las frases publicadas';

    select count(*) into n from estantes;
    assert n = 0, 'sin cuenta no se ven estantes, ve ' || n;
    raise notice '  ok · no ve los estantes';

    select count(*) into n from notas;
    assert n = 0, 'sin cuenta no se ven notas';
    raise notice '  ok · no ve notas de nadie';
  end $$;

  call debe_fallar($$insert into obras (titulo, autor, clave)
    values ('x', 'y', 'x|y')$$,
    'sin cuenta no puede cargar nada al catálogo');
rollback;

\echo ''
\echo '=== todas las tablas con RLS prendido ==='

do $$
declare sin_rls text;
begin
  select string_agg(relname, ', ') into sin_rls
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;

  assert sin_rls is null,
    'estas tablas están abiertas al mundo: ' || sin_rls;
  raise notice '  ok · ninguna tabla quedó sin permisos';
end $$;

\echo ''
\echo 'Todo bien.'
