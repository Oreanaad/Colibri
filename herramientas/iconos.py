#!/usr/bin/env python3
"""Genera los iconos de Colibrí.

    python3 herramientas/iconos.py

# Por qué lomos y no una letra

El icono son lomos de libros, los mismos que dibuja `fondo.dart` en los
márgenes de la app. No es una decisión nueva: es la imagen que la app ya
usa para decir "esto es un estante", y a 60 píxeles en una pantalla de
inicio se reconoce como libros, que es lo único que tiene que lograr.

Una letra sola —una C en dorado— habría sido más fácil y habría quedado
como cualquier otro icono de cualquier otra app.

# Los colores

Los de la paleta, sin inventar ninguno: el violeta de la noche de fondo,
los lomos en los mismos tonos del librero, y **uno solo en oro**. En esta
app el oro está reservado para lo que involucra a otra persona; acá marca
el libro que no es tuyo, que es de lo que se trata Colibrí.
"""
from PIL import Image, ImageDraw

NOCHE = (23, 19, 49)
ORO = (233, 180, 76)
LOMOS = [(42, 34, 82), (58, 47, 105), (34, 27, 69), (74, 60, 128)]


def icono(lado: int, margen: float = 0.0) -> Image.Image:
    """Un icono cuadrado de `lado` px.

    `margen` es la fracción de aire alrededor. Los iconos "maskable" de
    Android se recortan en círculo, así que necesitan que el dibujo no
    llegue a los bordes; los normales usan todo el cuadrado.
    """
    img = Image.new("RGB", (lado, lado), NOCHE)
    d = ImageDraw.Draw(img)

    borde = int(lado * margen)
    util = lado - borde * 2

    # Los lomos, apoyados en una repisa. Anchos distintos para que se lea
    # como libros de verdad y no como un código de barras.
    anchos = [0.17, 0.13, 0.20, 0.15, 0.11]
    altos = [0.62, 0.74, 0.55, 0.68, 0.78]
    # El tercero va en oro: el del medio, que es donde cae la vista.
    dorado = 2

    total = sum(anchos) + 0.035 * (len(anchos) - 1)
    x = borde + (util - util * total) / 2
    piso = borde + util * 0.86

    for i, (a, h) in enumerate(zip(anchos, altos)):
        ancho = util * a
        alto = util * h
        color = ORO if i == dorado else LOMOS[i % len(LOMOS)]
        d.rounded_rectangle(
            [x, piso - alto, x + ancho, piso],
            radius=max(1, int(util * 0.012)),
            fill=color,
        )
        # La franja del título, que es lo que hace que se lea como lomo y
        # no como una barra de color.
        if ancho > util * 0.12:
            fy = piso - alto * 0.72
            d.rectangle(
                [x + ancho * 0.24, fy, x + ancho * 0.76, fy + max(1, util * 0.011)],
                fill=NOCHE if i == dorado else (140, 125, 190),
            )
        x += ancho + util * 0.035

    # La repisa.
    d.rectangle(
        [borde + util * 0.06, piso, borde + util * 0.94, piso + max(2, util * 0.022)],
        fill=(96, 80, 150),
    )
    return img


if __name__ == "__main__":
    import pathlib

    web = pathlib.Path(__file__).parent.parent / "colibri" / "web"
    iconos = web / "icons"
    iconos.mkdir(parents=True, exist_ok=True)

    # Normales: el dibujo ocupa casi todo el cuadrado.
    icono(192).save(iconos / "Icon-192.png")
    icono(512).save(iconos / "Icon-512.png")

    # Maskable: Android los recorta en círculo, así que van con aire.
    icono(192, margen=0.14).save(iconos / "Icon-maskable-192.png")
    icono(512, margen=0.14).save(iconos / "Icon-maskable-512.png")

    # El de iOS. 180 es el tamaño exacto que pide la pantalla de inicio
    # del iPhone; con otro, lo reescala y queda blando.
    icono(180).save(iconos / "Icon-apple-180.png")

    icono(64).save(web / "favicon.png")
    print("iconos generados en colibri/web/")

    # Android. Los cinco tamaños que pide, uno por densidad de pantalla:
    # el teléfono elige el que le corresponde y no reescala ninguno.
    android = pathlib.Path(__file__).parent.parent / "colibri" / "android"
    res = android / "app" / "src" / "main" / "res"
    for carpeta, lado in [
        ("mipmap-mdpi", 48),
        ("mipmap-hdpi", 72),
        ("mipmap-xhdpi", 96),
        ("mipmap-xxhdpi", 144),
        ("mipmap-xxxhdpi", 192),
    ]:
        d = res / carpeta
        if d.exists():
            icono(lado).save(d / "ic_launcher.png")
    print("iconos generados en colibri/android/")

    # iPhone. Los tamaños no se escriben acá: se leen del Contents.json
    # que ya tiene el proyecto. Si Xcode alguna vez pide otro, aparece
    # ahí y esto lo genera solo, sin que haya que acordarse.
    #
    # Van sin margen y sin transparencia: iOS recorta las esquinas él
    # mismo, y un PNG con canal alfa hace que la subida a la App Store
    # falle con un error que no dice cuál es el archivo.
    import json

    ios = pathlib.Path(__file__).parent.parent / "colibri" / "ios"
    conjunto = ios / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if (conjunto / "Contents.json").exists():
        indice = json.loads((conjunto / "Contents.json").read_text())
        hechos = {}
        for imagen in indice["images"]:
            nombre = imagen.get("filename")
            if not nombre:
                continue
            lado = float(imagen["size"].split("x")[0])
            escala = int(imagen["scale"].rstrip("x"))
            hechos[nombre] = round(lado * escala)
        for nombre, lado in sorted(hechos.items()):
            icono(lado).convert("RGB").save(conjunto / nombre)
        print(f"iconos generados en colibri/ios/ ({len(hechos)} tamaños)")

    # La pantalla de arranque. La plantilla de Flutter la deja en blanco,
    # y en una app de fondo violeta oscuro eso es un fogonazo blanco cada
    # vez que se abre. Un cuadrado del color del fondo alcanza: no se ve
    # como una pantalla, se ve como que la app ya arrancó.
    lanzamiento = ios / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    if lanzamiento.exists():
        for nombre, lado in [
            ("LaunchImage.png", 1),
            ("LaunchImage@2x.png", 2),
            ("LaunchImage@3x.png", 3),
        ]:
            Image.new("RGB", (lado, lado), NOCHE).save(lanzamiento / nombre)
        print("pantalla de arranque generada en colibri/ios/")
