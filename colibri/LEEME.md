# Colibrí — demo

Tu biblioteca y la de toda tu gente. *De libro en libro.*

Una versión funcional para probar en el teléfono. Busca libros de verdad
contra Open Library, guarda tu biblioteca en el dispositivo y muestra las
dos funciones que diferencian a la app: **las coincidencias** y **las
reseñas por capas de spoiler**.

---

## Probarla ahora mismo, sin instalar nada

Ya está compilada y servida en la red de tu casa:

**En la compu** → http://localhost:8080
**En el teléfono** → http://192.168.68.104:8080 *(mismo wifi)*

En Android, desde Chrome: menú **⋮ → Agregar a pantalla de inicio**. Queda
con ícono propio y abre sin barra de navegador. Se ve y se usa como una app.

Para volver a levantar el servidor si lo cerraste:

```bash
cd build/web && python3 -m http.server 8080 --bind 0.0.0.0
```

Y si cambiás código, antes:

```bash
flutter build web --release
```

---

## Qué probar

1. **Buscá un libro** con la lupa de arriba a la derecha. Escribí tres letras
   y esperá: la búsqueda arranca sola.
2. **Agregá varios** con el `+`. Se guardan en el teléfono.
3. **Abrí uno** y ponelo en *Leyendo*, puntualo tocando las estrellas.
4. **Movés la barra de "por dónde vas"** y mirá cómo se abren las reseñas
   de abajo. Eso es la función de capas de spoiler funcionando de verdad.
5. **Andá a Comunidad.** Es la biblioteca de Caro, que es de mentira. Los
   libros que también tengas vos se encienden en oro. Agregá *Rayuela* o
   *Pedro Páramo* a tu biblioteca y volvé: vas a ver el encuentro.

### La prueba que más importa

Buscá **los veinte libros que estás leyendo vos y tus amigas**. Los que no
aparezcan son los que la comunidad va a tener que cargar a mano. Esa
proporción es el dato más importante que tenés ahora mismo, y define si la
carga manual es una función de emergencia o la función principal.

---

## Para sacar el APK

Falta una sola cosa: **el Android SDK**. Flutter ya está, el proyecto ya
tiene la carpeta `android/` armada.

1. Instalá **Android Studio** desde https://developer.android.com/studio
   (trae el JDK y el SDK juntos; son unos cuantos GB).
2. Abrilo una vez y dejá que instale los componentes que pide.
3. Después, acá:

```bash
flutter doctor            # tiene que dar ✓ en "Android toolchain"
flutter build apk --debug
```

El archivo queda en:

```
build/app/outputs/flutter-apk/app-debug.apk
```

Ese lo pasás por WhatsApp o cable y se instala en cualquier Android
(hay que permitir "instalar apps de origen desconocido"). Sirve para probar
y para repartir entre amigas, **no para publicar**: para la tienda hace
falta `flutter build appbundle` y una firma propia.

---

## Cómo está organizado

```
lib/
  tema.dart              La paleta y la tipografía. Un solo lugar.
  modelos.dart           Libro, Estante y la biblioteca que se guarda.
  api.dart               Open Library: búsqueda y tapas.
  widgets.dart           Tapa, Estrellas, Logotipo, botones.
  pantallas/
    biblioteca.dart      Tu biblioteca, con "ahora mismo" arriba.
    buscar.dart          Buscar y agregar.
    ficha.dart           Ficha del libro, capas de spoiler, frase subrayada.
    comunidad.dart       La biblioteca de otra persona y las coincidencias.
```

Las dos reglas de color están escritas en `tema.dart` y conviene sostenerlas:

- **Si algo responde al dedo, va en lila.**
- **Si hay otra persona del otro lado, va en oro. Nunca un botón.**

---

## Qué es de verdad y qué es de mentira

**De verdad:** la búsqueda, las tapas, tu biblioteca (se guarda en el
teléfono), los estantes, las puntuaciones, el progreso de lectura, y el
cálculo de coincidencias.

**De mentira:** Caro y su estante (nueve libros fijos que se resuelven una
vez contra Open Library), las reseñas, las etiquetas de ánimo y la frase
subrayada. Todo eso necesita servidor y cuentas, que es el paso siguiente.

**Todavía no está:** cargar un libro a mano cuando no aparece, el escáner
de código de barras, y la tapa generada aparece sola cuando Open Library no
tiene la imagen (probá con narrativa argentina reciente y la vas a ver).
