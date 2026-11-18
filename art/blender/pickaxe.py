"""Pico del minero: mango de madera con cinta en el agarre y pomo, cabeza de metal curvada con puntas
afiladas, collar con dos gemas brillantes.

El mango va a lo largo de Y en Blender (-Z hacia adelante en Roblox): la cabeza está en la punta
(y positivo) y se curva hacia el agarre, como un pico de verdad. El origen es el centro del mango.

Ejecutar:  blender --background --python art/blender/pickaxe.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: F401,F403,E402

WOOD = (170, 118, 72)
STEEL = (175, 188, 210)
WRAP = (205, 70, 60)
GEM = (255, 215, 90)

HANDLE_HALF = 2.2  # el mango va de y = -2.2 a y = +2.2
HEAD_Y = 2.3
ARC_RADIUS = 5.2
ARC_ANGLE = 27.0  # grados a cada lado del centro


def curved_head():
    """Cabeza en arco (plano YZ) que se afina hacia las dos puntas."""
    bm = bmesh.new()
    steps = 20
    rings = []
    for i in range(steps + 1):
        t = i / steps  # 0..1
        angle = math.radians((t * 2 - 1) * ARC_ANGLE)
        center = Vector((0, HEAD_Y + ARC_RADIUS * (math.cos(angle) - 1), ARC_RADIUS * math.sin(angle)))
        normal = Vector((0, math.cos(angle), math.sin(angle)))  # hacia afuera del arco
        # grosor: gordo en el centro y fino en las puntas
        k = 1.0 - abs(t * 2 - 1) ** 1.6
        width = 0.10 + 0.50 * k ** 0.7
        thick = 0.10 + 0.62 * k ** 0.8
        corners = []
        for sx, sn in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            corners.append(bm.verts.new(center + Vector((sx * width / 2, 0, 0)) + normal * (sn * thick / 2)))
        rings.append(corners)
    for i in range(steps):
        for j in range(4):
            j2 = (j + 1) % 4
            bm.faces.new((rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]))
    # puntas: el último anillo se cierra en un punto adelantado
    for index, direction in ((0, -1), (steps, 1)):
        angle = math.radians(direction * ARC_ANGLE)
        tangent = Vector((0, -math.sin(angle), math.cos(angle))) * direction
        ring = rings[index]
        center = sum((v.co for v in ring), Vector()) / 4
        tip = bm.verts.new(center + tangent * 0.7)
        for j in range(4):
            j2 = (j + 1) % 4
            if direction > 0:
                bm.faces.new((ring[j], ring[j2], tip))
            else:
                bm.faces.new((ring[j2], ring[j], tip))
    return bm


def build():
    reset_scene()
    parts = []

    def add(name, bm, preview, bevel_width, tint, material):
        parts.append(to_obj(name, bm, preview, bevel_width, 2, tint, material))

    # mango: un poco más ancho cerca de la cabeza, con pomo atrás
    handle = merge(
        [
            cylinder(0.22, 4.4, (0, 0, 0), 14, "Y", radius_top=0.27),
            sphere(0.34, (0, -HANDLE_HALF - 0.05, 0), 10, 6),
        ]
    )
    add("handle", handle, (0.78, 0.57, 0.39), 0.03, WOOD, "Wood")

    # cinta del agarre (3 vueltas)
    wraps = []
    for y in (-1.5, -1.1, -0.7):
        ring = torus(0.27, 0.07, (0, 0, 0), 14, 5)
        rotate_bm(ring, (90, 0, 0))
        translate_bm(ring, (0, y, 0))
        wraps.append(ring)
    add("wrap", merge(wraps), (0.24, 0.67, 1.0), 0.0, WRAP, "Fabric")

    # cabeza de metal casi recta, casquillo donde entra el mango y tapa del pomo
    socket = box((0.98, 1.2, 1.05), (0, HEAD_Y - 0.1, 0))
    band = box((1.1, 0.16, 1.18), (0, HEAD_Y - 0.78, 0))
    cap = cylinder(0.3, 0.22, (0, -HANDLE_HALF - 0.3, 0), 12, "Y")
    add("head", merge([curved_head(), socket, band, cap]), (0.69, 0.74, 0.82), 0.06, STEEL, "Metal")

    # remaches dorados a los lados del casquillo
    rivets = [sphere(0.15, (-0.52, HEAD_Y - 0.1, 0.0), 8, 5), sphere(0.15, (0.52, HEAD_Y - 0.1, 0.0), 8, 5)]
    add("gem", merge(rivets), (1.0, 0.84, 0.35), 0.0, GEM, "Neon")

    export_asset("pickaxe", parts)


build()
print("PICO LISTO")
