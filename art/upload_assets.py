"""Sube a Roblox los FBX de art/_export (Open Cloud Assets API) y guarda sus Ids.

Uso (después de generar los modelos con Blender):
    python art/upload_assets.py            # sube lo que aún no tiene Id
    python art/upload_assets.py --force    # vuelve a subir todo

Necesita la variable de entorno ROBLOX_API_KEY (clave de Creator Hub con permiso de Assets,
lectura y escritura). La clave nunca se escribe en un archivo del proyecto.
También se puede fijar ROBLOX_USER_ID (por defecto el dueño del juego).

Resultado: art/_export/asset_ids.json  ->  { "crystal_node_rock.fbx": 123456789, ... }
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "_export")
IDS_FILE = os.path.join(EXPORT, "asset_ids.json")
USER_ID = os.environ.get("ROBLOX_USER_ID", "3282659647")
BASE = "https://apis.roblox.com/assets/v1"


def api_key():
    key = os.environ.get("ROBLOX_API_KEY", "").strip()
    if not key:
        sys.exit("Falta la variable de entorno ROBLOX_API_KEY (ver las instrucciones).")
    return key


def request(method, url, key, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    for name, value in (headers or {}).items():
        req.add_header(name, value)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.loads(response.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        sys.exit(f"Error {error.code} de Roblox: {detail}")


def multipart(fields, file_field, file_name, file_bytes, file_type):
    boundary = "----neoluna" + uuid.uuid4().hex
    lines = []
    for name, value in fields.items():
        lines.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n".encode())
    lines.append(
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"{file_field}\"; filename=\"{file_name}\"\r\n"
        f"Content-Type: {file_type}\r\n\r\n".encode()
    )
    lines.append(file_bytes)
    lines.append(f"\r\n--{boundary}--\r\n".encode())
    return b"".join(lines), f"multipart/form-data; boundary={boundary}"


def upload(key, path):
    name = os.path.basename(path)
    display = "NeoLuna_" + os.path.splitext(name)[0]
    meta = {
        "assetType": "Model",
        "displayName": display[:50],
        "description": "Pieza de arte de Moon Miner Tycoon (generada con Blender).",
        "creationContext": {"creator": {"userId": USER_ID}},
    }
    with open(path, "rb") as handle:
        body, content_type = multipart({"request": json.dumps(meta)}, "fileContent", name, handle.read(), "model/fbx")
    operation = request("POST", f"{BASE}/assets", key, body, {"Content-Type": content_type})
    operation_id = operation["path"].split("/")[-1]
    for _ in range(60):
        time.sleep(2)
        status = request("GET", f"{BASE}/operations/{operation_id}", key)
        if status.get("done"):
            if "response" in status:
                return int(status["response"]["assetId"])
            sys.exit(f"La subida de {name} falló: {json.dumps(status)}")
    sys.exit(f"La subida de {name} tardó demasiado.")


def main():
    key = api_key()
    force = "--force" in sys.argv
    ids = {}
    if os.path.exists(IDS_FILE):
        with open(IDS_FILE, encoding="utf-8") as handle:
            ids = json.load(handle)
    files = sorted(f for f in os.listdir(EXPORT) if f.lower().endswith(".fbx"))
    for name in files:
        if name in ids and not force:
            print(f"ya subido: {name} -> {ids[name]}")
            continue
        asset_id = upload(key, os.path.join(EXPORT, name))
        ids[name] = asset_id
        print(f"subido: {name} -> {asset_id}")
        with open(IDS_FILE, "w", encoding="utf-8") as handle:
            json.dump(ids, handle, indent=2)
    print(f"Listo: {len(ids)} modelos con Id en {IDS_FILE}")


if __name__ == "__main__":
    main()
