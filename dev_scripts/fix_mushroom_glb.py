# -*- coding: utf-8 -*-
"""Виправлення згенерованого гриба (SM_Mushroom_Giant): частини моделі
вивернуті навиворіт — їхні грані дивляться всередину, тож відеокарта не
малює їх з того боку, звідки дивиться камера ("прозорість").

  M_Cap   (шапка)      — вивернута: розвертаємо грані назовні й нормалі.
  M_Stalk (ніжка)      — вивернута: так само.
  M_Gills (пластинки)  — грані дивляться вниз, як і треба (їх видно знизу),
                         але нормалі — вгору: світло лягало навпаки. Нормалі
                         розвертаємо під грані.
  M_Roots (коріння)    — правильне.

Плюс усі матеріали двобічні (doubleSided): стики й краї шапки не
просвічують ні з якого боку. Перевірка — check_model_faces.py."""
import json
import struct
import numpy as np

SRC = r"D:\RuneHorde_work\incoming\SM_Mushroom_Giant_1.glb"
DST = r"D:\Claude code\idle survivor_like\assets\models\fungal\mushroom_giant.glb"
FLIP_FACES = {"M_Cap", "M_Stalk"}
FLIP_NORMALS = {"M_Cap", "M_Stalk", "M_Gills_Emissive"}


def main():
    data = open(SRC, "rb").read()
    clen = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20:20 + clen])
    bin_header = data[20 + clen:20 + clen + 8]
    blob = bytearray(data[20 + clen + 8:])

    def view(ai):
        a = j["accessors"][ai]
        v = j["bufferViews"][a["bufferView"]]
        off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        ncomp = {"SCALAR": 1, "VEC3": 3}[a["type"]]
        dt = {5126: np.float32, 5123: np.uint16, 5125: np.uint32}[a["componentType"]]
        assert v.get("byteStride", np.dtype(dt).itemsize * ncomp) == np.dtype(dt).itemsize * ncomp, "чергування даних не підтримано"
        arr = np.frombuffer(blob, dtype=dt, count=a["count"] * ncomp, offset=off).copy()
        return arr, off

    for p in j["meshes"][0]["primitives"]:
        name = j["materials"][p["material"]]["name"]
        if name in FLIP_FACES:
            idx, off = view(p["indices"])
            tris = idx.reshape(-1, 3)
            tris[:, [1, 2]] = tris[:, [2, 1]]
            blob[off:off + idx.nbytes] = tris.reshape(-1).tobytes()
        if name in FLIP_NORMALS:
            nor, off = view(p["attributes"]["NORMAL"])
            blob[off:off + nor.nbytes] = (-nor).astype(np.float32).tobytes()
        print("%-18s грані %s, нормалі %s" % (name,
            "розвернуто" if name in FLIP_FACES else "як є",
            "розвернуто" if name in FLIP_NORMALS else "як є"))

    for m in j["materials"]:
        m["doubleSided"] = True
    js = json.dumps(j, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    out = (struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob))
           + struct.pack("<I4s", len(js), b"JSON") + js + bin_header + bytes(blob))
    open(DST, "wb").write(out)
    print("OK", DST, len(out))


if __name__ == "__main__":
    main()
