# -*- coding: utf-8 -*-
"""Крижана статуя лицаря (згенерована гравцем) -> модель під телефон.

Геометрія — спрощена вдвічі (8710 -> ~4350 трикутників) вбудованим у
Godot meshoptimizer: tools/simplify_mesh.gd у test_env пише її в lod.bin;
дрібний рельєф лишається в карті нормалей. Godot зберігає грані за
годинниковою стрілкою, glTF — проти, тож порядок вершин розвертаємо.
Без lod.bin — геометрія оригіналу як є.
Текстури 2048 -> 1024 (на екрані статуя ~200 px заввишки — більше не видно),
колір і шорсткість — JPEG, нормалі — PNG (JPEG дає смуги на рельєфі).
Карту світіння (texture_emissive.png — сині руни й тріщини криги) вшиваємо
в матеріал: руни світяться без джерел світла. Двобічність вимикаємо —
модель замкнена, зворотні грані малювати даремно.

  python process_statue.py"""
import io
import json
import os
import struct
import numpy as np
from PIL import Image

SRC_DIR = r"D:\RuneHorde_work\incoming\statue"
DST = r"D:\Claude code\idle survivor_like\assets\models\citadel\ice_knight_statue.glb"
SIZE = 1024
LOD_BIN = SRC_DIR + r"\lod.bin"


def main():
    data = open(SRC_DIR + r"\base_basic_pbr.glb", "rb").read()
    clen = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20:20 + clen])
    binstart = 20 + clen + 8
    old_bin = data[binstart:]

    def view_bytes(index):
        v = j["bufferViews"][index]
        off = v.get("byteOffset", 0)
        return old_bin[off:off + v["byteLength"]]

    image_views = {im["bufferView"] for im in j["images"]}
    blob = bytearray()
    views = []
    remap = {}

    def add(data_bytes, extra=None):
        while len(blob) % 4:
            blob.append(0)
        view = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(data_bytes)}
        if extra:
            view.update(extra)
        blob.extend(data_bytes)
        views.append(view)
        return len(views) - 1

    if os.path.exists(LOD_BIN):
        raw = open(LOD_BIN, "rb").read()
        vcount, icount = struct.unpack("<II", raw[:8])
        off = 8
        pos = np.frombuffer(raw, np.float32, vcount * 3, off).reshape(-1, 3); off += vcount * 12
        nor = np.frombuffer(raw, np.float32, vcount * 3, off).reshape(-1, 3); off += vcount * 12
        uv = np.frombuffer(raw, np.float32, vcount * 2, off).reshape(-1, 2); off += vcount * 8
        idx = np.frombuffer(raw, np.int32, icount, off).reshape(-1, 3).copy()
        idx[:, [1, 2]] = idx[:, [2, 1]]
        idx = idx.astype(np.uint32).reshape(-1)
        j["accessors"] = [
            {"bufferView": add(pos.tobytes(), {"target": 34962}), "componentType": 5126, "count": vcount,
             "type": "VEC3", "min": pos.min(0).tolist(), "max": pos.max(0).tolist()},
            {"bufferView": add(nor.tobytes(), {"target": 34962}), "componentType": 5126, "count": vcount, "type": "VEC3"},
            {"bufferView": add(uv.tobytes(), {"target": 34962}), "componentType": 5126, "count": vcount, "type": "VEC2"},
            {"bufferView": add(idx.tobytes(), {"target": 34963}), "componentType": 5125, "count": len(idx), "type": "SCALAR"},
        ]
        j["meshes"][0]["primitives"][0]["attributes"] = {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}
        j["meshes"][0]["primitives"][0]["indices"] = 3
        print("  геометрія з lod.bin: %d трикутників, %d вершин" % (len(idx) // 3, vcount))
    else:
        for i, v in enumerate(j["bufferViews"]):
            if i in image_views:
                continue
            extra = {k: v[k] for k in ("byteStride", "target") if k in v}
            remap[i] = add(view_bytes(i), extra)
        for a in j["accessors"]:
            a["bufferView"] = remap[a["bufferView"]]

    def encode(img, fmt):
        out = io.BytesIO()
        if fmt == "JPEG":
            img.convert("RGB").save(out, "JPEG", quality=90, optimize=True)
            return out.getvalue(), "image/jpeg"
        img.save(out, "PNG", optimize=True)
        return out.getvalue(), "image/png"

    images = []
    for im in j["images"]:
        src = Image.open(io.BytesIO(view_bytes(im["bufferView"]))).resize((SIZE, SIZE), Image.LANCZOS)
        fmt = "PNG" if "normal" in im.get("name", "") else "JPEG"
        payload, mime = encode(src, fmt)
        images.append({"bufferView": add(payload), "mimeType": mime, "name": im.get("name", "")})
        print("  %-38s %s %dKB" % (im.get("name"), fmt, len(payload) // 1024))
    emissive = Image.open(SRC_DIR + r"\texture_emissive.png").resize((SIZE, SIZE), Image.LANCZOS)
    payload, mime = encode(emissive, "JPEG")
    images.append({"bufferView": add(payload), "mimeType": mime, "name": "texture_emissive"})
    print("  %-38s JPEG %dKB" % ("texture_emissive", len(payload) // 1024))
    j["images"] = images
    j["textures"].append({"source": len(images) - 1})

    material = j["materials"][0]
    material["name"] = "M_IceKnightStatue"
    material["doubleSided"] = False
    material["emissiveTexture"] = {"index": len(j["textures"]) - 1}
    material["emissiveFactor"] = [1.0, 1.0, 1.0]
    j["nodes"][0]["name"] = "IceKnightStatue"
    j["bufferViews"] = views
    j["buffers"] = [{"byteLength": len(blob)}]

    js = json.dumps(j, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(blob) % 4:
        blob.append(0)
    out = (struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob))
           + struct.pack("<I4s", len(js), b"JSON") + js
           + struct.pack("<I4s", len(blob), b"BIN\x00") + bytes(blob))
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    open(DST, "wb").write(out)
    print("OK", DST, len(out) // 1024, "KB")


if __name__ == "__main__":
    main()
