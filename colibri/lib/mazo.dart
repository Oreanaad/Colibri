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
const mazoDeDescubrir =
    <(String, String, String?, int?, int?, int?)>[
  ('Cometierra', 'Dolores Reyes', '/works/OL24617061W', 11287141, 2014, null),
  ('Las malas', 'Camila Sosa Villada', '/works/OL20893481W', 10226058, 2020, 184),
  ('Cien años de soledad', 'Gabriel García Márquez', '/works/OL274505W', 12627383, 1967, 432),
  ('Pedro Páramo', 'Juan Rulfo', '/works/OL1731119W', 5419076, 1955, 130),
  ('Nuestra parte de noche', 'Mariana Enriquez', '/works/OL20901051W', 10239068, 2019, 640),
  ('Chicas muertas', 'Selva Almada', '/works/OL20023685W', 10121580, 2015, 187),
  ('La uruguaya', 'Pedro Mairal', '/works/OL26378818W', 12325434, 2013, 168),
  ('Catedrales', 'Claudia Piñeiro', '/works/OL24168102W', 10583553, 2021, null),
  ('Rayuela', 'Julio Cortázar', '/works/OL14860424W', 1047466, 1963, 633),
  ('Distancia de rescate', 'Samanta Schweblin', '/works/OL17317216W', 7395966, 2014, 160),
  ('Los detectives salvajes', 'Roberto Bolaño', '/works/OL712032W', 3706128, 1998, 619),
  ('La casa de los espíritus', 'Isabel Allende', '/works/OL1905255W', 3205226, 1982, 453),
  ('Como agua para chocolate', 'Laura Esquivel', '/works/OL953162W', 8372632, 1989, 246),
  ('Ficciones', 'Jorge Luis Borges', '/works/OL110971W', 10832290, 1945, 196),
  ('Kentukis', 'Samanta Schweblin', '/works/OL20760166W', 13241018, 2014, 256),
  ('La virgen cabeza', 'Gabriela Cabezón Cámara', '/works/OL18562985W', null, 2009, 160),
  ('Mugre rosa', 'Fernanda Trías', '/works/OL25484067W', 15124277, 2020, 276),
  ('Temporada de huracanes', 'Fernanda Melchor', '/works/OL17792692W', 10354466, 2017, 231),
  ('The Hunger Games', 'Suzanne Collins', '/works/OL5735363W', 12646537, 2008, 399),
  ('Divergent', 'Veronica Roth', '/works/OL15719630W', 13274634, 2010, 487),
  ('Percy Jackson and the Lightning Thief', 'Rick Riordan', '/works/OL492658W', 7239831, 2005, 384),
  ('City of Bones', 'Cassandra Clare', '/works/OL8455255W', 10121449, 2007, 512),
  ('A Court of Thorns and Roses', 'Sarah J. Maas', '/works/OL17352669W', 8738585, 2013, 451),
  ('Fourth Wing', 'Rebecca Yarros', '/works/OL29226517W', 14407898, 2023, 530),
  ('It Ends With Us', 'Colleen Hoover', '/works/OL18020194W', 10473609, 2012, 384),
  ('The Seven Husbands of Evelyn Hugo', 'Taylor Jenkins Reid', '/works/OL18203673W', 8354226, 2017, 400),
  ('A Game of Thrones', 'George R. R. Martin', '/works/OL257943W', 9269962, 1996, 801),
  ('The Fellowship of the Ring', 'J. R. R. Tolkien', '/works/OL27513W', 14627060, 1954, 492),
  ('Pride and Prejudice', 'Jane Austen', '/works/OL66554W', 14348537, 1813, 351),
];

/// Las categorías de Descubrir, ya resueltas.
///
/// # Por qué también van horneadas
///
/// Tocar una ficha de categoría pedía la lista a Open Library: unos 3
/// segundos, hasta 10 en la más lenta. Las etiquetas no cambian de un día
/// para el otro, así que se resuelven al compilar y la fila aparece al
/// instante, igual que el mazo.
///
/// La app **igual pregunta de fondo**, sin hacer esperar a nadie: si el
/// catálogo tiene algo distinto, la fila se actualiza sola. Lo horneado es
/// el piso, no el techo. Ver `_elegirCategoria` en destacados.dart.
///
/// La clave es la etiqueta de Open Library, no el nombre en castellano:
/// el nombre se cambia sin tocar esto.
const categoriasDeDescubrir =
    <String, List<(String, String, String?, int?, int?, int?)>>{
  'romantasy': [
    ('Once Upon a Broken Heart', 'Stephanie Garber', '/works/OL24706481W', 11427092, 2021, null),
    ('The Serpent & the Wings of Night', 'Carissa Broadbent', '/works/OL28520883W', 13451855, 2022, null),
    ('A Touch of Darkness', 'Scarlett St. Clair', '/works/OL21370801W', 10363130, 2019, null),
    ('The Ballad of Never After', 'Stephanie Garber', '/works/OL27090610W', 12945180, 2022, null),
    ('When the Moon Hatched', 'Sarah A. Parker', '/works/OL38010057W', 15161976, 2024, null),
    ('The Rose Bargain', 'Sasha Peyton Smith', '/works/OL42406366W', 15170176, 2025, null),
    ('Hurricane Wars', 'Thea Guanzon', '/works/OL34023561W', 14421764, 2023, null),
    ('King of Battle and Blood', 'Scarlett St. Clair', '/works/OL26200476W', 12194497, 2021, null),
    ('A Touch Of Ruin', 'Scarlett St. Clair', '/works/OL24662068W', 11357445, 2020, null),
    ('The Ashes and the Star-Cursed King', 'Carissa Broadbent', '/works/OL35014570W', 13976045, 2023, null),
    ('Assistant to the Villain', 'Hannah Nicole Maehrer', '/works/OL34840408W', 13620190, 2023, null),
    ('Belladonna', 'Adalyn Grace', '/works/OL26602235W', 12905843, 2022, null),
    ('A Curse for True Love', 'Stephanie Garber', '/works/OL33364737W', 13124827, 2023, null),
    ('The Courting of Bristol Keats', 'Mary E. Pearson', '/works/OL37683185W', 15118935, 2024, null),
    ('A Touch of Malice', 'Scarlett St. Clair', '/works/OL25914972W', 12415911, 2021, null),
    ('A Game of Fate', 'Scarlett St. Clair', '/works/OL22259152W', 10450006, 2020, null),
  ],
  'enemies_to_lovers': [
    ('Icebreaker', 'Hannah Grace', '/works/OL28952677W', 13180728, 2020, null),
    ('The Deal', 'Elle Kennedy', '/works/OL42430111W', 10201611, 2000, null),
    ('The Serpent & the Wings of Night', 'Carissa Broadbent', '/works/OL28520883W', 13451855, 2022, null),
    ('Merciless', 'Willow Winters', '/works/OL26793339W', 10328341, 2018, null),
    ('A Single Glance', 'Willow Winters', '/works/OL21940455W', 10413569, 2019, null),
    ('Breathless', 'Willow Winters', '/works/OL28715550W', 13709466, 2018, null),
    ('Twisted Games', 'Ana Huang', '/works/OL25515697W', 12821465, 2021, null),
    ('Heartless', 'Willow Winters', '/works/OL25478581W', 12026245, 2018, null),
    ('Hurricane Wars', 'Thea Guanzon', '/works/OL34023561W', 14421764, 2023, null),
    ('Beautiful bastard', 'Christina Lauren', '/works/OL19968136W', 10348137, 2013, null),
    ('Twisted Lies', 'Ana Huang', '/works/OL27818823W', 14425197, 2022, null),
    ('Instant Karma', 'Marissa Meyer', '/works/OL20800241W', 10096840, 2020, null),
    ('King of Battle and Blood', 'Scarlett St. Clair', '/works/OL26200476W', 12194497, 2021, null),
    ('The Ashes and the Star-Cursed King', 'Carissa Broadbent', '/works/OL35014570W', 13976045, 2023, null),
    ('Tell Me You Want Me', 'Willow Winters', '/works/OL26087200W', 15133307, 2021, null),
    ('A Single Kiss', 'Willow Winters', '/works/OL28593409W', 15133325, 2019, null),
  ],
  'dark_romance': [
    ('Sweet Savage Love', 'Rosemary Rogers', '/works/OL4996160W', 234725, 1974, null),
    ('Twisted Love', 'Ana Huang', '/works/OL24390422W', 12940491, 2021, null),
    ('Dirty Dom', 'Willow Winters', '/works/OL22298836W', 10452246, 2016, null),
    ('Bad Girl', 'Willow Winters', '/works/OL27914548W', 15139269, 2016, null),
    ('Possessive', 'Willow Winters', '/works/OL24637603W', 11318027, 2018, null),
    ('Bought', 'Lauren Landish', '/works/OL27701041W', 13916211, 2016, null),
    ('Broken', 'Willow Winters', '/works/OL29515951W', 13772660, 2016, null),
    ('She Asked for It', 'Willow Winters', '/works/OL40837726W', 13219174, 2018, null),
    ('Bad Boy', 'Willow Winters', '/works/OL27016597W', 12517503, 2016, null),
    ('Merciless', 'Willow Winters', '/works/OL26793339W', 10328341, 2018, null),
    ('Sold', 'Lauren Landish', '/works/OL27706145W', 13163682, 2016, null),
    ('His Hostage', 'Willow Winters', '/works/OL26977932W', 15133352, 2016, null),
    ('A Single Glance', 'Willow Winters', '/works/OL21940455W', 10413569, 2019, null),
    ('Wounded Kiss', 'Willow Winters', '/works/OL28065825W', 15133943, 2020, null),
    ('Good Girl', 'Willow Winters', '/works/OL34080522W', 15133329, 2016, null),
    ('Given', 'Willow Winters', '/works/OL27695402W', 15134272, 2017, null),
  ],
  'epic_fantasy': [
    ('A Game of Thrones', 'George R. R. Martin', '/works/OL257943W', 9269962, 1996, null),
    ('A Feast for Crows', 'George R. R. Martin', '/works/OL257948W', 6501256, 2005, null),
    ('The Eyes of the Dragon', 'Stephen King', '/works/OL81602W', 8524085, 1959, null),
    ('Wizard\'s First Rule', 'Terry Goodkind', '/works/OL2010436W', 1005963, 1994, null),
    ('A Dance With Dragons', 'George R. R. Martin', '/works/OL1955906W', 11298743, 2008, null),
    ('The Passage', 'Justin Cronin', '/works/OL15168588W', 8261369, 2010, null),
    ('The Wise Man’s Fear', 'Patrick Rothfuss', '/works/OL8479869W', 8294024, 2011, null),
    ('The Way of Kings', 'Brandon Sanderson', '/works/OL15358691W', 14658316, 2010, null),
    ('The Hero of Ages', 'Brandon Sanderson', '/works/OL5738154W', 14658094, 2008, null),
    ('A Memory of Light', 'Robert Jordan', '/works/OL16799133W', 14658328, 2013, null),
    ('Words of Radiance', 'Brandon Sanderson', '/works/OL16813053W', 14658334, 2012, null),
    ('The Crystal Shard', 'R. A. Salvatore', '/works/OL516728W', 1048109, 1988, null),
    ('Mistress of the Empire', 'Raymond E. Feist', '/works/OL554751W', 8695449, 1992, null),
    ('Lord Foul\'s Bane', 'Stephen R. Donaldson', '/works/OL11640876W', 9262497, 1977, null),
    ('The Spine of the World', 'R. A. Salvatore', '/works/OL516693W', 3197160, 1999, null),
    ('The Silent Blade', 'R. A. Salvatore', '/works/OL516691W', 3197151, 1998, null),
  ],
  'magic_realism': [
    ('Cien años de soledad', 'Gabriel García Márquez', '/works/OL274505W', 12627383, 1967, null),
    ('The People in the Trees', 'Hanya Yanagihara', '/works/OL19111131W', 8420417, 2013, null),
    ('The Weird', 'Ann VanderMeer', '/works/OL16476127W', 7016948, 2011, null),
    ('The Sound of Building Coffins', 'Louis Maistros', '/works/OL8421152W', 6848804, 2009, null),
    ('"Yellow peril"', 'Richard Jaccoma', '/works/OL6796902W', 13521350, 1978, null),
    ('Die Allee der verbotenen Fragen', 'Antonia Michaelis', '/works/OL20908269W', 10251739, 2016, null),
    ('The Snow Child', 'Eowyn Ivey', '/works/OL15980859W', 7255246, 2012, null),
    ('Traumklänge', 'Frederik Hetmann', '/works/OL23927570W', 12966069, 2004, null),
    ('Gian Paolo Dulbecco', 'Claudio Caserta', '/works/OL20429996W', 9096596, 2016, null),
    ('Orchard Park and Other Works', 'Tom Fahy', '/works/OL15167317W', 7251425, 2013, null),
    ('Il mago ascolta', 'Gian Paolo Dulbecco', '/works/OL15676795W', 6687380, 2004, null),
    ('Cuerpo Plural', 'Alejandro Varderi', '/works/OL15410607W', 11285305, 1978, null),
    ('Orchard Park', 'Tom Fahy', '/works/OL15456534W', 7105308, 2010, null),
    ('Living in Sin', 'Anastasia Vitsky', '/works/OL17093342W', 7335319, 2015, null),
    ('Tūla', 'Jurgis Kunčinas', '/works/OL18027558W', 13298697, 2016, null),
  ],
  'spanish_american_literature': [
    ('La casa de los espíritus', 'Isabel Allende', '/works/OL1905255W', 3205226, 1982, null),
    ('De amor y de sombra', 'Isabel Allende', '/works/OL1905374W', 4176665, 1984, null),
    ('The Last Days of Hitler', 'H. R. Trevor-Roper', '/works/OL4147253W', 143328, 1947, null),
    ('El hacedor', 'Jorge Luis Borges', '/works/OL110968W', 9311377, 1960, null),
    ('La expresión americana', 'José Lezama Lima', '/works/OL724164W', 4923742, 1957, null),
    ('The history of printing in America', 'Isaiah Thomas', '/works/OL239608W', 5858202, 1810, null),
    ('El cuento hispanoamericano', 'Seymour Menton', '/works/OL2251820W', 4924123, 1964, null),
    ('The literary history of Spanish America', 'Coester, Alfred', '/works/OL7094394W', 5852200, 1916, null),
    ('Escritores representativos de América', 'Luis Alberto Sánchez', '/works/OL1190713W', 4904206, 1957, null),
    ('Literatura hispanoamericana', 'Orlando Gómez-Gil', '/works/OL1347073W', 4938691, 1971, null),
    ('La utopía arcaica', 'Mario Vargas Llosa', '/works/OL857611W', 10034338, 1978, null),
    ('Studies in Spanish-American literature', 'Goldberg, Isaac', '/works/OL1504133W', 5885915, 1920, null),
    ('Historia de la literatura hispanoamericana', 'Enrique Anderson Imbert', '/works/OL711079W', 7371757, 1954, null),
    ('Nuestra América', 'José Martí', '/works/OL858785W', 6724717, 1909, null),
    ('The epic of Latin American literature', 'Arturo Torres-Rioseco', '/works/OL1152917W', 8005946, 1942, null),
    ('Textos Recobrados', 'Jorge Luis Borges', '/works/OL110922W', 8726846, 2002, null),
  ],
  'literatura_argentina': [
    ('El hacedor', 'Jorge Luis Borges', '/works/OL110968W', 9311377, 1960, null),
    ('Plan de evasión', 'Adolfo Bioy Casares', '/works/OL14944488W', 4480853, 1945, null),
    ('Historia de la eternidad', 'Jorge Luis Borges', '/works/OL110964W', 10831415, 1936, null),
    ('Nueva antología personal', 'Jorge Luis Borges', '/works/OL104914W', 9919340, 1968, null),
    ('Adán Buenosayres', 'Leopoldo Marechal', '/works/OL1212515W', 2152131, 1948, null),
    ('La trama celeste', 'Adolfo Bioy Casares', '/works/OL14944482W', 4911698, 1948, null),
    ('Historias fantásticas', 'Adolfo Bioy Casares', '/works/OL14944481W', 5258560, 1972, null),
    ('Respiración artificial', 'Ricardo Piglia', '/works/OL2056318W', 13788977, 1980, null),
    ('Historia Critica de la Literatura Argentina', 'Noe Jitrik', '/works/OL5647346W', 5229547, 1999, null),
    ('La Guerra Interior', 'Eduardo Mallea', '/works/OL1179528W', 5229681, 1963, null),
    ('Aguas abajo', 'Wilde, Eduardo', '/works/OL4226298W', 6464385, 1914, null),
    ('Research guide to Argentine literature', 'David William Foster', '/works/OL1863086W', 8488398, 1970, null),
    ('El Sueño', 'César Aira', '/works/OL710927W', 10365172, 1998, null),
    ('Personaje y lectura en cinco novelas de Manuel Puig', 'Geneviève Fabry', '/works/OL979512W', 3714670, 1998, null),
  ],
  'fan_fiction': [
    ('Foundation’s Friends', 'Martin H. Greenberg', '/works/OL16688802W', 9160121, 1989, null),
    ('Fangirl', 'Rainbow Rowell', '/works/OL17052872W', 7316505, 2013, null),
    ('Fan fiction and copyright', 'Aaron Schwabach', '/works/OL16296543W', 13109810, 2011, null),
    ('Fangirl', 'Rainbow Rowell', '/works/OL20003482W', 8977002, 2013, null),
    ('Career building through fan fiction writing', 'Miriam Segall', '/works/OL9699487W', 5342609, 2008, null),
    ('Film Remakes, Adaptations and Fan Productions', 'K. Loock', '/works/OL21617487W', 10386608, 2012, null),
    ('Ship it', 'Britta Lundin', '/works/OL19740599W', 12354269, 2018, null),
    ('Rogue Archives', 'Abigail De Kosnik', '/works/OL17694821W', 8049663, 2016, null),
    ('The Fanfiction Reader', 'Francesca Coppa', '/works/OL20220932W', 8873326, 2017, null),
    ('Beakman\'s World/Castelo Ra Tim Bum', '"Teary Eyes" Anderson', '/works/OL24207525W', 10653344, 2020, null),
    ('The heart rate of a mouse', 'Autor desconocido', '/works/OL19547726W', 8514270, 2018, null),
    ('Woke Cinderella', 'Suzy Woltmann', '/works/OL21950913W', 14140089, 2020, null),
    ('Gena/Finn', 'Hannah Moskowitz', '/works/OL20024504W', 13096338, 2016, null),
    ('Loose Lips', 'Amy Stephenson', '/works/OL21588488W', 12929737, 2016, null),
    ('Fan fiction and fan communities in the age of the Internet', 'Karen Hellekson', '/works/OL19499428W', 12918732, 2006, null),
    ('Creative Crowds', 'Vera Cuntz-Leng', '/works/OL38055639W', 13244180, 2014, null),
  ],
};
