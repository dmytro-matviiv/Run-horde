# -*- coding: utf-8 -*-
"""Злиті сітки з кольором у вершинах (.bin від tools/merge_pack.gd у
test_env) -> GLB з двома матеріалами: звичайний (колір — з вершин) і той,
що світиться (руни, кристали). Без текстур: два виклики малювання на всю
модель замість одного на кожен з восьми плоских матеріалів джерела.
Порядок вершин розвертаємо (Godot — за годинниковою, glTF — проти).

  python write_vertex_color_glb.py <вхід.bin> <вихід.glb> <масштаб> <назва>"""
import json
import os
import struct
import sys
import numpy as np

GLOW_EMISSION = [0.08, 0.78, 1.0]


def main(src, dst, scale, name):
    raw = open(src, "rb").read()
    off = 0

    def take(fmt, count):
        nonlocal off
        size = struct.calcsize(fmt) * count
        out = struct.unpack_from("<%d%s" % (count, fmt), raw, off)
        off += size
        return out

    groups_count = take("I", 1)[0]
    blob = bytearray()
    views, accessors, primitives = [], [], []

    def add(payload, target):
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(payload), "target": target})
        blob.extend(payload)
        return len(views) - 1

    total = 0
    for _ in range(groups_count):
        group, vcount, icount = take("I", 3)
        pos = np.array(take("f", vcount * 3), np.float32).reshape(-1, 3) * np.float32(scale)
        nor = np.array(take("f", vcount * 3), np.float32).reshape(-1, 3)
        col = np.array(take("f", vcount * 4), np.float32).reshape(-1, 4)
        idx = np.array(take("i", icount), np.int64).reshape(-1, 3)
        if icount == 0:
            continue
        idx[:, [1, 2]] = idx[:, [2, 1]]
        idx = idx.astype(np.uint32).reshape(-1)
        pos = pos.astype(np.float32)
        base = len(accessors)
        accessors += [
            {"bufferView": add(pos.tobytes(), 34962), "componentType": 5126, "count": vcount, "type": "VEC3",
             "min": pos.min(0).tolist(), "max": pos.max(0).tolist()},
            {"bufferView": add(nor.tobytes(), 34962), "componentType": 5126, "count": vcount, "type": "VEC3"},
            {"bufferView": add(col.tobytes(), 34962), "componentType": 5126, "count": vcount, "type": "VEC4"},
            {"bufferView": add(idx.tobytes(), 34963), "componentType": 5125, "count": len(idx), "type": "SCALAR"},
        ]
        primitives.append({"attributes": {"POSITION": base, "NORMAL": base + 1, "COLOR_0": base + 2},
                           "indices": base + 3, "material": group})
        total += len(idx) // 3
        print("  група %d: %d трикутників" % (group, len(idx) // 3))

    materials = [
        {"name": "M_%s" % name, "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1],
                                                         "metallicFactor": 0.0, "roughnessFactor": 0.8}},
        {"name": "M_%s_Glow" % name, "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1],
                                                              "metallicFactor": 0.0, "roughnessFactor": 0.3},
         "emissiveFactor": GLOW_EMISSION},
    ]
    gltf = {
        "asset": {"version": "2.0", "generator": "RuneHorde write_vertex_color_glb.py"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": primitives}],
        "materials": materials,
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
    print("OK %s: %d трикутників, %dKB" % (dst, total, len(out) // 1024))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4])
