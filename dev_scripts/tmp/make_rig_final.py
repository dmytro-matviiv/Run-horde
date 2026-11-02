# -*- coding: utf-8 -*-
"""Збирає rig_final.py з rig_golem.py: суглоби Тіньового Володаря (гуманоїд
у А-позі, 1.89 м), набір анімацій фінального боса з фазами."""
SRC = r"D:\RuneHorde_work\scripts\blender\rig_golem.py"
DST = r"D:\RuneHorde_work\scripts\blender\rig_final.py"
s = open(SRC, encoding="utf-8").read()


def cut(text, start, end, new):
    a = text.index(start)
    b = text.index(end, a)
    return text[:a] + new + text[b:]


s = cut(s, '# -*- coding', 'import math', '''# -*- coding: utf-8 -*-
"""Тіньовий Володар (фінальний бос, 15-й данж) і його двійники — дві
згенеровані моделі гравця (біла й темна) однакової будови, без скелета.
Той самий конвеєр, що rig_knight.py / rig_golem.py, свої суглоби (за
силуетом, у метрах; модель — у А-позі) і розширений набір анімацій:
Idle, Idle_Rage (фази 2-3), Walk, Run (фаза 3), Turn, Weapon, Weapon2
(удари по черзі), Cast (промені), Summon (розкол на двійників), Roar
(перехід фази), Jump, HitReact, Death.

  blender -b --factory-startup -P rig_final.py -- <вхід.glb> <вихід.glb> <світіння.png>
"""
''')
s = s.replace('mesh_obj.name = "LavaGolem"', 'mesh_obj.name = "ShadowLord"')
s = cut(s, 'BONES = [', ']\n\n', '''BONES = [
    ("root", None, bl(0, 0.0, 0), bl(0, 0.12, 0), 0.0),
    ("hips", "root", bl(0, 0.95, 0), bl(0, 1.10, 0), 0.16),
    ("spine", "hips", bl(0, 1.10, 0), bl(0, 1.28, 0), 0.17),
    ("chest", "spine", bl(0, 1.28, 0), bl(0, 1.48, 0), 0.20),
    ("neck", "chest", bl(0, 1.48, 0), bl(0, 1.57, 0.01), 0.08),
    ("head", "neck", bl(0, 1.57, 0.01), bl(0, 1.86, 0.02), 0.12),
    ("upperarm.L", "chest", bl(-0.28, 1.33, 0.0), bl(-0.45, 1.06, 0.0), 0.08),
    ("forearm.L", "upperarm.L", bl(-0.45, 1.06, 0.0), bl(-0.57, 0.86, 0.02), 0.07),
    ("hand.L", "forearm.L", bl(-0.57, 0.86, 0.02), bl(-0.63, 0.72, 0.03), 0.06),
    ("upperarm.R", "chest", bl(0.28, 1.33, 0.0), bl(0.45, 1.06, 0.0), 0.08),
    ("forearm.R", "upperarm.R", bl(0.45, 1.06, 0.0), bl(0.57, 0.86, 0.02), 0.07),
    ("hand.R", "forearm.R", bl(0.57, 0.86, 0.02), bl(0.63, 0.72, 0.03), 0.06),
    ("thigh.L", "hips", bl(-0.13, 0.95, 0.0), bl(-0.18, 0.47, 0.02), 0.10),
    ("shin.L", "thigh.L", bl(-0.18, 0.47, 0.02), bl(-0.20, 0.08, -0.01), 0.08),
    ("foot.L", "shin.L", bl(-0.20, 0.08, -0.01), bl(-0.20, 0.0, 0.14), 0.06),
    ("thigh.R", "hips", bl(0.13, 0.95, 0.0), bl(0.18, 0.47, 0.02), 0.10),
    ("shin.R", "thigh.R", bl(0.18, 0.47, 0.02), bl(0.20, 0.08, -0.01), 0.08),
    ("foot.R", "shin.R", bl(0.20, 0.08, -0.01), bl(0.20, 0.0, 0.14), 0.06),
''')
s = s.replace('remesh.voxel_size = 0.016', 'remesh.voxel_size = 0.011')
s = s.replace('rigid("hand.L", near_bone("hand.L", 0.14))', 'rigid("hand.L", near_bone("hand.L", 0.07))')
s = s.replace('rigid("hand.R", near_bone("hand.R", 0.14))', 'rigid("hand.R", near_bone("hand.R", 0.07))')
s = cut(s, '# Знаки: нахил уперед хребта', '# --- світіння лави ---', '''# Знаки: нахил уперед хребта — +x; нога/рука вперед — -x. Руки в спокої
# в А-позі (45° убік); "y" > 0 для лівої — відвести далі вбік.
# Стійка: руки опущені ближче до тіла, легке погойдування.
REST_ARMS = {"upperarm.L": {"y": -18}, "upperarm.R": {"y": 18},
             "forearm.L": {"x": -15}, "forearm.R": {"x": -15}}

def pose(extra):
    out = {k: dict(v) for k, v in REST_ARMS.items()}
    for bone, spec in extra.items():
        merged = dict(out.get(bone, {}))
        for axis, value in spec.items():
            merged[axis] = merged.get(axis, 0) + value if axis != "loc" else value
        out[bone] = merged
    return out

make_action("Idle", 60, {
    0: pose({"chest": {"x": 1}, "head": {"x": 2}}),
    30: pose({"chest": {"x": -2}, "head": {"x": -1, "z": 4}, "upperarm.L": {"y": 3}, "upperarm.R": {"y": -3},
              "root": {"loc": (0, 0, -0.006)}}),
}, loop=True)

# Фази 2-3: хижа стійка — нахилений уперед, руки розведені, пальці-кігті.
make_action("Idle_Rage", 40, {
    0: pose({"spine": {"x": 12}, "chest": {"x": 6}, "head": {"x": -10}, "upperarm.L": {"y": 25, "x": -15},
             "upperarm.R": {"y": -25, "x": -15}, "forearm.L": {"x": -25}, "forearm.R": {"x": -25},
             "thigh.L": {"x": -10}, "thigh.R": {"x": 6}, "shin.L": {"x": 15}, "shin.R": {"x": 8},
             "root": {"loc": (0, 0, -0.04)}}),
    20: pose({"spine": {"x": 14}, "chest": {"x": 9}, "head": {"x": -8, "z": 8}, "upperarm.L": {"y": 30, "x": -20},
              "upperarm.R": {"y": -30, "x": -20}, "forearm.L": {"x": -30}, "forearm.R": {"x": -30},
              "thigh.L": {"x": -10}, "thigh.R": {"x": 6}, "shin.L": {"x": 15}, "shin.R": {"x": 8},
              "root": {"loc": (0, 0, -0.05)}}),
}, loop=True)

def walk_pose(phase, stride, lean, bob):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({
        "thigh.L": {"x": -stride * s}, "thigh.R": {"x": stride * s},
        "shin.L": {"x": stride * 1.2 * max(0.0, -s) + 5}, "shin.R": {"x": stride * 1.2 * max(0.0, s) + 5},
        "foot.L": {"x": -8 * s}, "foot.R": {"x": 8 * s},
        "upperarm.L": {"x": 18 * s}, "upperarm.R": {"x": -18 * s},
        "spine": {"z": 7 * s, "x": lean}, "chest": {"z": -6 * s},
        "root": {"loc": (0, 0, -bob * abs(c))},
    })
make_action("Walk", 32, {f: walk_pose(f / 32 * math.tau, 24, 4, 0.02) for f in range(0, 32, 4)}, loop=True)
make_action("Run", 20, {f: walk_pose(f / 20 * math.tau, 38, 16, 0.04) for f in range(0, 20, 2)}, loop=True)

def turn_pose(phase):
    s = math.sin(phase)
    return pose({"thigh.L": {"x": -10 * max(0.0, s), "z": 8 * s}, "thigh.R": {"x": 10 * max(0.0, -s), "z": 8 * s},
                 "shin.L": {"x": 16 * max(0.0, s)}, "shin.R": {"x": 16 * max(0.0, -s)},
                 "spine": {"z": 10 * s}, "root": {"loc": (0, 0, -0.015 * abs(s))}})
make_action("Turn", 24, {f: turn_pose(f / 24 * math.tau) for f in range(0, 24, 4)}, loop=True)

# Удар правою — розгін через плече й кігтистий змах навскіс.
make_action("Weapon", 24, {
    0: pose({}),
    8: pose({"upperarm.R": {"x": -130, "y": -30}, "forearm.R": {"x": -50}, "chest": {"z": 30, "x": -6},
             "spine": {"z": 12}, "thigh.R": {"x": 10}, "thigh.L": {"x": -12}}),
    12: pose({"upperarm.R": {"x": -40, "y": 20}, "forearm.R": {"x": -5}, "chest": {"z": -30, "x": 16},
              "spine": {"z": -12, "x": 8}, "thigh.L": {"x": -25}, "shin.L": {"x": 20}, "root": {"loc": (0, 0, -0.05)}}),
    18: pose({"upperarm.R": {"x": -30, "y": 15}, "chest": {"z": -15, "x": 10}, "root": {"loc": (0, 0, -0.03)}}),
    24: pose({}),
})
# Удар лівою — у відповідь, бекхендом знизу вгору.
make_action("Weapon2", 24, {
    0: pose({}),
    7: pose({"upperarm.L": {"x": 30, "y": -10}, "forearm.L": {"x": -40}, "chest": {"z": -25},
             "spine": {"x": 10}, "root": {"loc": (0, 0, -0.04)}}),
    12: pose({"upperarm.L": {"x": -140, "y": 35}, "forearm.L": {"x": -10}, "chest": {"z": 25, "x": -10},
              "spine": {"x": -6}, "thigh.R": {"x": -20}, "shin.R": {"x": 15}}),
    18: pose({"upperarm.L": {"x": -110, "y": 30}, "chest": {"z": 15, "x": -4}}),
    24: pose({}),
})

# Промені: руки вперед, долоні до героя, тримає й тремтить від сили.
make_action("Cast", 40, {
    0: pose({}),
    8: pose({"upperarm.L": {"x": -80, "y": 10}, "upperarm.R": {"x": -80, "y": -10},
             "forearm.L": {"x": 10}, "forearm.R": {"x": 10}, "chest": {"x": -8}, "head": {"x": -6}}),
    20: pose({"upperarm.L": {"x": -85, "y": 14}, "upperarm.R": {"x": -85, "y": -14}, "chest": {"x": -12},
              "spine": {"x": -4}, "thigh.L": {"x": -15}, "shin.L": {"x": 12}, "root": {"loc": (0, 0, -0.03)}}),
    30: pose({"upperarm.L": {"x": -78, "y": 8}, "upperarm.R": {"x": -78, "y": -8}, "chest": {"x": -9},
              "thigh.L": {"x": -15}, "shin.L": {"x": 12}, "root": {"loc": (0, 0, -0.03)}}),
    40: pose({}),
})

# Розкол: розкидає руки широко вгору, наче розриває себе на тіні.
make_action("Summon", 40, {
    0: pose({}),
    10: pose({"upperarm.L": {"y": 10, "x": -20}, "upperarm.R": {"y": -10, "x": -20},
              "forearm.L": {"x": -60}, "forearm.R": {"x": -60}, "chest": {"x": 18}, "spine": {"x": 10},
              "head": {"x": 15}, "root": {"loc": (0, 0, -0.06)}}),
    22: pose({"upperarm.L": {"y": 75, "x": -40}, "upperarm.R": {"y": -75, "x": -40},
              "forearm.L": {"x": 0}, "forearm.R": {"x": 0}, "chest": {"x": -18}, "spine": {"x": -6},
              "head": {"x": -25}, "root": {"loc": (0, 0, 0.03)}}),
    32: pose({"upperarm.L": {"y": 60, "x": -30}, "upperarm.R": {"y": -60, "x": -30}, "chest": {"x": -10},
              "head": {"x": -15}}),
    40: pose({}),
})

# Рев переходу фази: присідає, стискає себе — і вибухає риком у небо.
make_action("Roar", 50, {
    0: pose({}),
    12: pose({"upperarm.L": {"x": -40, "y": -25}, "upperarm.R": {"x": -40, "y": 25},
              "forearm.L": {"x": -100}, "forearm.R": {"x": -100}, "chest": {"x": 30}, "spine": {"x": 18},
              "head": {"x": 25}, "thigh.L": {"x": -30}, "thigh.R": {"x": -30}, "shin.L": {"x": 45},
              "shin.R": {"x": 45}, "root": {"loc": (0, 0, -0.15)}}),
    24: pose({"upperarm.L": {"y": 85, "x": -60}, "upperarm.R": {"y": -85, "x": -60},
              "forearm.L": {"x": -10}, "forearm.R": {"x": -10}, "chest": {"x": -25}, "spine": {"x": -10},
              "head": {"x": -35}, "root": {"loc": (0, 0, 0.02)}}),
    38: pose({"upperarm.L": {"y": 80, "x": -55}, "upperarm.R": {"y": -80, "x": -55}, "chest": {"x": -22},
              "head": {"x": -32, "z": 6}}),
    50: pose({}),
})

make_action("Jump", 26, {
    0: pose({}),
    6: pose({"thigh.L": {"x": -45}, "thigh.R": {"x": -45}, "shin.L": {"x": 80}, "shin.R": {"x": 80},
             "foot.L": {"x": -30}, "foot.R": {"x": -30}, "spine": {"x": 20}, "upperarm.L": {"x": 30},
             "upperarm.R": {"x": 30}, "root": {"loc": (0, 0, -0.2)}}),
    12: pose({"thigh.L": {"x": -10}, "thigh.R": {"x": 15}, "shin.L": {"x": 20}, "shin.R": {"x": 30},
              "upperarm.L": {"x": -120}, "upperarm.R": {"x": -130}, "spine": {"x": -8}}),
    20: pose({"thigh.L": {"x": -40}, "thigh.R": {"x": -40}, "shin.L": {"x": 70}, "shin.R": {"x": 70},
              "spine": {"x": 22}, "root": {"loc": (0, 0, -0.17)}}),
    26: pose({}),
})

make_action("HitReact", 14, {
    0: pose({}),
    4: pose({"chest": {"x": -16, "z": 8}, "head": {"x": -14}, "spine": {"x": -6},
             "upperarm.L": {"x": 20, "y": 15}, "upperarm.R": {"x": 15, "y": -12}}),
    14: pose({}),
})

# Смерть: хапається за груди, падає на коліна, руки до неба — і навзнак.
make_action("Death", 70, {
    0: pose({}),
    10: pose({"upperarm.L": {"x": -50, "y": -40}, "upperarm.R": {"x": -50, "y": 40},
              "forearm.L": {"x": -110}, "forearm.R": {"x": -110}, "chest": {"x": 20}, "head": {"x": 20},
              "spine": {"x": 10}}),
    26: pose({"thigh.L": {"x": -85}, "thigh.R": {"x": -85}, "shin.L": {"x": 150}, "shin.R": {"x": 150},
              "foot.L": {"x": -45}, "foot.R": {"x": -45}, "chest": {"x": -10}, "head": {"x": -25},
              "upperarm.L": {"y": 70, "x": -70}, "upperarm.R": {"y": -70, "x": -70},
              "root": {"loc": (0, 0, -0.48)}}),
    44: pose({"thigh.L": {"x": -85}, "thigh.R": {"x": -85}, "shin.L": {"x": 150}, "shin.R": {"x": 150},
              "foot.L": {"x": -45}, "foot.R": {"x": -45}, "chest": {"x": -20}, "head": {"x": -40},
              "upperarm.L": {"y": 85, "x": -90}, "upperarm.R": {"y": -85, "x": -90},
              "root": {"loc": (0, 0, -0.48)}}),
    58: pose({"root": {"x": -70, "loc": (0, 0.3, -0.62)}, "thigh.L": {"x": -60}, "thigh.R": {"x": -60},
              "shin.L": {"x": 110}, "shin.R": {"x": 110}, "upperarm.L": {"y": 60}, "upperarm.R": {"y": -60},
              "head": {"x": -20}}),
    70: pose({"root": {"x": -86, "loc": (0, 0.42, -0.74)}, "thigh.L": {"x": -30}, "thigh.R": {"x": -30},
              "shin.L": {"x": 50}, "shin.R": {"x": 50}, "upperarm.L": {"y": 70}, "upperarm.R": {"y": -70},
              "head": {"x": -20}}),
})

''')
s = s.replace('# --- світіння лави ---', '# --- світіння ---')
open(DST, "w", encoding="utf-8").write(s)
print("ok")
