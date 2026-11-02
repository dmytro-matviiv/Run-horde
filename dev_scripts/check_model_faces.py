# -*- coding: utf-8 -*-
"""Перевірка орієнтації граней моделі GLB: для кожної грані пускаємо промінь
з її центру вздовж нормалі грані (за порядком вершин) і рахуємо, скільки
разів він перетне модель. Парна кількість — грань дивиться назовні,
непарна — всередину (вивернута; згори її не видно — "прозорість").
Також звіряємо нормалі вершин з порядком вершин.
  python check_model_faces.py <file.glb>"""
import json
import struct
import sys
import numpy as np


def load(path):
    data = open(path, "rb").read()
    clen = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20:20 + clen])
    binstart = 20 + clen + 8

    def read(ai):
        a = j["accessors"][ai]
        v = j["bufferViews"][a["bufferView"]]
        off = binstart + v.get("byteOffset", 0) + a.get("byteOffset", 0)
        ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
        dt = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}[a["componentType"]]
        arr = np.frombuffer(data, dtype=dt, count=a["count"] * ncomp, offset=off)
        return arr.reshape(a["count"], ncomp) if ncomp > 1 else arr

    prims = []
    for p in j["meshes"][0]["primitives"]:
        prims.append({
            "pos": read(p["attributes"]["POSITION"]).astype(np.float64),
            "nor": read(p["attributes"]["NORMAL"]).astype(np.float64),
            "idx": read(p["indices"]).astype(np.int64).reshape(-1, 3),
            "mat": j["materials"][p["material"]]["name"],
        })
    return prims


def ray_hits(origins, dirs, tri_a, tri_b, tri_c):
    """Скільки трикутників перетинає кожен промінь (Мöller–Trumbore)."""
    e1 = tri_b - tri_a
    e2 = tri_c - tri_a
    counts = np.zeros(len(origins), dtype=np.int64)
    for i in range(len(origins)):
        o, d = origins[i], dirs[i]
        p = np.cross(d, e2)
        det = (e1 * p).sum(1)
        ok = np.abs(det) > 1e-9
        inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
        s = o - tri_a
        u = (s * p).sum(1) * inv
        q = np.cross(s, e1)
        v = (q * d).sum(1) * inv
        t = (e2 * q).sum(1) * inv
        hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-4)
        counts[i] = hit.sum()
    return counts


def main(path):
    prims = load(path)
    all_a = np.concatenate([p["pos"][p["idx"][:, 0]] for p in prims])
    all_b = np.concatenate([p["pos"][p["idx"][:, 1]] for p in prims])
    all_c = np.concatenate([p["pos"][p["idx"][:, 2]] for p in prims])
    for p in prims:
        a, b, c = (p["pos"][p["idx"][:, k]] for k in range(3))
        fn = np.cross(b - a, c - a)
        length = np.linalg.norm(fn, axis=1)
        good = length > 1e-12
        fn = fn / np.where(good, length, 1.0)[:, None]
        centers = (a + b + c) / 3.0 + fn * 1e-4
        hits = ray_hits(centers[good], fn[good], all_a, all_b, all_c)
        inward = (hits % 2 == 1).sum()
        vn = p["nor"][p["idx"][:, 0]] + p["nor"][p["idx"][:, 1]] + p["nor"][p["idx"][:, 2]]
        agree = ((vn * fn).sum(1) > 0)[good].sum()
        print("%-18s граней %5d  назовні %5d  всередину %5d  нормалі вершин збігаються з гранями: %d/%d" % (
            p["mat"], good.sum(), good.sum() - inward, inward, agree, good.sum()))


if __name__ == "__main__":
    main(sys.argv[1])
