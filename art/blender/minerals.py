"""Los 25 minerales del juego: cada uno con su diseño propio.

Cada mineral es UNA malla con su base apoyada en z = 0 (centrada en x, y). El juego la pinta con el
color del mineral y la usa en la mina (sobre la roca), en la mano, en la espalda y en los estantes.

Ejecutar:  blender --background --python art/blender/minerals.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: F401,F403,E402


def deg(a):
    return math.radians(a)


def place(bm, rot=(0, 0, 0), pos=(0, 0, 0)):
    if any(rot):
        rotate_bm(bm, rot)
    return translate_bm(bm, pos)


def radial(count, radius, make, start=0.0):
    """Reparte `count` mallas alrededor del eje Z. make(i, angle_deg) devuelve una malla en el origen."""
    items = []
    for i in range(count):
        angle = start + i * 360.0 / count
        bm = make(i, angle)
        translate_bm(bm, (math.cos(deg(angle)) * radius, math.sin(deg(angle)) * radius, 0))
        items.append(bm)
    return items


def star_prism(outer, inner, thickness, points=5):
    """Estrella extruida, de pie (en el plano XZ), con una punta hacia arriba."""
    bm = bmesh.new()
    front, back = [], []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = deg(90) + i * math.pi / points
        x, z = math.cos(a) * r, math.sin(a) * r
        front.append(bm.verts.new((x, thickness / 2, z)))
        back.append(bm.verts.new((x, -thickness / 2, z)))
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(front)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))
    return bm


def mushroom(cap_radius, stalk_height, stalk_radius, pos):
    stalk = cylinder(stalk_radius, stalk_height, (0, 0, stalk_height / 2), 8, radius_top=stalk_radius * 0.75)
    cap = sphere(cap_radius, (0, 0, stalk_height + cap_radius * 0.2), 10, 6, (1, 1, 0.6))
    return translate_bm(merge([stalk, cap]), pos)


# ----------------------------------------------------------------------------------------
# Diseños: devuelven (malla, material de Roblox, bisel)
# ----------------------------------------------------------------------------------------
def d_LunarRock():
    rock = blob((4.2, 3.8, 3.4), 5, bumps=0.3, subdivisions=2)
    translate_bm(rock, (0, 0, 1.6))
    pebbles = [blob((1.3, 1.2, 1.0), 8, 0.3, 1), blob((0.9, 0.9, 0.7), 9, 0.3, 1)]
    translate_bm(pebbles[0], (2.5, 0.6, 0.5))
    translate_bm(pebbles[1], (-2.3, -0.9, 0.35))
    return merge([rock] + pebbles), "Slate", 0.04


def d_Iron():
    bars = []
    for z, w, rot in ((0.5, 3.8, 0), (1.5, 3.4, 12), (2.5, 3.0, -8)):
        bar = box((w, 1.9, 0.95), (0, 0, 0))
        place(bar, (0, 0, rot), (0, 0, z))
        bars.append(bar)
    rivet = cylinder(0.3, 0.4, (0, 0, 3.15), 8)
    return merge(bars + [rivet]), "Metal", 0.12


def d_Copper():
    nuggets = [
        sphere(1.35, (0, 0, 1.3), 9, 6, (1.1, 0.9, 0.9)),
        sphere(1.0, (1.5, 0.7, 0.9), 8, 5),
        sphere(0.9, (-1.3, -0.6, 0.8), 8, 5),
        sphere(0.7, (0.2, -1.5, 0.6), 7, 5),
        sphere(0.6, (0.5, 0.3, 2.5), 7, 5),
    ]
    return merge(nuggets), "Metal", 0.0


def d_Aluminium():
    ingot = box((3.2, 2.0, 1.5), (0, 0, 0.75))
    can = cylinder(0.85, 2.4, (1.4, 0.4, 1.2), 14)
    top = cylinder(0.65, 0.3, (1.4, 0.4, 2.5), 14)
    sheet = box((2.6, 0.18, 3.4), (-0.8, -1.4, 1.7))
    place(sheet, (0, 0, 18))
    return merge([ingot, can, top, sheet]), "Metal", 0.1


def d_LunarQuartz():
    points = []
    for radius, height, tilt, az in ((0.7, 3.8, 0, 0), (0.55, 3.0, 12, 70), (0.55, 2.6, 16, 150), (0.5, 3.3, 14, 230), (0.45, 2.2, 20, 300), (0.4, 1.6, 26, 20)):
        c = crystal(radius, height, 1.0, 0.8, 6, deg(az))
        place(c, (tilt, 0, az), (math.cos(deg(az)) * 0.4, math.sin(deg(az)) * 0.4, 0.1))
        points.append(c)
    return merge(points), "Glass", 0.05


def d_IceCrystal():
    blades = []
    for width, height, tilt, az in ((1.9, 5.0, 8, 0), (1.5, 3.6, 24, 120), (1.4, 3.2, 26, 240), (0.9, 2.2, 38, 60)):
        blade = crystal(width / 2, height * 0.6, height * 0.4, 0.55, 4, deg(45))
        scale_bm(blade, (1.0, 0.45, 1.0))
        place(blade, (tilt, 0, az), (math.cos(deg(az)) * 0.5, math.sin(deg(az)) * 0.5, 0.0))
        blades.append(blade)
    return merge(blades), "Glass", 0.05


def d_MoonSapphire():
    crown = bipyramid(1.9, 1.0, 0.0001, sides=8, twist=deg(22))
    place(crown, (0, 0, 0), (0, 0, 2.4))
    pavilion = bipyramid(1.9, 0.0001, 1.8, sides=8, twist=deg(22))
    place(pavilion, (0, 0, 0), (0, 0, 2.4))
    table = cylinder(1.05, 0.25, (0, 0, 3.5), 8)
    pedestal = cylinder(1.5, 0.5, (0, 0, 0.25), 12, radius_top=1.1)
    return merge([crown, pavilion, table, pedestal]), "Glass", 0.04


def d_SpaceAmber():
    drop = sphere(1.6, (0, 0, 2.0), 12, 8, (1, 1, 1.2))
    tip = cylinder(1.0, 1.8, (0, 0, 4.2), 12, radius_top=0.0)
    base = cylinder(1.9, 0.45, (0, 0, 0.22), 14)
    bubbles = [sphere(0.28, (0.6, 0.5, 1.8), 6, 4), sphere(0.2, (-0.5, 0.3, 2.6), 6, 4), sphere(0.16, (0.1, -0.7, 3.1), 6, 4)]
    return merge([drop, tip, base] + bubbles), "Glass", 0.03


def d_Uranium():
    spines = []
    for radius, height, tip, az, tilt in ((0.45, 3.6, 1.0, 0, 0), (0.38, 3.0, 0.8, 72, 16), (0.35, 2.6, 0.8, 144, 20), (0.4, 3.2, 0.9, 216, 14), (0.32, 2.2, 0.7, 288, 24)):
        s = crystal(radius, height, tip, 0.4, 4, deg(az))
        place(s, (tilt, 0, az), (math.cos(deg(az)) * 0.55, math.sin(deg(az)) * 0.55, 0.2))
        spines.append(s)
    ring = torus(1.9, 0.17, (0, 0, 0), 20, 6)
    place(ring, (14, 8, 0), (0, 0, 1.5))
    return merge(spines + [ring]), "Glass", 0.04


def d_RadioCrystal():
    core = crystal(1.2, 3.6, 1.6, 0.8, 6, deg(15))
    place(core, (0, 0, 0), (0, 0, 0.4))
    ring = torus(2.3, 0.2, (0, 0, 0), 22, 6)
    place(ring, (0, 0, 0), (0, 0, 2.2))
    shards = radial(3, 1.9, lambda i, a: crystal(0.28, 1.2, 0.5, 0.5, 4), 30)
    for s in shards:
        translate_bm(s, (0, 0, 0.3))
    return merge([core, ring] + shards), "Glass", 0.05


def d_Thorium():
    plates = []
    for i in range(5):
        plate = cylinder(1.5 - i * 0.12, 0.62, (0, 0, 0), 6)
        place(plate, (0, 0, i * 22), (0, 0, 0.45 + i * 0.7))
        plates.append(plate)
    cap = crystal(0.8, 0.5, 1.0, 0.6, 6)
    translate_bm(cap, (0, 0, 3.8))
    return merge(plates + [cap]), "Metal", 0.06


def d_BlueIsotope():
    core = sphere(0.9, (0, 0, 2.9), 12, 8)
    rings = []
    for rot in ((0, 0, 0), (60, 0, 0), (-60, 0, 0)):
        r = torus(2.0, 0.11, (0, 0, 0), 24, 6)
        place(r, rot, (0, 0, 2.9))
        rings.append(r)
    electrons = [sphere(0.3, (2.0, 0, 2.9), 8, 5), sphere(0.3, (-1.0, 1.73, 2.9 + 0.0), 8, 5), sphere(0.3, (-1.0, -1.0, 2.9 + 1.7), 8, 5)]
    stand = cylinder(0.9, 0.5, (0, 0, 0.25), 12)
    post = cylinder(0.25, 1.8, (0, 0, 1.2), 8)
    return merge([core, stand, post] + rings + electrons), "Glass", 0.0


def d_Meteorite():
    rock = blob((3.6, 3.2, 2.8), 21, bumps=0.35)
    translate_bm(rock, (0, 0, 1.5))
    shards = []
    for x, y, z, s in ((1.6, 1.0, 3.6, 0.5), (-1.7, 0.4, 3.9, 0.4)):
        shard = blob((s * 2, s * 2, s * 2), 3, 0.3, 1)
        translate_bm(shard, (x, y, z))
        shards.append(shard)
    trail = cylinder(1.1, 3.4, (0, 0, 0), 8, radius_top=0.0)
    place(trail, (0, 50, 0), (-2.6, 0.0, 4.2))
    return merge([rock, trail] + shards), "Slate", 0.04


def d_AlienCrystal():
    gem = bipyramid(1.35, 2.3, 1.9, sides=8, twist=deg(22))
    translate_bm(gem, (0, 0, 4.3))
    stem = cylinder(0.38, 1.4, (0, 0, 1.6), 8, radius_top=0.14)
    ring_a = torus(2.2, 0.13, (0, 0, 0), 22, 6)
    place(ring_a, (62, 0, 0), (0, 0, 4.3))
    ring_b = torus(2.7, 0.1, (0, 0, 0), 24, 6)
    place(ring_b, (-35, 28, 0), (0, 0, 4.3))
    sats = []
    for az in (10, 130, 250):
        s = bipyramid(0.34, 0.8, 0.5, sides=4)
        translate_bm(s, (math.cos(deg(az)) * 2.4, math.sin(deg(az)) * 2.4, 4.3))
        sats.append(s)
    base = cylinder(1.3, 0.5, (0, 0, 0.25), 12)
    return merge([gem, stem, ring_a, ring_b, base] + sats), "Glass", 0.04


def d_CometShard():
    shard = crystal(1.0, 3.2, 1.6, 0.7, 5, deg(10))
    place(shard, (0, 0, 0), (0, 0, 0.0))
    tail = cylinder(1.0, 4.6, (0, 0, 0), 8, radius_top=0.0)
    place(tail, (0, 68, 0), (-2.4, 0, 3.3))
    sparks = []
    for x, z, r in ((-3.4, 1.8, 0.28), (-4.3, 3.4, 0.22), (-2.2, 5.2, 0.2), (-5.1, 2.2, 0.16)):
        sparks.append(sphere(r, (x, 0.4, z), 6, 4))
    base = cylinder(1.4, 0.5, (0, 0, 0.25), 10)
    return merge([shard, tail, base] + sparks), "Glass", 0.04


def d_AlienOrb():
    orb = sphere(1.7, (0, 0, 3.0), 14, 9)
    ring = torus(2.4, 0.15, (0, 0, 0), 24, 6)
    place(ring, (20, 0, 0), (0, 0, 3.0))
    antennae = []
    for az, el in ((0, 40), (72, 55), (144, 40), (216, 55), (288, 40)):
        s = cylinder(0.1, 1.5, (0, 0, 0.75), 6)
        tipball = sphere(0.3, (0, 0, 1.55), 6, 4)
        stalk = merge([s, tipball])
        place(stalk, (0, 90 - el, az), (math.cos(deg(az)) * 1.1, math.sin(deg(az)) * 1.1, 3.0 + math.sin(deg(el)) * 1.2))
        antennae.append(stalk)
    base = cylinder(1.3, 0.8, (0, 0, 0.4), 12, radius_top=0.7)
    return merge([orb, ring, base] + antennae), "Glass", 0.0


def d_MutantSpores():
    return merge([mushroom(1.35, 2.0, 0.4, (0, 0, 0)), mushroom(1.0, 1.4, 0.32, (1.9, 0.8, 0)), mushroom(0.8, 1.0, 0.28, (-1.7, -0.9, 0)), mushroom(0.6, 0.7, 0.22, (0.4, -1.9, 0))]), "SmoothPlastic", 0.0


def d_MutantCore():
    pods = [
        sphere(1.5, (0, 0, 3.1), 10, 7, (1.0, 1.0, 1.15)),
        sphere(1.0, (1.3, 0.5, 2.0), 8, 6),
        sphere(1.1, (-1.1, -0.6, 2.1), 8, 6),
        sphere(0.8, (0.4, -1.3, 1.7), 8, 5),
    ]
    spikes = []
    for az, el in ((0, 35), (60, 55), (120, 30), (190, 50), (250, 35), (310, 55)):
        sp = cylinder(0.28, 1.4, (0, 0, 0.7), 6, radius_top=0.0)
        place(sp, (0, 90 - el, az), (math.cos(deg(az)) * 1.3, math.sin(deg(az)) * 1.3, 3.1 + math.sin(deg(el)) * 0.9))
        spikes.append(sp)
    return merge(pods + spikes), "SmoothPlastic", 0.0


def d_MutantMold():
    blobs = [
        sphere(2.0, (0, 0, 1.0), 10, 6, (1.1, 1.1, 0.55)),
        sphere(1.5, (0.2, 0.1, 2.2), 10, 6, (1, 1, 0.6)),
        sphere(1.0, (-0.1, 0, 3.2), 9, 5, (1, 1, 0.65)),
    ]
    drips = []
    for az in (20, 110, 200, 290):
        d = cylinder(0.3, 1.4, (0, 0, 0.7), 6, radius_top=0.08)
        translate_bm(d, (math.cos(deg(az)) * 1.9, math.sin(deg(az)) * 1.9, 0.0))
        drips.append(d)
    eyes = [sphere(0.28, (0.7, 0.8, 3.4), 6, 4), sphere(0.2, (-0.5, 0.9, 3.5), 6, 4)]
    return merge(blobs + drips + eyes), "SmoothPlastic", 0.0


def d_ChimeraGem():
    heads = [
        bipyramid(1.3, 3.8, 0.0001, 6, deg(30)),
        bipyramid(1.0, 2.8, 0.0001, 6, deg(0)),
        bipyramid(0.9, 2.4, 0.0001, 6, deg(15)),
    ]
    place(heads[0], (0, 0, 0), (0, 0, 1.2))
    place(heads[1], (0, 24, 0), (1.5, 0, 0.8))
    place(heads[2], (0, -26, 0), (-1.4, 0.4, 0.7))
    horns = []
    for az in (60, 180, 300):
        h = cylinder(0.25, 1.4, (0, 0, 0.7), 6, radius_top=0.0)
        place(h, (0, 70, az), (math.cos(deg(az)) * 1.6, math.sin(deg(az)) * 1.6, 0.3))
        horns.append(h)
    return merge(heads + horns), "Glass", 0.04


def d_MoonHeart():
    lobes = [sphere(1.1, (-0.8, 0, 3.4), 12, 8), sphere(1.1, (0.8, 0, 3.4), 12, 8)]
    point = cylinder(1.9, 2.8, (0, 0, 2.0), 12, radius_top=0.0)
    place(point, (180, 0, 0), (0, 0, 3.8))
    heart = merge(lobes + [point])
    place(heart, (0, 0, 0), (0, 0, 0.3))
    crescent = torus(2.5, 0.18, (0, 0, 0), 26, 6)
    place(crescent, (90, 0, 0), (0, -0.9, 3.4))
    stars = [bipyramid(0.28, 0.65, 0.4, 4), bipyramid(0.22, 0.5, 0.3, 4)]
    translate_bm(stars[0], (2.4, 0, 5.0))
    translate_bm(stars[1], (-2.3, 0, 1.6))
    return merge([heart, crescent] + stars), "Glass", 0.04


def d_UfoPiece():
    disc = cylinder(2.5, 0.7, (0, 0, 1.2), 20, radius_top=2.2)
    dome = sphere(1.3, (0, 0, 1.55), 14, 8, (1, 1, 0.9))
    rim = torus(2.35, 0.2, (0, 0, 1.2), 22, 6)
    under = cylinder(1.4, 0.6, (0, 0, 0.7), 14, radius_top=0.8)
    lights = []
    for az in range(0, 360, 60):
        lights.append(sphere(0.2, (math.cos(deg(az)) * 2.15, math.sin(deg(az)) * 2.15, 1.45), 6, 4))
    ufo = merge([disc, dome, rim, under] + lights)
    place(ufo, (14, 0, 0), (0, 0, 0.6))
    return ufo, "Metal", 0.04


def d_FallenStar():
    star = star_prism(2.3, 1.0, 0.9, 5)
    place(star, (0, 0, 0), (0, 0, 2.7))
    tail = cylinder(1.0, 4.0, (0, 0, 0), 6, radius_top=0.0)
    place(tail, (0, 80, 0), (-3.0, 0, 3.6))
    sparks = [bipyramid(0.22, 0.55, 0.3, 4), bipyramid(0.18, 0.45, 0.25, 4), bipyramid(0.2, 0.5, 0.28, 4)]
    translate_bm(sparks[0], (-2.2, 0.2, 5.2))
    translate_bm(sparks[1], (-4.2, -0.2, 2.2))
    translate_bm(sparks[2], (1.4, 0.2, 5.4))
    base = cylinder(1.3, 0.5, (0, 0, 0.25), 10)
    return merge([star, tail, base] + sparks), "Glass", 0.05


def d_BlackHoleCore():
    core = sphere(1.3, (0, 0, 3.0), 14, 9)
    disc = torus(2.7, 0.45, (0, 0, 0), 28, 8)
    place(disc, (18, 0, 0), (0, 0, 3.0))
    outer = torus(3.5, 0.12, (0, 0, 0), 32, 6)
    place(outer, (18, 0, 0), (0, 0, 3.0))
    jets = []
    for sign in (1, -1):
        j = cylinder(0.5, 2.0, (0, 0, 0), 8, radius_top=0.0)
        place(j, (180 if sign < 0 else 0, 0, 0), (0, 0, 3.0 + sign * 2.2))
        jets.append(j)
    base = cylinder(1.2, 0.5, (0, 0, 0.25), 12)
    post = cylinder(0.3, 1.6, (0, 0, 1.1), 8)
    return merge([core, disc, outer, base, post] + jets), "SmoothPlastic", 0.0


def d_OriginCrystal():
    center = crystal(1.2, 5.0, 1.8, 0.8, 6, deg(15))
    translate_bm(center, (0, 0, 0.5))
    ring_crystals = radial(6, 2.2, lambda i, a: crystal(0.5, 1.8 + (i % 2) * 0.8, 0.8, 0.8, 6), 0)
    for i, c in enumerate(ring_crystals):
        place(c, (14, 0, 0), (0, 0, 0.3))
    base = cylinder(3.0, 0.5, (0, 0, 0.25), 18, radius_top=2.6)
    halo = torus(3.1, 0.15, (0, 0, 0), 28, 6)
    place(halo, (0, 0, 0), (0, 0, 4.5))
    orbs = [bipyramid(0.3, 0.7, 0.4, 4) for _ in range(4)]
    for i, o in enumerate(orbs):
        a = deg(45 + i * 90)
        translate_bm(o, (math.cos(a) * 3.1, math.sin(a) * 3.1, 4.5))
    return merge([center, base, halo] + ring_crystals + orbs), "Glass", 0.04


DESIGNS = [
    ("LunarRock", d_LunarRock, (0.59, 0.59, 0.62)),
    ("Iron", d_Iron, (0.45, 0.51, 0.61)),
    ("Copper", d_Copper, (0.8, 0.49, 0.27)),
    ("Aluminium", d_Aluminium, (0.8, 0.83, 0.88)),
    ("LunarQuartz", d_LunarQuartz, (0.91, 0.89, 1.0)),
    ("IceCrystal", d_IceCrystal, (0.55, 0.87, 1.0)),
    ("MoonSapphire", d_MoonSapphire, (0.27, 0.43, 0.92)),
    ("SpaceAmber", d_SpaceAmber, (1.0, 0.69, 0.2)),
    ("Uranium", d_Uranium, (0.43, 0.9, 0.31)),
    ("RadioCrystal", d_RadioCrystal, (0.76, 1.0, 0.24)),
    ("Thorium", d_Thorium, (0.84, 0.8, 0.49)),
    ("BlueIsotope", d_BlueIsotope, (0.24, 0.55, 1.0)),
    ("Meteorite", d_Meteorite, (0.63, 0.37, 0.24)),
    ("AlienCrystal", d_AlienCrystal, (0.73, 0.37, 1.0)),
    ("CometShard", d_CometShard, (0.59, 0.91, 1.0)),
    ("AlienOrb", d_AlienOrb, (0.43, 1.0, 0.8)),
    ("MutantSpores", d_MutantSpores, (0.67, 0.86, 0.35)),
    ("MutantCore", d_MutantCore, (1.0, 0.29, 0.49)),
    ("MutantMold", d_MutantMold, (0.41, 0.65, 0.25)),
    ("ChimeraGem", d_ChimeraGem, (1.0, 0.49, 0.86)),
    ("MoonHeart", d_MoonHeart, (1.0, 0.92, 0.65)),
    ("UfoPiece", d_UfoPiece, (0.67, 1.0, 0.8)),
    ("FallenStar", d_FallenStar, (1.0, 0.86, 0.24)),
    ("BlackHoleCore", d_BlackHoleCore, (0.49, 0.29, 0.76)),
    ("OriginCrystal", d_OriginCrystal, (1.0, 0.59, 1.0)),
]


def build():
    reset_scene()
    parts = []
    for mineral_id, design, preview in DESIGNS:
        bm, material, bevel_width = design()
        # la base descansa en z = 0
        low = min(v.co.z for v in bm.verts)
        translate_bm(bm, (0, 0, -low))
        obj = make_object(mineral_id, bm, preview)
        bevel(obj, bevel_width, 2)
        parts.append((obj, (200, 200, 210), material))

    # exportar y luego colocar en cuadrícula para la vista previa
    info_parts = list(parts)
    export_asset_no_preview(info_parts)

    columns = 5
    spacing = 9.0
    for index, (obj, _, _) in enumerate(info_parts):
        row, col = divmod(index, columns)
        obj.location = (col * spacing, -row * spacing, obj.location.z)
    render_preview("minerales", [p[0] for p in info_parts], azimuth=0.2)


def export_asset_no_preview(parts):
    """Como export_asset pero sin renderizar (la vista previa es una cuadrícula)."""
    import json

    info = {}
    for obj, tint, material in parts:
        select_only(obj)
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        center = obj.location.copy()
        dims = obj.dimensions.copy()
        file_name = f"minerals_{obj.name}.fbx"
        obj.location = (0, 0, 0)
        select_only(obj)
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(OUT, file_name),
            use_selection=True,
            axis_forward="-Z",
            axis_up="Y",
            apply_unit_scale=True,
            apply_scale_options="FBX_SCALE_UNITS",
            bake_anim=False,
            add_leaf_bones=False,
            mesh_smooth_type="FACE",
        )
        obj.location = center
        info[obj.name] = {
            "file": file_name,
            "center": [round(center.x, 4), round(center.z, 4), round(-center.y, 4)],
            "size": [round(dims.x, 4), round(dims.z, 4), round(dims.y, 4)],
            "tint": list(tint),
            "material": material,
            "triangles": sum(len(p.vertices) - 2 for p in obj.data.polygons),
        }
    manifest = {}
    if os.path.exists(MANIFEST_FILE):
        with open(MANIFEST_FILE, encoding="utf-8") as handle:
            manifest = json.load(handle)
    manifest["minerals"] = info
    with open(MANIFEST_FILE, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)


build()
print("MINERALES LISTOS")
