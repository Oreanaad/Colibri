-- Colibrí · el esquema de la base
--
-- Está escrito para Supabase, que es Postgres con las cuentas ya hechas.
-- Corre igual en un Postgres pelado si antes se levanta el remedo de
-- `auth` que está en `local.sql`.
--
--     psql -f servidor/esquema.sql
--
-- ============================================================
-- LAS TRES DECISIONES QUE EXPLICAN TODO LO DEMÁS
-- ============================================================
--
-- 1. OBRA Y EDICIÓN SON COSAS DISTINTAS.
--
--    «Pedro Páramo» es una obra. La edición del Fondo de Cultura de 2012
--    con tapa naranja es una edición. Vos leíste una edición, pero cuando
--    alguien busca el libro busca la obra.
--
--    Mezclarlas es el error que arruina estos catálogos: o tenés
--    doscientas fichas del mismo libro, o tenés una sola y nadie encuentra
--    la suya.
--
-- 2. LO QUE VOS HICISTE CON UN LIBRO NO ES DEL LIBRO, ES TUYO.
--
--    Por eso `lecturas` es una tabla aparte y no columnas de `ediciones`.
--    Mil personas leyeron la misma edición y cada una lloró distinto.
--
-- 3. LO PRIVADO VIVE EN OTRA TABLA, NO EN OTRA COLUMNA.
--
--    Postgres protege filas, no columnas. Si las notas privadas fueran una
--    columna de `lecturas`, cualquier permiso que deje ver tu estante
--    dejaría ver tus notas. Están en `notas`, con su propia regla.

-- Sin `begin` ni `commit` a propósito: el editor de Supabase ya corre
-- todo lo que le pegás dentro de una transacción, y abrir otra adentro
-- le saca un aviso o directamente falla. Para correrlo con psql, la
-- atomicidad la pone `--single-transaction`, que es lo que hace
-- `probar.sh`.

-- ============================================================
-- QUIÉN SOS
-- ============================================================

create table perfiles (
  id            uuid primary key references auth.users(id) on delete cascade,

  -- Texto común y no `citext`, aunque `citext` parezca lo obvio para que
  -- «Lucia» y «lucia» sean la misma persona.
  --
  -- No hace falta: la regla de formato de más abajo pide `[a-z]`, así que
  -- un nombre con mayúsculas no entra, punto. La app ya los pasa a
  -- minúsculas antes de mandarlos.
  --
  -- Y sale más barato: `citext` es una extensión, las extensiones en
  -- Supabase viven en otro esquema, y ahí el tipo deja de resolverse
  -- según cómo esté armado el camino de búsqueda. Una dependencia menos
  -- es un problema menos.
  usuario       text not null unique,

  nombre        text not null default '',
  presentacion  text not null default '',

  -- Si tu estante lo puede mirar cualquiera. En true por defecto porque
  -- la app se trata de eso, pero apagable: hay gente que lee cosas que no
  -- quiere que su familia vea, y eso es motivo suficiente.
  publico       boolean not null default true,

  desde         timestamptz not null default now(),

  -- Las mismas reglas que valida la app, acá abajo también. No es
  -- desconfianza: es que el día que haya una segunda app, o alguien
  -- entre por la API, estas reglas tienen que seguir valiendo.
  constraint usuario_bien_formado check (
    usuario ~ '^[a-z][a-z0-9._]{2,19}$'
    and usuario !~ '[._]$'
    and usuario !~ '[._]{2}'
  ),
  constraint usuario_no_reservado check (
    usuario not in (
      'admin', 'administrador', 'colibri', 'oficial', 'ayuda', 'soporte',
      'staff', 'moderacion', 'root', 'api', 'yo', 'vos', 'nuevo', 'null'
    )
  )
);

-- ============================================================
-- EL CATÁLOGO: OBRAS, EDICIONES Y FANFICS
-- ============================================================

create table obras (
  id      uuid primary key default gen_random_uuid(),
  titulo  text not null,
  autor   text not null,

  -- La clave normalizada que ya calcula la app: título sin acentos ni
  -- mayúsculas, más las palabras del nombre ordenadas alfabéticamente,
  -- para que «Juan Rulfo» y «Rulfo, Juan» sean la misma persona.
  clave   text not null unique,

  creada  timestamptz not null default now()
);

create table ediciones (
  id         uuid primary key default gen_random_uuid(),
  obra_id    uuid not null references obras(id) on delete cascade,

  titulo     text not null,      -- el de esta edición, en su idioma
  idioma     text,               -- spa, eng, por…
  editorial  text,
  anio       int,
  paginas    int,
  tapa_url   text,

  -- El ISBN de trece dígitos, único en todo el catálogo. Es lo que hace
  -- que escanear el mismo libro dos veces no cree dos fichas.
  isbn       text unique,

  origen     text not null default 'catalogo'
             check (origen in ('catalogo', 'propio')),

  cargada_por uuid references perfiles(id) on delete set null,
  creada      timestamptz not null default now(),

  constraint isbn_de_trece check (isbn is null or isbn ~ '^\d{13}$'),
  constraint anio_posible  check (anio is null or anio between 1400 and 2100)
);

create index ediciones_por_obra   on ediciones (obra_id);
create index ediciones_por_idioma on ediciones (obra_id, idioma);

-- Los fanfics son otra tabla y no una edición más, y no es por prolijidad:
-- **se identifican distinto**. Un libro es su ISBN; un fanfic es su
-- dirección, porque el título lo escribe cada persona a su manera y el
-- mismo fic entraría cuatro mil veces.
create table fanfics (
  id          uuid primary key default gen_random_uuid(),

  -- 'ao3:1234567', 'wattpad:336699'. La calcula la app a partir del
  -- enlace, y es lo único que decide si dos fichas son el mismo fic.
  identidad   text not null unique,

  enlace      text not null,
  titulo      text not null,
  autoria     text not null default '',
  fandom      text,
  capitulos   int,

  cargado_por uuid references perfiles(id) on delete set null,
  creado      timestamptz not null default now(),

  -- «ao3:1234567», «wattpad:336699», «web:miblog.com/x». El nombre del
  -- sitio puede llevar números —ao3 los lleva— y eso lo encontró una
  -- prueba, no yo: la primera versión pedía solo letras y rechazaba
  -- justamente el sitio más usado.
  constraint identidad_con_sitio check (identidad ~ '^[a-z][a-z0-9]*:.+')
);

create index fanfics_por_fandom on fanfics (fandom);

-- ============================================================
-- LO TUYO
-- ============================================================

create table lecturas (
  id          uuid primary key default gen_random_uuid(),
  perfil_id   uuid not null references perfiles(id) on delete cascade,

  -- Una lectura es de un libro **o** de un fanfic. Nunca de los dos, y
  -- nunca de ninguno: sin esto se podrían guardar lecturas huérfanas que
  -- después nadie sabe de qué eran.
  edicion_id  uuid references ediciones(id) on delete cascade,
  fanfic_id   uuid references fanfics(id)   on delete cascade,

  estado      text not null default 'pendiente'
              check (estado in ('leyendo', 'leido', 'pendiente')),

  puntaje     smallint not null default 0 check (puntaje   between 0 and 5),
  lagrimas    smallint not null default 0 check (lagrimas  between 0 and 5),
  romantico   smallint not null default 0 check (romantico between 0 and 5),
  picante     smallint not null default 0 check (picante   between 0 and 5),

  pagina_actual int not null default 0 check (pagina_actual >= 0),
  empezado    date,
  terminado   date,

  resena              text,
  resena_con_spoilers boolean not null default false,

  creada      timestamptz not null default now(),
  actualizada timestamptz not null default now(),

  constraint una_cosa_por_lectura
    check (num_nonnulls(edicion_id, fanfic_id) = 1),

  -- Si empezaste y terminaste, no pudiste terminar antes de empezar.
  constraint fechas_en_orden
    check (empezado is null or terminado is null or terminado >= empezado),

  -- El mismo libro dos veces en tu biblioteca no tiene sentido. En la de
  -- otra persona sí: por eso la unicidad es por perfil.
  unique (perfil_id, edicion_id),
  unique (perfil_id, fanfic_id)
);

create index lecturas_por_perfil on lecturas (perfil_id, estado);
create index lecturas_por_edicion on lecturas (edicion_id);

-- Las notas privadas viven acá y no en `lecturas`, y esta es la razón
-- entera de que exista esta tabla:
--
-- Postgres protege **filas**, no columnas. Si esto fuera una columna de
-- `lecturas`, el permiso que deja a otra persona ver tu estante dejaría
-- ver también tus notas. Separadas, la regla es una línea y no se puede
-- equivocar.
create table notas (
  lectura_id uuid primary key references lecturas(id) on delete cascade,
  texto      text not null,
  actualizada timestamptz not null default now()
);

-- ============================================================
-- FRASES
-- ============================================================

create table frases (
  id         uuid primary key default gen_random_uuid(),
  lectura_id uuid not null references lecturas(id) on delete cascade,

  texto      text not null,
  pagina     int,

  -- Las frases son privadas salvo que digas lo contrario.
  publica    boolean not null default false,

  creada     timestamptz not null default now(),

  -- El tope de ochocientos caracteres no es un detalle técnico: es lo que
  -- impide que la app se convierta en un lugar donde se reconstruyen
  -- libros enteros frase por frase. Está en la app y está acá, porque una
  -- regla legal que vive en un solo lado es una regla que se pierde.
  constraint frase_corta check (char_length(texto) between 1 and 800)
);

create index frases_por_lectura on frases (lectura_id);

-- ============================================================
-- ETIQUETAS Y ESTANTES
-- ============================================================

-- Las doce etiquetas de «cómo te dejó». Lista cerrada a propósito: con
-- texto libre, «me destruyó», «me destrozó» y «me rompió» son tres cosas
-- distintas y no se puede agrupar nada.
create table animos (
  nombre text primary key,
  orden  smallint not null
);

create table lectura_animos (
  lectura_id uuid not null references lecturas(id) on delete cascade,
  animo      text not null references animos(nombre) on delete cascade,
  primary key (lectura_id, animo)
);

-- Las etiquetas que la gente pide y todavía no están. No se publican: se
-- juntan para leerlas, y cuando una se repite mucho entra a la lista.
create table animos_propuestos (
  id        uuid primary key default gen_random_uuid(),
  texto     text not null,
  perfil_id uuid references perfiles(id) on delete set null,
  creada    timestamptz not null default now()
);

create table estantes (
  id        uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references perfiles(id) on delete cascade,
  nombre    text not null,
  creado    timestamptz not null default now(),

  unique (perfil_id, nombre)
);

create table estante_lecturas (
  estante_id uuid not null references estantes(id) on delete cascade,
  lectura_id uuid not null references lecturas(id) on delete cascade,
  primary key (estante_id, lectura_id)
);

create table personajes (
  lectura_id uuid not null references lecturas(id) on delete cascade,
  nombre     text not null,
  primary key (lectura_id, nombre)
);

-- ============================================================
-- QUIÉN PUEDE VER QUÉ
-- ============================================================
--
-- Row Level Security: sin esto, cualquiera con la clave pública de la app
-- puede leer y escribir la tabla entera. Con esto, cada consulta lleva
-- adosada la pregunta «¿y esto es tuyo?».
--
-- Se prende en todas las tablas. Una tabla sin RLS en Supabase es una
-- tabla abierta al mundo.

alter table perfiles          enable row level security;
alter table obras             enable row level security;
alter table ediciones         enable row level security;
alter table fanfics           enable row level security;
alter table lecturas          enable row level security;
alter table notas             enable row level security;
alter table frases            enable row level security;
alter table animos            enable row level security;
alter table lectura_animos    enable row level security;
alter table animos_propuestos enable row level security;
alter table estantes          enable row level security;
alter table estante_lecturas  enable row level security;
alter table personajes        enable row level security;

-- --- Perfiles ---
--
-- # Una decisión que conviene entender antes de cambiarla
--
-- «Público» acá quiere decir **visible para quien tenga cuenta**, no
-- visible para todo internet. La diferencia no es chica: lo que alguien
-- lee dice muchísimo de esa persona, y una biblioteca abierta sin cuenta
-- es una biblioteca que se puede bajar entera, indexar y cruzar con
-- otras cosas, por gente que nunca va a usar la app.
--
-- El catálogo sí queda abierto, porque hace falta para que alguien pueda
-- buscar un libro antes de registrarse.
--
-- Se puede abrir más algún día con una línea. **Al revés no**: una vez que
-- los datos de la gente se copiaron, no se descopian.

create policy "los perfiles públicos los ve quien tenga cuenta"
  on perfiles for select
  using (id = auth.uid() or (publico and auth.uid() is not null));

create policy "cada quien arma el suyo"
  on perfiles for insert with check (id = auth.uid());

create policy "cada quien edita el suyo"
  on perfiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- --- El catálogo: de todas ---

-- Se lee sin cuenta. Alguien que todavía no se registró tiene que poder
-- buscar un libro: si no, la app está vacía hasta que te registres, y
-- nadie se registra en una app vacía.
create policy "el catálogo lo lee cualquiera"
  on obras for select using (true);
create policy "las ediciones las lee cualquiera"
  on ediciones for select using (true);
create policy "los fanfics los lee cualquiera"
  on fanfics for select using (true);

-- Cargar sí necesita cuenta: es lo único que hace que se pueda saber
-- quién cargó cada cosa el día que haya que limpiar el catálogo.
create policy "con cuenta se puede cargar una obra"
  on obras for insert with check (auth.uid() is not null);
create policy "con cuenta se puede cargar una edición"
  on ediciones for insert with check (auth.uid() is not null);
create policy "con cuenta se puede cargar un fanfic"
  on fanfics for insert with check (auth.uid() is not null);

-- Y nadie edita ni borra del catálogo desde la app. Corregir una ficha
-- ajena es moderación, y la moderación no puede ser un botón que tiene
-- todo el mundo.

-- --- Lecturas: tuyas para escribir, de todas para mirar ---

create policy "el estante de alguien se puede mirar"
  on lecturas for select
  using (
    perfil_id = auth.uid()
    or (
      auth.uid() is not null
      and exists (
        select 1 from perfiles p
        where p.id = lecturas.perfil_id and p.publico
      )
    )
  );

create policy "cada quien escribe sus lecturas"
  on lecturas for insert with check (perfil_id = auth.uid());
-- El `with check` va escrito aunque Postgres lo asuma cuando falta: sin
-- él, la regla se lee como «podés editar tus filas» y lo que dice de
-- verdad es «además, no podés dejarlas a nombre de otra persona».
create policy "cada quien edita sus lecturas"
  on lecturas for update
  using (perfil_id = auth.uid())
  with check (perfil_id = auth.uid());
create policy "cada quien borra sus lecturas"
  on lecturas for delete using (perfil_id = auth.uid());

-- --- Notas privadas: de nadie más ---
--
-- Sin «or es público». Es toda la diferencia con la regla de arriba, y es
-- por eso que las notas están en su propia tabla.

create policy "las notas son solo tuyas"
  on notas for all
  using (
    exists (
      select 1 from lecturas l
      where l.id = notas.lectura_id and l.perfil_id = auth.uid()
    )
  );

-- --- Frases: privadas salvo que las publiques ---

create policy "las frases publicadas se ven"
  on frases for select
  using (
    (publica and auth.uid() is not null)
    or exists (
      select 1 from lecturas l
      where l.id = frases.lectura_id and l.perfil_id = auth.uid()
    )
  );

create policy "cada quien guarda sus frases"
  on frases for all
  using (
    exists (
      select 1 from lecturas l
      where l.id = frases.lectura_id and l.perfil_id = auth.uid()
    )
  );

-- --- Etiquetas ---

create policy "las etiquetas las ve cualquiera"
  on animos for select using (true);

create policy "los ánimos de una lectura visible se ven"
  on lectura_animos for select
  using (
    exists (
      select 1 from lecturas l join perfiles p on p.id = l.perfil_id
      where l.id = lectura_animos.lectura_id
        and (
          l.perfil_id = auth.uid()
          or (p.publico and auth.uid() is not null)
        )
    )
  );

create policy "cada quien pone sus etiquetas"
  on lectura_animos for all
  using (
    exists (
      select 1 from lecturas l
      where l.id = lectura_animos.lectura_id and l.perfil_id = auth.uid()
    )
  );

-- Las propuestas se mandan y no se leen: nadie tiene que poder mirar lo
-- que pidió el resto, ni siquiera quien lo pidió. Se leen desde afuera,
-- para decidir qué etiqueta entra.
create policy "proponer una etiqueta"
  on animos_propuestos for insert
  with check (auth.uid() is not null);

-- --- Estantes ---

create policy "los estantes de un perfil visible se ven"
  on estantes for select
  using (
    perfil_id = auth.uid()
    or (
      auth.uid() is not null
      and exists (
        select 1 from perfiles p
        where p.id = estantes.perfil_id and p.publico
      )
    )
  );

create policy "cada quien arma sus estantes"
  on estantes for all using (perfil_id = auth.uid());

create policy "lo que hay en un estante visible se ve"
  on estante_lecturas for select
  using (
    exists (
      select 1 from estantes e join perfiles p on p.id = e.perfil_id
      where e.id = estante_lecturas.estante_id
        and (
          e.perfil_id = auth.uid()
          or (p.publico and auth.uid() is not null)
        )
    )
  );

create policy "cada quien llena sus estantes"
  on estante_lecturas for all
  using (
    exists (
      select 1 from estantes e
      where e.id = estante_lecturas.estante_id and e.perfil_id = auth.uid()
    )
  );

-- --- Personajes ---

create policy "los personajes de una lectura visible se ven"
  on personajes for select
  using (
    exists (
      select 1 from lecturas l join perfiles p on p.id = l.perfil_id
      where l.id = personajes.lectura_id
        and (
          l.perfil_id = auth.uid()
          or (p.publico and auth.uid() is not null)
        )
    )
  );

create policy "cada quien elige sus personajes"
  on personajes for all
  using (
    exists (
      select 1 from lecturas l
      where l.id = personajes.lectura_id and l.perfil_id = auth.uid()
    )
  );

-- ============================================================
-- LAS DOCE ETIQUETAS
-- ============================================================

insert into animos (nombre, orden) values
  ('me destruyó', 1),
  ('me dio paz', 2),
  ('me hizo reír', 3),
  ('me dejó pensando', 4),
  ('me abrazó', 5),
  ('me incomodó', 6),
  ('me dio bronca', 7),
  ('me enamoró', 8),
  ('me dio miedo', 9),
  ('me devolvió las ganas de leer', 10),
  ('me costó', 11),
  ('me cambió algo', 12);
