# -*- coding: utf-8 -*-
"""Модель гравця (одна сітка, один матеріал) -> легка версія під телефон.

Геометрія — з lod.bin, який пише tools/simplify_mesh.gd у test_env
(спрощення вбудованим у Godot meshoptimizer); Godot зберігає грані за
годинниковою стрілкою, glTF — проти, тож порядок вершин розвертаємо.
Масштаб (scale) множиться прямо в координати. Текстури зменшуються до
max_size; JPEG лишається JPEG, PNG — PNG. Матеріал — як у джерелі.

  python optimize_model.py <джерело.glb> <lod.bin> <результат.glb> <масштаб> <розмір текстур> [світіння.png]

Карта світіння окремим файлом (як texture_emissive.png у генератора) —
вшивається в матеріал; двобічність тоді ж вимикається (модель замкнена)."""
import io
import json
import os
import struct
import sys
import numpy as np
from PIL import Image


def main(src, lod_bin, dst, scale, max_size, emissive=None):
    data = open(src, "rb").read()
    clen = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20:20 + clen])
    binstart = 20 + clen + 8
    old_bin = data[binstart:]
    blob = bytearray()
    views = []

    def add(payload, extra=None):
        while len(blob) % 4:
            blob.append(0)
        view = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(payload)}
        if extra:
            view.update(extra)
        blob.extend(payload)
        views.append(view)
        return len(views) - 1

    raw = open(lod_bin, "rb").read()
    vcount, icount = struct.unpack("<II", raw[:8])
    off = 8
    pos = np.frombuffer(raw, np.float32, vcount * 3, off).reshape(-1, 3) * np.float32(scale); off += vcount * 12
    nor = np.frombuffer(raw, np.float32, vcount * 3, off).reshape(-1, 3); off += vcount * 12
    uv = np.frombuffer(raw, np.float32, vcount * 2, off).reshape(-1, 2); off += vcount * 8
    idx = np.frombuffer(raw, np.int32, icount, off).reshape(-1, 3).copy()
    idx[:, [1, 2]] = idx[:, [2, 1]]
    idx = idx.astype(np.uint32).reshape(-1)
    pos = pos.astype(np.float32)
    accessors = [
        {"bufferView": add(pos.tobytes(), {"target": 34962}), "componentType": 5126, "count": vcount,
         "type": "VEC3", "min": pos.min(0).tolist(), "max": pos.max(0).tolist()},
        {"bufferView": add(nor.tobytes(), {"target": 34962}), "componentType": 5126, "count": vcount, "type": "VEC3"},
        {"bufferView": add(uv.tobytes(), {"target": 34962}), "componentType": 5126, "count": vcount, "type": "VEC2"},
        {"bufferView": add(idx.tobytes(), {"target": 34963}), "componentType": 5125, "count": len(idx), "type": "SCALAR"},
    ]
    images = []
    for im in j["images"]:
        v = j["bufferViews"][im["bufferView"]]
        payload = old_bin[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
        img = Image.open(io.BytesIO(payload))
        if max(img.size) > max_size:
            k = max_size / max(img.size)
            img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
        out = io.BytesIO()
        # Нормалі — PNG (JPEG дає смуги на рельєфі), решта — JPEG.
        if "normal" in im.get("name", ""):
            img.save(out, "PNG", optimize=True)
            mime = "image/png"
        else:
            img.convert("RGB").save(out, "JPEG", quality=90, optimize=True)
            mime = "image/jpeg"
        images.append({"bufferView": add(out.getvalue()), "mimeType": mime})
        print("  текстура %dx%d %s %dKB" % (img.width, img.height, mime, len(out.getvalue()) // 1024))
    if emissive:
        img = Image.open(emissive).convert("RGB")
        if max(img.size) > max_size:
            img = img.resize((max_size, max_size), Image.LANCZOS)
        out = io.BytesIO()
        img.save(out, "JPEG", quality=90, optimize=True)
        images.append({"bufferView": add(out.getvalue()), "mimeType": "image/jpeg"})
        j.setdefault("textures", []).append({"source": len(images) - 1})
        material = j["materials"][0]
        material["emissiveTexture"] = {"index": len(j["textures"]) - 1}
        material["emissiveFactor"] = [1.0, 1.0, 1.0]
        material["doubleSided"] = False
        print("  світіння %dx%d %dKB" % (img.width, img.height, len(out.getvalue()) // 1024))
    j["accessors"] = accessors
    j["images"] = images
    prim = j["meshes"][0]["primitives"][0]
    prim["attributes"] = {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}
    prim["indices"] = 3
    j["bufferViews"] = views
    j["buffers"] = [{"byteLength": len(blob)}]
    js = json.dumps(j, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(blob) % 4:
        blob.append(0)
    out = (struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob))
           + struct.pack("<I4s", len(js), b"JSON") + js
           + struct.pack("<I4s", len(blob), b"BIN\x00") + bytes(blob))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, "wb").write(out)
    print("OK %s: %d трикутників, %d вершин, %dKB" % (dst, len(idx) // 3, vcount, len(out) // 1024))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]), int(sys.argv[5]),
         sys.argv[6] if len(sys.argv) > 6 else None)
