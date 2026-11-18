"""Naves y objetos para ambientar el cielo: transbordador, carguero, explorador, satélite,
estación espacial y asteroides. Se ven lejos y en lo alto (no estorban la vista).

Cada modelo se arma con varias partes (cuerpo, alas, cristal, motores...) cuyo nombre empieza con
el del modelo: shuttle_body, shuttle_wing... El juego las pinta con su tinte y las mueve.
Frente de las naves = +Y en Blender (-Z en Roblox).

Ejecutar:  blender --background --python art/blender/ambient.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: F401,F403,E402

WHITE = (235, 238, 246)
GRAY = (170, 176, 190)
DARK = (90, 94, 108)
ORANGE = (235, 130, 40)
BLUE = (60, 130, 220)
CYAN = (110, 220, 255)
GLASS = (30, 50, 80)
GOLD = (230, 190, 80)


def deg(a):
    return math.radians(a)


def prism(points, thickness, plane="XY", offset=0.0):
    """Polígono extruido. plane="XY": puntos (x, y), grosor en Z. plane="YZ": puntos (y, z), grosor en X."""
    bm = bmesh.new()
    front, back = [], []
    for u, v in points:
        if plane == "XY":
            front.append(bm.verts.new((u, v, offset + thickness / 2)))
            back.append(bm.verts.new((u, v, offset - thickness / 2)))
        else:
            front.append(bm.verts.new((offset + thickness / 2, u, v)))
            back.append(bm.verts.new((offset - thickness / 2, u, v)))
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(front)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))
    return bm


def mirror_x(bm):
    """Copia espejada en X (para alas izquierda/derecha)."""
    mesh = bpy.data.meshes.new("tmp")
    bm.to_mesh(mesh)
    copy = bmesh.new()
    copy.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)
    for v in copy.verts:
        v.co.x = -v.co.x
    bmesh.ops.reverse_faces(copy, faces=copy.faces)
    return copy


def both_sides(bm):
    left = mirror_x(bm)
    return merge([bm, left])


class Ship:
    def __init__(self, name):
        self.name = name
        self.parts = []

    def add(self, part, bm, preview, bevel_width, tint, material="SmoothPlastic", segments=2):
        self.parts.append(to_obj(f"{self.name}_{part}", bm, preview, bevel_width, segments, tint, material))


def shuttle():
    ship = Ship("shuttle")
    body = merge(
        [
            cylinder(1.45, 9.0, (0, 0, 0), 18, "Y"),
            cylinder(1.45, 4.5, (0, 6.7, 0), 18, "Y", radius_top=0.25),
            cylinder(1.5, 2.2, (0, -5.5, 0), 18, "Y", radius_top=1.0),
        ]
    )
    ship.add("body", body, (0.92, 0.93, 0.96), 0.08, WHITE)
    wing = both_sides(prism([(0.9, 3.4), (7.2, -4.6), (0.9, -4.6)], 0.35, "XY", -0.5))
    ship.add("wing", wing, (0.92, 0.5, 0.16), 0.06, ORANGE)
    fin = prism([(-4.4, 1.2), (-5.9, 4.6), (-5.9, 1.2)], 0.3, "YZ", 0.0)
    translate_bm(fin, (0, 0, 0.6))
    ship.add("fin", fin, (0.92, 0.5, 0.16), 0.05, ORANGE)
    canopy = sphere(1.0, (0, 4.0, 1.1), 10, 6, (0.9, 1.7, 0.6))
    ship.add("glass", canopy, (0.12, 0.2, 0.32), 0.0, GLASS, "Glass")
    engines = merge([cylinder(0.62, 1.4, (x, -6.9, 0.0), 12, "Y") for x in (-0.95, 0.0, 0.95)])
    ship.add("engine", engines, (0.43, 0.86, 1.0), 0.0, CYAN, "Neon")
    return ship


def freighter():
    ship = Ship("freighter")
    hull = merge(
        [
            box((6.2, 28.0, 5.4), (0, 0, 0)),
            cylinder(3.0, 6.5, (0, 17.0, 0), 14, "Y", radius_top=0.9),
        ]
    )
    ship.add("hull", hull, (0.66, 0.69, 0.75), 0.5, GRAY, "Metal", 3)
    ship.add("rear", box((7.0, 3.2, 6.0), (0, -15.2, 0)), (0.35, 0.37, 0.43), 0.3, DARK, "Metal")
    ship.add("bridge", box((3.6, 5.0, 3.0), (0, 9.0, 4.2)), (0.92, 0.93, 0.96), 0.25, WHITE)
    ship.add("glass", box((3.0, 0.3, 0.9), (0, 11.6, 4.6)), (0.12, 0.2, 0.32), 0.0, GLASS, "Glass")
    cargo_a, cargo_b = [], []
    for index in range(8):
        y = -10.5 + index * 3.3
        for side in (-1.5, 1.5):
            (cargo_a if index % 2 == 0 else cargo_b).append(box((2.7, 3.0, 2.5), (side, y, 3.95)))
    ship.add("cargo_a", merge(cargo_a), (0.92, 0.5, 0.16), 0.1, ORANGE)
    ship.add("cargo_b", merge(cargo_b), (0.24, 0.5, 0.86), 0.1, BLUE)
    engines = merge([cylinder(0.95, 1.6, (x, -17.4, 0.0), 12, "Y") for x in (-2.0, 0.0, 2.0)])
    ship.add("engine", engines, (0.43, 0.86, 1.0), 0.0, CYAN, "Neon")
    return ship


def scout():
    ship = Ship("scout")
    body = merge(
        [
            cylinder(0.85, 4.0, (0, 0, 0), 12, "Y"),
            cylinder(0.85, 3.4, (0, 3.7, 0), 12, "Y", radius_top=0.12),
        ]
    )
    ship.add("body", body, (0.92, 0.93, 0.96), 0.05, WHITE)
    wing = both_sides(prism([(0.7, 1.8), (4.6, -2.6), (0.7, -2.6)], 0.25, "XY", -0.1))
    ship.add("wing", wing, (0.24, 0.67, 1.0), 0.04, (60, 170, 255))
    ship.add("glass", sphere(0.6, (0, 1.3, 0.55), 8, 5, (0.9, 1.7, 0.7)), (0.12, 0.2, 0.32), 0.0, GLASS, "Glass")
    ship.add("engine", cylinder(0.55, 0.9, (0, -2.5, 0), 10, "Y"), (0.43, 0.86, 1.0), 0.0, CYAN, "Neon")
    return ship


def satellite():
    ship = Ship("satellite")
    ship.add("body", box((3.2, 3.2, 3.2), (0, 0, 0)), (0.9, 0.74, 0.31), 0.25, GOLD, "Metal")
    panels = merge([box((6.0, 0.18, 3.0), (-5.2, 0, 0)), box((6.0, 0.18, 3.0), (5.2, 0, 0))])
    ship.add("panels", panels, (0.24, 0.5, 0.86), 0.04, (40, 80, 170))
    arms = merge([box((1.4, 0.25, 0.25), (-2.2, 0, 0)), box((1.4, 0.25, 0.25), (2.2, 0, 0))])
    ship.add("arms", arms, (0.58, 0.6, 0.66), 0.0, (150, 154, 168), "Metal")
    dish = merge([cylinder(1.5, 0.35, (0, 2.6, 0.9), 16, "Y"), cylinder(0.12, 1.4, (0, 3.2, 0.9), 6, "Y")])
    ship.add("dish", dish, (0.92, 0.93, 0.96), 0.0, WHITE)
    return ship


def station():
    ship = Ship("station")
    ring = torus(24.0, 2.8, (0, 0, 0), 40, 8)
    ship.add("ring", ring, (0.92, 0.93, 0.96), 0.0, WHITE, "SmoothPlastic", 1)
    hub = merge([cylinder(5.5, 16.0, (0, 0, 0), 20, "Z"), sphere(5.0, (0, 0, 8.0), 14, 7, (1, 1, 0.7))])
    ship.add("hub", hub, (0.92, 0.93, 0.96), 0.3, WHITE, "SmoothPlastic", 2)
    spokes = []
    for az in (0, 90, 180, 270):
        spoke = box((22.0, 1.5, 1.5), (11.0, 0, 0))
        rotate_bm(spoke, (0, 0, az))
        spokes.append(spoke)
    ship.add("spokes", merge(spokes), (0.58, 0.6, 0.66), 0.1, (150, 154, 168), "Metal")
    fins = merge([box((14.0, 0.4, 6.0), (-12.0, 0, 10.5)), box((14.0, 0.4, 6.0), (12.0, 0, 10.5))])
    ship.add("solar", fins, (0.24, 0.5, 0.86), 0.05, (40, 80, 170))
    lights = []
    for i in range(16):
        a = deg(i * 360 / 16)
        lights.append(sphere(0.7, (math.cos(a) * 24.0, math.sin(a) * 24.0, 2.9), 6, 4))
    ship.add("lights", merge(lights), (0.43, 0.86, 1.0), 0.0, CYAN, "Neon")
    return ship


def asteroids():
    ship = Ship("asteroid")
    ship.add("a", blob((10, 8, 7), 31, 0.4), (0.5, 0.47, 0.45), 0.0, (110, 104, 100), "Slate")
    ship.add("b", blob((6, 5, 5), 32, 0.45), (0.45, 0.43, 0.46), 0.0, (100, 98, 108), "Slate")
    ship.add("c", blob((14, 11, 10), 33, 0.35), (0.55, 0.5, 0.45), 0.0, (125, 116, 106), "Slate")
    return ship


def build():
    reset_scene()
    ships = [shuttle(), freighter(), scout(), satellite(), station(), asteroids()]
    all_parts = []
    for ship in ships:
        all_parts.extend(ship.parts)
    export_asset("ambient", all_parts, preview=False)

    # vista previa: cada modelo en su lugar de una fila
    x = 0.0
    previews = []
    for ship in ships:
        xs = [obj.dimensions.x for obj, _, _ in ship.parts]
        width = max(xs) if xs else 10
        x += width / 2 + 6
        for obj, _, _ in ship.parts:
            obj.location = (obj.location.x + x, obj.location.y, obj.location.z)
        previews.extend(o for o, _, _ in ship.parts)
        x += width / 2 + 6
    render_preview("ambiente", previews, azimuth=0.3)


build()
print("AMBIENTE LISTO")
