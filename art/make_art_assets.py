"""Genera src/shared/ArtAssets.luau a partir del manifiesto de Blender y los Ids subidos.

Uso:  python art/make_art_assets.py
Cada pieza trae su Id de Roblox, su centro y tamaño (studs), su tinte y su material.
El juego usa estas piezas si cargan; si no, usa los modelos hechos con código.
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "_export")
OUT = os.path.join(HERE, "..", "src", "shared", "ArtAssets.luau")

with open(os.path.join(EXPORT, "manifest.json"), encoding="utf-8") as handle:
    manifest = json.load(handle)
with open(os.path.join(EXPORT, "asset_ids.json"), encoding="utf-8") as handle:
    ids = json.load(handle)

lines = [
    "-- GENERADO por art/make_art_assets.py. No editar a mano: se vuelve a crear con Blender.",
    "-- Cada pieza: Id (modelo subido a Roblox), Center y Size (studs), Tint (color) y Material.",
    "",
    "return {",
]
for asset, parts in manifest.items():
    lines.append(f"\t{asset} = {{")
    for part, info in parts.items():
        asset_id = ids.get(info["file"])
        if not asset_id:
            continue
        cx, cy, cz = info["center"]
        sx, sy, sz = info["size"]
        r, g, b = info["tint"]
        lines.append(
            f"\t\t{part} = {{ Id = {asset_id}, Center = Vector3.new({cx}, {cy}, {cz}), "
            f"Size = Vector3.new({sx}, {sy}, {sz}), Tint = Color3.fromRGB({r}, {g}, {b}), "
            f"Material = \"{info['material']}\" }},"
        )
    lines.append("\t},")
lines.append("}")
lines.append("")

with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
    handle.write("\n".join(lines))
print("Escrito", os.path.normpath(OUT))
