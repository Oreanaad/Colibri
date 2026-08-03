# Colibrí

**Tu biblioteca y la de toda tu gente.** *De libro en libro.*

Una app para la comunidad lectora: tu biblioteca personal, la de las demás,
y lo que pasa cuando las dos se cruzan.

---

## Qué hay acá

```
colibri/            La app (Flutter · Android, iOS y web)
buscar_tapas.py     Utilidad: busca tapas por título y autora
```

Para levantar la app, mirá [`colibri/LEEME.md`](colibri/LEEME.md).

---

## Las dos funciones que la diferencian

**Coincidencias.** Al entrar a la biblioteca de otra persona, los libros que
también tenés vos se encienden en oro. Convierte a una desconocida en alguien
con quien ya tenés catorce cosas en común, antes de cruzar una palabra.

**Reseñas por capas de spoiler.** Se escriben en tres tramos —sin spoilers,
hasta la mitad, el final— y solo se ve el que corresponde a por dónde va
quien lee. Los demás se abren solos al avanzar.

---

## Las dos reglas de color

Están escritas en `colibri/lib/tema.dart` y sostienen todo el diseño:

- **Si algo responde al dedo, va en lila.**
- **Si hay otra persona del otro lado, va en oro. Nunca un botón.**

El oro es lo único cálido en toda la app, y por eso se ve desde el otro lado
de la habitación. Si estuviera en cada botón, dejaría de significar algo.

---

## Postura de producto

**Ritmo, no rachas.** Las rachas diarias funcionan para los idiomas y el
gimnasio, pero con la lectura hacen daño: empujan a elegir libros cortos, a
leer apurada y a abandonar la app el día que se corta la racha. Colibrí
muestra ritmo y nunca castiga un día sin leer.

## Google Books, el segundo catálogo

Open Library encuentra bien por título, pero tiene **una sola edición con
ISBN** de la narrativa latinoamericana reciente. Por eso el escáner falla
justo con los libros que lee esta comunidad, y por eso hay un segundo
catálogo.

Google Books contesta sin clave, pero mete a todo internet en un mismo
proyecto anónimo compartido, y esa cuota está agotada casi siempre:

    Quota exceeded for quota metric 'Queries' and limit 'Queries per day'
    ... for consumer 'project_number:624717413613'

Así que la clave no es opcional. Es gratis: mil consultas por día.

### Sacar la clave

1. Entrá a <https://console.cloud.google.com> y creá un proyecto.
2. Buscá **Books API** y activala.
3. En *Credenciales*, creá una **clave de API**.
4. Limitala: que solo sirva para la Books API, y —cuando la app esté
   publicada— solo desde tu dirección web.

### Usarla

    cp colibri/claves.ejemplo.json colibri/claves.json
    # pegá la clave adentro

    cd colibri
    flutter run -d chrome --dart-define-from-file=claves.json

`claves.json` está ignorado por Git. **Nunca va al repositorio**, que es
público.

Sin clave la app funciona igual que antes: busca solo en Open Library, sin
errores ni avisos. Nunca se rompe por falta de clave.

### Verificarla

    flutter test tool/probar_google.dart --dart-define-from-file=claves.json

Las pruebas de `test/google_test.dart` usan respuestas armadas a mano,
porque la cuota anónima estaba agotada cuando se escribió el código. Esta
herramienta habla con Google de verdad y es la que confirma que el segundo
catálogo funciona.

### Una advertencia

Una clave que viaja dentro de una app es pública: cualquiera puede sacarla
del archivo instalado. Pasa en cualquier app de cualquier lenguaje. Por eso
se **limita** desde el panel de Google, y cuando exista servidor propio, se
mueve ahí.
