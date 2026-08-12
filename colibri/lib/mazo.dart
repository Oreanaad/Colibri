// GENERADO POR herramientas/mazo.py — no editar a mano.
//
// Para cambiarlo: editá MAZO en ese script y correlo de nuevo.

/// El mazo de Descubrir, ya resuelto contra Open Library.
///
/// # Por qué está horneado y no se pide
///
/// El carrusel hacía una búsqueda por título para cada libro que mostraba.
/// Aunque salían en paralelo, la más lenta manda: medido contra Open
/// Library, entre 2 y 10 segundos antes de ver la primera tapa, y otros
/// cinco pedidos en cada «mostrame otros cinco».
///
/// Y la respuesta siempre era la misma, porque los títulos son fijos. Se
/// preguntaba en cada teléfono, cada vez, algo que ya se sabía. Ahora se
/// pregunta una sola vez, al compilar.
///
/// Lo único que queda por bajar son las imágenes de las tapas, que van al
/// caché de 30 días.
///
/// # Qué es cada campo
///
/// El título como lo escribe el catálogo, la autoría como la escribimos
/// nosotras, la clave de la obra —`/works/OL…`, la que necesita elegir
/// edición—, el número de tapa, el año y las páginas. Cualquiera puede
/// ser null: un libro que el catálogo no encontró sale con la tapa
/// dibujada, igual que antes.
const mazoDeDescubrir = <(String, String, String?, int?, int?, int?)>[
  ('Cometierra', 'Dolores Reyes', '/works/OL24617061W', 11287141, 2014, null),
  (
    'Las malas',
    'Camila Sosa Villada',
    '/works/OL20893481W',
    10226058,
    2020,
    184,
  ),
  (
    'Cien años de soledad',
    'Gabriel García Márquez',
    '/works/OL274505W',
    12627383,
    1967,
    432,
  ),
  ('Pedro Páramo', 'Juan Rulfo', '/works/OL1731119W', 5419076, 1955, 130),
  (
    'Nuestra parte de noche',
    'Mariana Enriquez',
    '/works/OL20901051W',
    10239068,
    2019,
    640,
  ),
  ('Chicas muertas', 'Selva Almada', '/works/OL20023685W', 10121580, 2015, 187),
  ('La uruguaya', 'Pedro Mairal', '/works/OL26378818W', 12325434, 2013, 168),
  ('Catedrales', 'Claudia Piñeiro', '/works/OL24168102W', 10583553, 2021, null),
  ('Rayuela', 'Julio Cortázar', '/works/OL14860424W', 1047466, 1963, 633),
  (
    'Distancia de rescate',
    'Samanta Schweblin',
    '/works/OL17317216W',
    7395966,
    2014,
    160,
  ),
  (
    'Los detectives salvajes',
    'Roberto Bolaño',
    '/works/OL712032W',
    3706128,
    1998,
    619,
  ),
  (
    'La casa de los espíritus',
    'Isabel Allende',
    '/works/OL1905255W',
    3205226,
    1982,
    453,
  ),
  (
    'Como agua para chocolate',
    'Laura Esquivel',
    '/works/OL953162W',
    8372632,
    1989,
    246,
  ),
  ('Ficciones', 'Jorge Luis Borges', '/works/OL110971W', 10832290, 1945, 196),
  ('Kentukis', 'Samanta Schweblin', '/works/OL20760166W', 13241018, 2014, 256),
  (
    'La virgen cabeza',
    'Gabriela Cabezón Cámara',
    '/works/OL18562985W',
    null,
    2009,
    160,
  ),
  ('Mugre rosa', 'Fernanda Trías', '/works/OL25484067W', 15124277, 2020, 276),
  (
    'Temporada de huracanes',
    'Fernanda Melchor',
    '/works/OL17792692W',
    10354466,
    2017,
    231,
  ),
  (
    'The Hunger Games',
    'Suzanne Collins',
    '/works/OL5735363W',
    12646537,
    2008,
    399,
  ),
  ('Divergent', 'Veronica Roth', '/works/OL15719630W', 13274634, 2010, 487),
  (
    'Percy Jackson and the Lightning Thief',
    'Rick Riordan',
    '/works/OL492658W',
    7239831,
    2005,
    384,
  ),
  (
    'City of Bones',
    'Cassandra Clare',
    '/works/OL8455255W',
    10121449,
    2007,
    512,
  ),
  (
    'A Court of Thorns and Roses',
    'Sarah J. Maas',
    '/works/OL17352669W',
    8738585,
    2013,
    451,
  ),
  ('Fourth Wing', 'Rebecca Yarros', '/works/OL29226517W', 14407898, 2023, 530),
  (
    'It Ends With Us',
    'Colleen Hoover',
    '/works/OL18020194W',
    10473609,
    2012,
    384,
  ),
  (
    'The Seven Husbands of Evelyn Hugo',
    'Taylor Jenkins Reid',
    '/works/OL18203673W',
    8354226,
    2017,
    400,
  ),
  (
    'A Game of Thrones',
    'George R. R. Martin',
    '/works/OL257943W',
    9269962,
    1996,
    801,
  ),
  (
    'The Fellowship of the Ring',
    'J. R. R. Tolkien',
    '/works/OL27513W',
    14627060,
    1954,
    492,
  ),
  (
    'Pride and Prejudice',
    'Jane Austen',
    '/works/OL66554W',
    14348537,
    1813,
    351,
  ),
];
