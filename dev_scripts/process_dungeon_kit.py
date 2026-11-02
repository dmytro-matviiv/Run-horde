# -*- coding: utf-8 -*-
"""DungeonKit (набір гравця для Грибних нетрів) -> легкі моделі для данжу.

Набір зроблено під сітку 4 м, наш данж — 2 м на клітинку й 2 м стіни,
тож усе зменшуємо вдвічі (координати x0.5 прямо в моделі).

Плитка підлоги (4226 трикутників) і стіна (~6000) — це щільна сітка, з
якої витиснуто рельєф кладки (3-4 см). Малюнок каменю вже є в текстурі,
а текстура на верх підлоги й лице стіни натягнута площиною (перевірено:
похибка 0 і 0.019). Тож легка версія з тими самими текстурами виглядає
так само з ізометричної камери, а коштує в сотні разів менше:
  підлога — верх (2 трикутники) + бортики;
  стіна   — рівне лице й тил квадами, верх і торці — з оригіналу.
До того ж у підлозі набору верх вивернутий (грані дивляться вниз — згори
його не видно); тут грані будуються наново й правильно.
Колона, уламки — геометрія як є (вона й робить їх об'ємними), лише x0.5.

  python process_dungeon_kit.py [fungal|ice]   (без аргументу — fungal)

Набори: fungal — DungeonKit (Грибні нетрі), ice — IceCitadel (Крижана
цитадель); будова однакова: сітка 4 м, плити й стіни з рельєфом."""
import json
import os
import struct
import numpy as np

SCALE = 0.5
KITS = {
    "fungal": {
        "src": r"D:\RuneHorde_work\incoming\DungeonKit",
        "dst": r"D:\Claude code\idle survivor_like\assets\models\fungal\kit",
        "floors": {"SM_Floor_A_Glow": "floor_glow", "SM_Floor_B_Plain": "floor_plain", "SM_Floor_C_Roots": "floor_roots"},
        "walls": {
            "SM_Wall_A_Plain": "wall_plain", "SM_Wall_B_Moss": "wall_moss", "SM_Wall_C_Roots": "wall_roots",
            "SM_Wall_D_Shrooms": "wall_shrooms", "SM_Wall_E_Plain2": "wall_plain2", "SM_Wall_F_Moss2": "wall_moss2",
            "SM_Wall_G_Roots2": "wall_roots2", "SM_Wall_H_Crack": "wall_crack",
        },
        "props": {"SM_Column": "column", "SM_Rubble": "rubble"},
    },
    "ice": {
        "src": r"D:\RuneHorde_work\incoming\IceCitadel",
        "dst": r"D:\Claude code\idle survivor_like\assets\models\citadel\kit",
        "floors": {"SM_IceFloor_A_Runes": "floor_runes", "SM_IceFloor_B_Snow": "floor_snow", "SM_IceFloor_C_Glow": "floor_glow"},
        "walls": {"SM_IceWall_A_Runes": "wall_runes", "SM_IceWall_B_Pillar": "wall_pillar", "SM_IceWall_C_Frost": "wall_frost"},
        "props": {},
    },
}
# Поточний набір — виставляє main().
SRC = DST = ""


def load(path):
    data = open(path, "rb").read()
    clen = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20:20 + clen])
    binstart = 20 + clen + 8

    def raw_view(index):
        v = j["bufferViews"][index]
        off = binstart + v.get("byteOffset", 0)
        return data[off:off + v["byteLength"]]

    def read(ai):
        a = j["accessors"][ai]
        v = j["bufferViews"][a["bufferView"]]
        off = binstart + v.get("byteOffset", 0) + a.get("byteOffset", 0)
        ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[a["type"]]
        dt = {5126: np.float32, 5123: np.uint16, 5125: np.uint32}[a["componentType"]]
        arr = np.frombuffer(data, dtype=dt, count=a["count"] * ncomp, offset=off)
        return arr.reshape(a["count"], ncomp) if ncomp > 1 else arr

    p = j["meshes"][0]["primitives"][0]
    geo = {
        "pos": read(p["attributes"]["POSITION"]).astype(np.float64),
        "nor": read(p["attributes"]["NORMAL"]).astype(np.float64),
        "uv": read(p["attributes"]["TEXCOORD_0"]).astype(np.float64),
        "idx": read(p["indices"]).astype(np.int64).reshape(-1, 3),
    }
    images = [(im.get("mimeType", "image/png"), raw_view(im["bufferView"])) for im in j["images"]]
    return j, geo, images


def fit_uv(points2d, uv):
    """UV = A·[a, b, 1] за найменшими квадратами; повертає функцію."""
    A = np.c_[points2d, np.ones(len(points2d))]
    coef = np.linalg.lstsq(A, uv, rcond=None)[0]
    return lambda q: np.c_[np.asarray(q, dtype=np.float64), np.ones(len(q))] @ coef


class Builder:
    """Збирає трикутники; кожен розвертає так, щоб він дивився за `facing`."""

    def __init__(self):
        self.pos, self.nor, self.uv, self.tris = [], [], [], []

    def tri(self, p, n, uv, facing):
        p = [np.asarray(v, dtype=np.float64) for v in p]
        if np.dot(np.cross(p[1] - p[0], p[2] - p[0]), facing) < 0:
            p = [p[0], p[2], p[1]]
            n = [n[0], n[2], n[1]]
            uv = [uv[0], uv[2], uv[1]]
        base = len(self.pos)
        self.pos += p
        self.nor += [np.asarray(v, dtype=np.float64) for v in n]
        self.uv += [np.asarray(v, dtype=np.float64) for v in uv]
        self.tris.append([base, base + 1, base + 2])

    def quad(self, corners, uvs, normal):
        n = [normal] * 3
        self.tri(corners[:3], n, uvs[:3], normal)
        self.tri([corners[0], corners[2], corners[3]], n, [uvs[0], uvs[2], uvs[3]], normal)


def write_glb(path, source_json, images, builder, name):
    pos = (np.array(builder.pos) * SCALE).astype(np.float32)
    nor = np.array(builder.nor, dtype=np.float32)
    nor /= np.linalg.norm(nor, axis=1, keepdims=True) + 1e-12
    uv = np.array(builder.uv, dtype=np.float32)
    idx = np.array(builder.tris, dtype=np.uint32).reshape(-1)

    blob = bytearray()
    views = []

    def add_view(data, target=None):
        while len(blob) % 4:
            blob.append(0)
        view = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)}
        if target:
            view["target"] = target
        blob.extend(data)
        views.append(view)
        return len(views) - 1

    accessors = [
        {"bufferView": add_view(pos.tobytes(), 34962), "componentType": 5126, "count": len(pos), "type": "VEC3",
         "min": pos.min(0).tolist(), "max": pos.max(0).tolist()},
        {"bufferView": add_view(nor.tobytes(), 34962), "componentType": 5126, "count": len(nor), "type": "VEC3"},
        {"bufferView": add_view(uv.tobytes(), 34962), "componentType": 5126, "count": len(uv), "type": "VEC2"},
        {"bufferView": add_view(idx.tobytes(), 34963), "componentType": 5125, "count": len(idx), "type": "SCALAR"},
    ]
    gl_images = []
    for mime, data in images:
        gl_images.append({"bufferView": add_view(data), "mimeType": mime})
    material = dict(source_json["materials"][0])
    gltf = {
        "asset": {"version": "2.0", "generator": "RuneHorde process_dungeon_kit.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": [{
            "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
        "materials": [material],
        "textures": source_json["textures"],
        "images": gl_images,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    if "samplers" in source_json:
        gltf["samplers"] = source_json["samplers"]
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(blob) % 4:
        blob.append(0)
    out = (struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob))
           + struct.pack("<I4s", len(js), b"JSON") + js
           + struct.pack("<I4s", len(blob), b"BIN\x00") + bytes(blob))
    with open(path, "wb") as f:
        f.write(out)
    return len(builder.tris)


def floor(name, out_name):
    j, g, images = load(os.path.join(SRC, name + ".glb"))
    up = g["nor"][:, 1] > 0.7
    top_uv = fit_uv(g["pos"][up][:, [0, 2]], g["uv"][up])
    side = (np.abs(g["nor"][:, 1]) < 0.3)
    side_uv = g["uv"][side].mean(0)
    b = Builder()
    corners = np.array([[-2, -2], [2, -2], [2, 2], [-2, 2]], dtype=np.float64)
    uvs = top_uv(corners)
    b.quad([[c[0], 0.0, c[1]] for c in corners], list(uvs), np.array([0, 1, 0.0]))
    # Бортики плити — на краю рівня, де поруч порожнеча, їх видно.
    for (x0, z0), (x1, z1), normal in [((-2, 2), (2, 2), (0, 0, 1)), ((2, -2), (-2, -2), (0, 0, -1)),
                                         ((2, 2), (2, -2), (1, 0, 0)), ((-2, -2), (-2, 2), (-1, 0, 0))]:
        b.quad([[x0, 0, z0], [x1, 0, z1], [x1, -0.35, z1], [x0, -0.35, z0]], [side_uv] * 4, np.array(normal, dtype=float))
    return write_glb(os.path.join(DST, out_name + ".glb"), j, images, b, out_name)


def wall(name, out_name):
    j, g, images = load(os.path.join(SRC, name + ".glb"))
    pos, nor, uv, idx = g["pos"], g["nor"], g["uv"], g["idx"]
    front = (nor[:, 2] > 0.7) & (pos[:, 2] > -1.6)
    front_uv = fit_uv(pos[front][:, [0, 1]], uv[front])
    back = (nor[:, 2] < -0.7) & (pos[:, 2] < -1.95)
    back_uv = uv[back].mean(0)
    b = Builder()
    # Лице й тил — рівні площини на місці рельєфної сітки.
    corners = np.array([[-2, -0.09], [2, -0.09], [2, 4.0], [-2, 4.0]], dtype=np.float64)
    b.quad([[c[0], c[1], -1.5] for c in corners], list(front_uv(corners)), np.array([0, 0, 1.0]))
    b.quad([[c[0], c[1], -2.0] for c in corners], [back_uv] * 4, np.array([0, 0, -1.0]))
    # Верх і торці — з оригіналу (їх мало, і там своя розгортка).
    relief_zone = pos[:, 2] > -1.545
    for t in idx:
        n = nor[t].mean(0)
        n /= np.linalg.norm(n) + 1e-12
        if relief_zone[t].all() and not (n[1] > 0.7 and pos[t][:, 1].min() > 3.7):
            continue   # рельєф лиця: схований за рівним лицем
        if n[2] < -0.7 and pos[t][:, 2].max() < -1.95:
            continue   # тил: замінено квадом
        if n[1] < -0.7 and pos[t][:, 1].max() < 0.0:
            continue   # низ під підлогою — не видно ніколи
        if n[1] > 0.7 and pos[t][:, 1].min() < 3.7:
            continue   # уступи рельєфу всередині
        b.tri(pos[t], nor[t], uv[t], n)
    return write_glb(os.path.join(DST, out_name + ".glb"), j, images, b, out_name)


def prop(name, out_name):
    j, g, images = load(os.path.join(SRC, name + ".glb"))
    b = Builder()
    for t in g["idx"]:
        n = g["nor"][t].mean(0)
        b.tri(g["pos"][t], g["nor"][t], g["uv"][t], n)
    return write_glb(os.path.join(DST, out_name + ".glb"), j, images, b, out_name)


def main(kit_name):
    global SRC, DST
    kit = KITS[kit_name]
    SRC, DST = kit["src"], kit["dst"]
    os.makedirs(DST, exist_ok=True)
    for src, dst in kit["floors"].items():
        print("%-20s -> %-14s %5d трикутників" % (src, dst, floor(src, dst)))
    for src, dst in kit["walls"].items():
        print("%-20s -> %-14s %5d трикутників" % (src, dst, wall(src, dst)))
    for src, dst in kit["props"].items():
        print("%-20s -> %-14s %5d трикутників" % (src, dst, prop(src, dst)))


if __name__ == "__main__":
    import sys
    main(sys.argv[1] if len(sys.argv) > 1 else "fungal")
