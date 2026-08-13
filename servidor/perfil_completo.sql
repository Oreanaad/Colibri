-- Que el perfil viaje entero: la foto, los tres libros y las insignias.
--
-- Pegar entero en Supabase -> SQL Editor -> Run.
--
-- ============================================================
-- QUÉ FALTABA
-- ============================================================
--
-- El perfil de la app tiene siete cosas y la tabla guardaba cuatro:
--
--     la app:      usuario nombre presentacion desde foto libros insignias
--     el servidor: usuario nombre presentacion desde
--
-- Así que entrar desde otro aparato traía el nombre y nada más. Ni la
-- foto, ni los tres libros que te representan, ni las insignias: se veían
-- solo en el teléfono donde se habían elegido, que es justo lo contrario de
-- para qué sirve tener cuenta.
--
-- ============================================================
-- POR QUÉ LA FOTO VA ACÁ Y NO EN UN DEPÓSITO DE ARCHIVOS
-- ============================================================
--
-- Lo «correcto» para imágenes es Supabase Storage: un depósito aparte, con
-- sus propias reglas y sus propias direcciones. Para una foto de perfil de
-- 256 píxeles no vale la pena.
--
-- Medido: la app ya la recorta, la achica a 256 y la guarda como JPEG de
-- calidad 82. El peor caso —una imagen de ruido puro, que es lo que peor
-- comprime— da 39 KB, o 52 mil caracteres en base64. Una foto de verdad da
-- bastante menos. Postgres guarda un texto de ese tamaño fuera de la fila
-- sin que nadie tenga que pensarlo.
--
-- A cambio: una tabla en vez de dos, sin direcciones que caduquen, sin
-- reglas nuevas que escribir, y la foto viaja en la misma consulta que ya
-- trae el perfil. Si algún día las fotos crecen, se muda; hoy sería
-- arquitectura para un problema que no existe.
--
-- El tope está escrito abajo igual, porque un campo de texto sin límite es
-- una invitación a que alguien suba un archivo de diez megas por la API.
-- ============================================================

alter table perfiles
  add column if not exists foto      text,
  add column if not exists libros    text[] not null default '{}',
  add column if not exists insignias text[] not null default '{}';

-- Los tres libros son tres. La app ya lo comprueba —está en el constructor
-- de `Perfil`, después de que una vez se colara por `copiarCon`— y acá
-- también, por la misma razón que el resto de las reglas de este esquema:
-- el día que haya una segunda app, o que alguien entre por la API, esto
-- tiene que seguir valiendo.
alter table perfiles
  drop constraint if exists tres_libros_como_mucho;
alter table perfiles
  add constraint tres_libros_como_mucho
  check (array_length(libros, 1) is null or array_length(libros, 1) <= 3);

-- Una insignia por saga, y hay pocas sagas. Diez es holgado y a la vez es
-- un techo: sin él, la lista puede crecer sin fin.
alter table perfiles
  drop constraint if exists pocas_insignias;
alter table perfiles
  add constraint pocas_insignias
  check (array_length(insignias, 1) is null or array_length(insignias, 1) <= 10);

-- El tope de la foto: 200 mil caracteres de base64 son unos 150 KB, casi
-- cuatro veces lo que produce la app en su peor caso. Suficiente aire para
-- que nunca moleste, y suficiente techo para que nadie suba una película.
alter table perfiles
  drop constraint if exists foto_chica;
alter table perfiles
  add constraint foto_chica
  check (foto is null or char_length(foto) <= 200000);

-- ============================================================
-- LAS REGLAS DE ACCESO NO CAMBIAN
-- ============================================================
--
-- Y es a propósito: son columnas de `perfiles`, así que ya están cubiertas
-- por la regla que existe —tu perfil lo ves vos, y los públicos los ve
-- quien tenga cuenta—. No hace falta tocar nada.
--
-- Esto es lo contrario de las notas privadas, que **sí** necesitaron su
-- propia tabla: ahí lo que se quería era que el permiso de ver el estante
-- no alcanzara para verlas, y Postgres protege filas y no columnas. Acá lo
-- que se quiere es exactamente que se vean junto con el perfil.

-- ============================================================
-- COMPROBACIÓN
-- ============================================================

do $$
declare
  cuantas int;
begin
  select count(*) into cuantas
  from information_schema.columns
  where table_name = 'perfiles'
    and column_name in ('foto', 'libros', 'insignias');

  if cuantas <> 3 then
    raise exception 'faltan columnas: solo aparecieron %', cuantas;
  end if;

  raise notice 'perfiles: foto, libros e insignias listas.';
end
$$;
