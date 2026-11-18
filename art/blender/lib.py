"""Utilidades comunes para generar arte con Blender (se importa desde los otros scripts).

Ejes: en Blender el frente es +Y y arriba es +Z. Roblox: frente -Z, arriba +Y.
Conversión: (x, y, z)_blender -> (x, z, -y)_roblox. Todo en studs.
"""

import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Euler, Vector

OUT = r"D:\Programacion\NeoLuna\art\_export"
os.makedirs(os.path.join(OUT, "previews"), exist_ok=True)
MANIFEST_FILE = os.path.join(OUT, "manifest.json")


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ----------------------------------------------------------------------------------------
# Mallas básicas (devuelven bmesh)
# ----------------------------------------------------------------------------------------
def box(size, center=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = v.co.x * size[0] + center[0]
        v.co.y = v.co.y * size[1] + center[1]
        v.co.z = v.co.z * size[2] + center[2]
    return bm


def cylinder(radius, height, center=(0, 0, 0), segments=16, axis="Z", radius_top=None):
    """Cilindro (o cono truncado si radius_top es distinto) a lo largo de `axis`."""
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius if radius_top is None else radius_top,
        depth=height,
    )
    if axis == "X":
        rotate_bm(bm, (0, 90, 0))
    elif axis == "Y":
        rotate_bm(bm, (90, 0, 0))
    return translate_bm(bm, center)


def sphere(radius, center=(0, 0, 0), segments=10, rings=6, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    for v in bm.verts:
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z *= scale[2]
    return translate_bm(bm, center)


def torus(major, minor, center=(0, 0, 0), major_segments=18, minor_segments=6):
    """Anillo (dona) en el plano XY."""
    bm = bmesh.new()
    rings = []
    for i in range(major_segments):
        a = i * 2 * math.pi / major_segments
        ring = []
        for j in range(minor_segments):
            b = j * 2 * math.pi / minor_segments
            r = major + minor * math.cos(b)
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, minor * math.sin(b))))
        rings.append(ring)
    for i in range(major_segments):
        for j in range(minor_segments):
            i2, j2 = (i + 1) % major_segments, (j + 1) % minor_segments
            bm.faces.new((rings[i][j], rings[i2][j], rings[i2][j2], rings[i][j2]))
    return translate_bm(bm, center)


def crystal(radius, height, tip, taper=0.82, sides=6, twist=0.0, bottom_tip=0.0):
    """Cristal facetado: prisma que se afina y termina en punta (y opcionalmente punta abajo)."""
    bm = bmesh.new()
    bottom, top = [], []
    for i in range(sides):
        angle = twist + i * 2 * math.pi / sides
        bottom.append(bm.verts.new((math.cos(angle) * radius, math.sin(angle) * radius, 0)))
        top.append(bm.verts.new((math.cos(angle) * radius * taper, math.sin(angle) * radius * taper, height)))
    apex = bm.verts.new((0, 0, height + tip))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
        bm.faces.new((top[i], top[j], apex))
    if bottom_tip > 0:
        low = bm.verts.new((0, 0, -bottom_tip))
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((bottom[j], bottom[i], low))
    else:
        bm.faces.new(list(reversed(bottom)))
    return bm


def bipyramid(radius, up, down, sides=6, twist=0.0):
    """Gema de dos puntas (octaedro alargado)."""
    bm = bmesh.new()
    ring = [
        bm.verts.new((math.cos(twist + i * 2 * math.pi / sides) * radius, math.sin(twist + i * 2 * math.pi / sides) * radius, 0))
        for i in range(sides)
    ]
    top = bm.verts.new((0, 0, up))
    low = bm.verts.new((0, 0, -down))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((ring[i], ring[j], top))
        bm.faces.new((ring[j], ring[i], low))
    return bm


def blob(size, seed, bumps=0.22, subdivisions=2):
    """Roca de pocas caras (esfera irregular)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=0.5)
    rng = random.Random(seed)
    for v in bm.verts:
        push = 1.0 + rng.uniform(-bumps, bumps)
        v.co.x *= size[0] * push
        v.co.y *= size[1] * push
        v.co.z *= size[2] * push
    return bm


def arch(length, depth, height, segments=14):
    """Techo en arco (medio cilindro) a lo largo de X, apoyado en z=0."""
    bm = bmesh.new()
    left, right = [], []
    for i in range(segments + 1):
        a = math.pi * i / segments
        y = math.cos(a) * depth / 2
        z = math.sin(a) * height
        left.append(bm.verts.new((-length / 2, y, z)))
        right.append(bm.verts.new((length / 2, y, z)))
    for i in range(segments):
        bm.faces.new((left[i], left[i + 1], right[i + 1], right[i]))
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    bm.faces.new((left[0], right[0], right[-1], left[-1]))
    return bm


# ----------------------------------------------------------------------------------------
# Transformaciones
# ----------------------------------------------------------------------------------------
def rotate_bm(bm, degrees):
    matrix = Euler([math.radians(a) for a in degrees], "XYZ").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm


def translate_bm(bm, offset):
    bmesh.ops.translate(bm, vec=Vector(offset), verts=bm.verts)
    return bm


def scale_bm(bm, factor):
    for v in bm.verts:
        v.co.x *= factor[0]
        v.co.y *= factor[1]
        v.co.z *= factor[2]
    return bm


def merge(bm_list):
    result = bmesh.new()
    for bm in bm_list:
        mesh = bpy.data.meshes.new("tmp")
        bm.to_mesh(mesh)
        bm.free()
        result.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    return result


# ----------------------------------------------------------------------------------------
# Objetos, biselado y exportación
# ----------------------------------------------------------------------------------------
def make_object(name, bm, preview_color):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    material = bpy.data.materials.new(name + "_preview")
    material.diffuse_color = (preview_color[0], preview_color[1], preview_color[2], 1.0)
    obj.data.materials.append(material)
    return obj


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def bevel(obj, width, segments=2, angle=25):
    if width <= 0:
        return obj
    select_only(obj)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(angle)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def to_obj(name, bm, preview_color, bevel_width=0.0, bevel_segments=2, tint=(255, 255, 255), material="SmoothPlastic"):
    obj = make_object(name, bm, preview_color)
    bevel(obj, bevel_width, bevel_segments)
    return obj, tint, material


def export_asset(asset_name, parts, preview=True):
    """parts: lista de (objeto, tinte (r,g,b 0-255), material de Roblox)."""
    info = {}
    for obj, tint, material in parts:
        select_only(obj)
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        center = obj.location.copy()
        dims = obj.dimensions.copy()
        file_name = f"{asset_name}_{obj.name}.fbx"
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
    manifest[asset_name] = info
    with open(MANIFEST_FILE, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
    if preview:
        render_preview(asset_name, [p[0] for p in parts])


def render_preview(asset_name, objects, azimuth=1.0):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    world = bpy.data.worlds.new("w")
    world.color = (0.09, 0.08, 0.16)
    scene.world = world

    bpy.context.view_layer.update()  # las ubicaciones cambiaron: actualizar matrices
    points = []
    for obj in objects:
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    center = (low + high) / 2
    radius = (high - low).length * 1.2

    camera_data = bpy.data.cameras.new("cam")
    camera_data.lens = 45
    camera = bpy.data.objects.new("cam", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = center + Vector((radius * 0.7 * azimuth, radius * 0.95, radius * 0.5))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera

    scene.render.filepath = os.path.join(OUT, "previews", f"{asset_name}.png")
    bpy.ops.render.render(write_still=True)
