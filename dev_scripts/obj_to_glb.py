# -*- coding: utf-8 -*-
"""OBJ з окремими PBR-текстурами (генератор гравця) -> GLB.

Беремо texture_diffuse, texture_normal, texture_roughness і texture_metallic
(останні дві зливаються в одну карту glTF: G — шорсткість, B — метал).
Текстури зменшуються до max_size. Багатокутники розбиваються віялом на
трикутники; V у UV перевертаємо (в OBJ початок знизу, у glTF — згори).
Порядок вершин у OBJ — проти годинникової, як і в glTF.

  python obj_to_glb.py <тека з base.obj і текстурами> <результат.glb> <розмір текстур>"""
import io
import json
import os
import struct
import sys
import numpy as np
from PIL import Image


def main(folder, dst, max_size):
    pos, uvs, nors = [], [], []
    keys, index = {}, []
    out_pos, out_uv, out_nor = [], [], []
    for line in open(os.path.join(folder, "base.obj"), encoding="utf-8", errors="ignore"):
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "v":
            pos.append([float(x) for x in parts[1:4]])
        elif parts[0] == "vt":
            uvs.append([float(parts[1]), 1.0 - float(parts[2])])
        elif parts[0] == "vn":
            nors.append([float(x) for x in parts[1:4]])
        elif parts[0] == "f":
            corners = []
            for token in parts[1:]:
                bits = (token.split("/") + ["", ""])[:3]
                key = (int(bits[0]) - 1, int(bits[1]) - 1 if bits[1] else -1, int(bits[2]) - 1 if bits[2] else -1)
                if key not in keys:
                    keys[key] = len(out_pos)
                    out_pos.append(pos[key[0]])
                    out_uv.append(uvs[key[1]] if key[1] >= 0 else [0.0, 0.0])
                    out_nor.append(nors[key[2]] if key[2] >= 0 else [0.0, 1.0, 0.0])
                corners.append(keys[key])
            for i in range(1, len(corners) - 1):
                index += [corners[0], corners[i], corners[i + 1]]
    p = np.array(out_pos, np.float32)
    n = np.array(out_nor, np.float32)
    n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
    t = np.array(out_uv, np.float32)
    idx = np.array(index, np.uint32)

    blob = bytearray()
    views = []

    def add(payload, target=None):
        while len(blob) % 4:
            blob.append(0)
        view = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(payload)}
        if target:
            view["target"] = target
        blob.extend(payload)
        views.append(view)
        return len(views) - 1

    def texture(img, fmt):
        if max(img.size) > max_size:
            img = img.resize((max_size, max_size), Image.LANCZOS)
        out = io.BytesIO()
        if fmt == "PNG":
            img.save(out, "PNG", optimize=True)
            return {"bufferView": add(out.getvalue()), "mimeType": "image/png"}
        img.convert("RGB").save(out, "JPEG", quality=90, optimize=True)
        return {"bufferView": add(out.getvalue()), "mimeType": "image/jpeg"}

    accessors = [
        {"bufferView": add(p.tobytes(), 34962), "componentType": 5126, "count": len(p), "type": "VEC3",
         "min": p.min(0).tolist(), "max": p.max(0).tolist()},
        {"bufferView": add(n.tobytes(), 34962), "componentType": 5126, "count": len(n), "type": "VEC3"},
        {"bufferView": add(t.tobytes(), 34962), "componentType": 5126, "count": len(t), "type": "VEC2"},
        {"bufferView": add(idx.tobytes(), 34963), "componentType": 5125, "count": len(idx), "type": "SCALAR"},
    ]
    diffuse = Image.open(os.path.join(folder, "texture_diffuse.png")).convert("RGB")
    normal = Image.open(os.path.join(folder, "texture_normal.png")).convert("RGB")
    rough = Image.open(os.path.join(folder, "texture_roughness.png")).convert("L")
    metal = Image.open(os.path.join(folder, "texture_metallic.png")).convert("L").resize(rough.size)
    orm = Image.merge("RGB", (Image.new("L", rough.size, 255), rough, metal))
    images = [texture(diffuse, "JPEG"), texture(normal, "PNG"), texture(orm, "JPEG")]
    for image, label in zip(images, ["texture_diffuse", "texture_normal", "texture_orm"]):
        image["name"] = label
    name = os.path.splitext(os.path.basename(dst))[0]
    gltf = {
        "asset": {"version": "2.0", "generator": "RuneHorde obj_to_glb.py"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                                                  "indices": 3, "material": 0}]}],
        "materials": [{"name": "M_" + name, "doubleSided": True,
                       "pbrMetallicRoughness": {"baseColorTexture": {"index": 0},
                                                "metallicRoughnessTexture": {"index": 2}},
                       "normalTexture": {"index": 1}}],
        "textures": [{"source": 0}, {"source": 1}, {"source": 2}],
        "images": images,
        "accessors": accessors, "bufferViews": views, "buffers": [{"byteLength": len(blob)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(blob) % 4:
        blob.append(0)
    out = (struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob))
           + struct.pack("<I4s", len(js), b"JSON") + js
           + struct.pack("<I4s", len(blob), b"BIN\x00") + bytes(blob))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, "wb").write(out)
    print("OK %s: %d трикутників, %d вершин, %dKB" % (dst, len(idx) // 3, len(p), len(out) // 1024))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]))
