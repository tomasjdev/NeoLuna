"""Tienda de la colonia lunar: quiosco con ventana de atención, mostrador, toldo a rayas, techo en
arco, columnas, ojos de buey, letrero con marco y antena.

Medidas (studs): 17.4 de ancho x 13.4 de fondo x ~14 de alto. Frente = +Y en Blender (-Z en Roblox).
El toldo, el techo, el marco del cartel y la punta de la antena se pintan con el color de cada
tienda (desde el código); lo demás lleva su color fijo.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: F401,F403,E402

ACCENT = (235, 130, 40)
WHITE = (240, 240, 245)
STEEL = (150, 154, 168)
LIGHT = (225, 228, 236)


def build():
    reset_scene()
    parts = []

    def add(name, bm, preview, bevel_width, tint, material="SmoothPlastic", segments=2):
        parts.append(to_obj(name, bm, preview, bevel_width, segments, tint, material))

    add("base", box((17.4, 13.4, 0.7), (0, 0, 0.35)), (0.35, 0.37, 0.43), 0.2, (90, 94, 108), "Metal")
    add("body", box((15, 10.6, 7.4), (0, -0.2, 4.4)), (0.88, 0.9, 0.93), 0.9, LIGHT, "SmoothPlastic", 4)

    roof = arch(16.4, 12.0, 2.4)
    translate_bm(roof, (0, -0.2, 8.1))
    add("roof", roof, (0.92, 0.5, 0.16), 0.2, ACCENT)

    # ventana de atención con marco y mostrador
    add("window_dark", box((9.6, 0.2, 3.6), (0, 5.15, 5.0)), (0.12, 0.14, 0.22), 0.0, (35, 40, 60))
    frame = merge(
        [
            box((10.4, 0.5, 0.4), (0, 5.3, 6.9)),
            box((10.4, 0.5, 0.4), (0, 5.3, 3.1)),
            box((0.4, 0.5, 4.2), (-5.0, 5.3, 5.0)),
            box((0.4, 0.5, 4.2), (5.0, 5.3, 5.0)),
        ]
    )
    add("window_frame", frame, (0.58, 0.6, 0.66), 0.08, STEEL, "Metal")
    add("counter", box((11, 1.8, 0.5), (0, 6.1, 3.0)), (0.92, 0.92, 0.95), 0.15, WHITE)

    # toldo a rayas: 5 paneles inclinados, alternando color de la tienda y blanco
    awning_a, awning_b = [], []
    for index in range(5):
        panel = box((3.2, 3.8, 0.35), (0, 0, 0))
        rotate_bm(panel, (-18, 0, 0))
        translate_bm(panel, (-6.4 + index * 3.2, 7.1, 7.0))
        (awning_a if index % 2 == 0 else awning_b).append(panel)
    add("awning_a", merge(awning_a), (0.92, 0.5, 0.16), 0.12, ACCENT)
    add("awning_b", merge(awning_b), (0.95, 0.95, 0.97), 0.12, WHITE)

    # columnas delanteras
    pillars = []
    for side in (-1, 1):
        pillars.append(cylinder(0.6, 7.4, (side * 7.6, 5.6, 4.4), 14))
        pillars.append(cylinder(0.85, 0.5, (side * 7.6, 5.6, 0.95), 14))
        pillars.append(cylinder(0.85, 0.5, (side * 7.6, 5.6, 7.85), 14))
    add("pillars", merge(pillars), (0.88, 0.9, 0.93), 0.08, LIGHT)

    # ojos de buey en los costados
    rings, glass = [], []
    for side in (-1, 1):
        ring = torus(0.95, 0.18, (0, 0, 0), 18, 6)
        rotate_bm(ring, (0, 90, 0))
        translate_bm(ring, (side * 7.55, -0.2, 5.0))
        rings.append(ring)
        glass.append(cylinder(0.9, 0.2, (side * 7.5, -0.2, 5.0), 16, axis="X"))
    add("porthole", merge(rings), (0.58, 0.6, 0.66), 0.0, STEEL, "Metal")
    add("porthole_glass", merge(glass), (0.47, 0.75, 0.9), 0.0, (120, 190, 230), "Glass")

    # cartel con marco (el texto lo escribe el juego sobre "sign")
    add("sign", box((10, 0.7, 3.0), (0, 3.4, 12.6)), (0.15, 0.16, 0.2), 0.15, (38, 42, 52))
    trim = merge(
        [
            box((10.7, 0.9, 0.3), (0, 3.4, 14.25)),
            box((10.7, 0.9, 0.3), (0, 3.4, 10.95)),
            box((0.3, 0.9, 3.6), (-5.2, 3.4, 12.6)),
            box((0.3, 0.9, 3.6), (5.2, 3.4, 12.6)),
        ]
    )
    add("sign_trim", trim, (0.92, 0.5, 0.16), 0.08, ACCENT)
    struts = merge([cylinder(0.22, 1.6, (-3.5, 3.4, 10.4), 8), cylinder(0.22, 1.6, (3.5, 3.4, 10.4), 8)])
    add("sign_struts", struts, (0.58, 0.6, 0.66), 0.0, STEEL, "Metal")

    # antena
    add("antenna", cylinder(0.12, 3.4, (-5.5, -3.0, 11.9), 8), (0.58, 0.6, 0.66), 0.0, STEEL, "Metal")
    add("antenna_tip", sphere(0.38, (-5.5, -3.0, 13.7), 10, 6), (0.92, 0.5, 0.16), 0.0, ACCENT)

    export_asset("shop", parts)


build()
print("TIENDA LISTA")
