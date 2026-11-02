# -*- coding: utf-8 -*-
"""Збирає rig_golem.py з rig_knight.py: інші суглоби, без меча й плаща,
важкі анімації голема, карта світіння лави."""
SRC = r"D:\RuneHorde_work\scripts\blender\rig_knight.py"
DST = r"D:\RuneHorde_work\scripts\blender\rig_golem.py"
s = open(SRC, encoding="utf-8").read()


def cut(text, start, end, new):
    a = text.index(start)
    b = text.index(end, a)
    return text[:a] + new + text[b:]


s = cut(s, '# -*- coding', 'import math', '''# -*- coding: utf-8 -*-
"""Лавовий голем (згенерована модель гравця, без скелета) -> бос 5-го данжу.
Той самий конвеєр, що rig_knight.py (скелет, теплові ваги через вокселеву
копію, анімації окремими Action), але суглоби — за силуетом голема (у
метрах), без меча, з картою світіння лави.

  blender -b --factory-startup -P rig_golem.py -- <вхід.glb> <вихід.glb> <світіння.png>
"""
''')
s = s.replace('TARGET_TRIS = int(argv[2]) if len(argv) > 2 else 12000', 'EMISSIVE = argv[2]\nTARGET_TRIS = 12000')
s = s.replace('mesh_obj.name = "DarkKnight"', 'mesh_obj.name = "LavaGolem"')
s = cut(s, '# --- скелет.', 'arm_data = bpy.data.armatures.new', '''# --- скелет (у метрах; "гра": x — убік, y — вгору, z — уперед).
# Blender: (x, -z, y). Права рука — на +x.
def bl(x, y, z):
    return Vector((x, -z, y))

BONES = [
    ("root", None, bl(0, 0.0, 0), bl(0, 0.12, 0), 0.0),
    ("hips", "root", bl(0, 0.68, 0), bl(0, 0.85, 0), 0.30),
    ("spine", "hips", bl(0, 0.85, 0), bl(0, 1.10, 0), 0.30),
    ("chest", "spine", bl(0, 1.10, 0), bl(0, 1.40, 0), 0.35),
    ("neck", "chest", bl(0, 1.40, 0), bl(0, 1.50, 0.02), 0.15),
    ("head", "neck", bl(0, 1.50, 0.02), bl(0, 1.86, 0.05), 0.20),
    ("upperarm.L", "chest", bl(-0.50, 1.30, 0.0), bl(-0.72, 0.86, 0.03), 0.15),
    ("forearm.L", "upperarm.L", bl(-0.72, 0.86, 0.03), bl(-0.80, 0.50, 0.05), 0.14),
    ("hand.L", "forearm.L", bl(-0.80, 0.50, 0.05), bl(-0.80, 0.30, 0.06), 0.13),
    ("upperarm.R", "chest", bl(0.50, 1.30, 0.0), bl(0.72, 0.86, 0.03), 0.15),
    ("forearm.R", "upperarm.R", bl(0.72, 0.86, 0.03), bl(0.80, 0.50, 0.05), 0.14),
    ("hand.R", "forearm.R", bl(0.80, 0.50, 0.05), bl(0.80, 0.30, 0.06), 0.13),
    ("thigh.L", "hips", bl(-0.30, 0.68, 0.0), bl(-0.33, 0.33, 0.03), 0.17),
    ("shin.L", "thigh.L", bl(-0.33, 0.33, 0.03), bl(-0.35, 0.08, 0.0), 0.15),
    ("foot.L", "shin.L", bl(-0.35, 0.08, 0.0), bl(-0.35, 0.0, 0.15), 0.12),
    ("thigh.R", "hips", bl(0.30, 0.68, 0.0), bl(0.33, 0.33, 0.03), 0.17),
    ("shin.R", "thigh.R", bl(0.33, 0.33, 0.03), bl(0.35, 0.08, 0.0), 0.15),
    ("foot.R", "shin.R", bl(0.35, 0.08, 0.0), bl(0.35, 0.0, 0.15), 0.12),
]

''')
s = cut(s, '# Меч — одна сітка з тілом', '# Ваги: спершу', 'sword = np.zeros(len(coords), bool)\n')
s = s.replace('remesh.voxel_size = 0.009', 'remesh.voxel_size = 0.016')
s = cut(s, '    hand_rigid = sword | near_bone("hand.L", 0.06)', '    print("WEIGHTS: heat")', '''    # Кулаки — цілком на кистях.
    print("RIGID hand.L", rigid("hand.L", near_bone("hand.L", 0.14)))
    print("RIGID hand.R", rigid("hand.R", near_bone("hand.R", 0.14)))
''')
s = cut(s, '# Знаки: нахил уперед хребта', '# --- текстури й експорт ---', '''# Знаки: нахил уперед хребта — +x; нога/рука вперед — -x (вони звисають).
make_action("Idle", 60, {
    0: {"chest": {"x": 2}, "head": {"x": 2}, "upperarm.L": {"y": 2}, "upperarm.R": {"y": -2}},
    30: {"chest": {"x": -3}, "spine": {"x": 1}, "head": {"x": -2, "z": 5},
         "upperarm.L": {"y": 6}, "upperarm.R": {"y": -6}, "root": {"loc": (0, 0, -0.01)}},
}, loop=True)

# Важка хода: короткий крок, перевалюється з боку на бік.
def walk_pose(phase):
    s = math.sin(phase)
    c = math.cos(phase)
    return {
        "thigh.L": {"x": -18 * s}, "thigh.R": {"x": 18 * s},
        "shin.L": {"x": 22 * max(0.0, -s) + 4}, "shin.R": {"x": 22 * max(0.0, s) + 4},
        "foot.L": {"x": -8 * s}, "foot.R": {"x": 8 * s},
        "upperarm.L": {"x": 16 * s, "y": 4}, "upperarm.R": {"x": -16 * s, "y": -4},
        "forearm.L": {"x": -10}, "forearm.R": {"x": -10},
        "spine": {"y": 4 * s, "x": 6}, "chest": {"z": -6 * s},
        "root": {"loc": (0, 0, -0.03 * abs(c))},
    }
make_action("Walk", 36, {f: walk_pose(f / 36 * math.tau) for f in range(0, 36, 4)}, loop=True)

def turn_pose(phase):
    s = math.sin(phase)
    return {"thigh.L": {"x": -10 * max(0.0, s), "z": 8 * s}, "thigh.R": {"x": 10 * max(0.0, -s), "z": 8 * s},
            "shin.L": {"x": 16 * max(0.0, s)}, "shin.R": {"x": 16 * max(0.0, -s)},
            "spine": {"z": 10 * s}, "upperarm.L": {"x": 8 * s}, "upperarm.R": {"x": -8 * s},
            "root": {"loc": (0, 0, -0.02 * abs(s))}}
make_action("Turn", 28, {f: turn_pose(f / 28 * math.tau) for f in range(0, 28, 4)}, loop=True)

# Удар: обидва кулаки здіймає над головою й гатить у землю (ударна хвиля).
make_action("Weapon", 30, {
    0: {},
    11: {"upperarm.L": {"x": -165, "y": 15}, "upperarm.R": {"x": -165, "y": -15},
         "forearm.L": {"x": -30}, "forearm.R": {"x": -30}, "chest": {"x": -14}, "spine": {"x": -6},
         "head": {"x": -10}, "root": {"loc": (0, 0, 0.03)}},
    16: {"upperarm.L": {"x": -55, "y": 10}, "upperarm.R": {"x": -55, "y": -10},
         "forearm.L": {"x": -10}, "forearm.R": {"x": -10}, "chest": {"x": 30}, "spine": {"x": 18},
         "head": {"x": 10}, "thigh.L": {"x": -30}, "thigh.R": {"x": -30}, "shin.L": {"x": 45},
         "shin.R": {"x": 45}, "root": {"loc": (0, 0, -0.16)}},
    22: {"upperarm.L": {"x": -45, "y": 10}, "upperarm.R": {"x": -45, "y": -10}, "chest": {"x": 24},
         "spine": {"x": 14}, "thigh.L": {"x": -22}, "thigh.R": {"x": -22}, "shin.L": {"x": 32},
         "shin.R": {"x": 32}, "root": {"loc": (0, 0, -0.11)}},
    30: {},
})

# Чари (метеоритний дощ): розкидає руки в боки й угору, реве в небо.
make_action("Cast", 40, {
    0: {},
    10: {"upperarm.L": {"y": 55, "x": -30}, "upperarm.R": {"y": -55, "x": -30},
         "forearm.L": {"x": -30}, "forearm.R": {"x": -30}, "chest": {"x": -8}, "head": {"x": -15}},
    20: {"upperarm.L": {"y": 80, "x": -70}, "upperarm.R": {"y": -80, "x": -70},
         "forearm.L": {"x": -20}, "forearm.R": {"x": -20}, "chest": {"x": -18}, "spine": {"x": -6},
         "head": {"x": -30}, "root": {"loc": (0, 0, 0.02)}},
    30: {"upperarm.L": {"y": 40, "x": -40}, "upperarm.R": {"y": -40, "x": -40},
         "chest": {"x": 10}, "head": {"x": 5}, "thigh.L": {"x": -15}, "shin.L": {"x": 15},
         "root": {"loc": (0, 0, -0.05)}},
    40: {},
})

make_action("Jump", 28, {
    0: {},
    7: {"thigh.L": {"x": -45}, "thigh.R": {"x": -45}, "shin.L": {"x": 75}, "shin.R": {"x": 75},
        "foot.L": {"x": -25}, "foot.R": {"x": -25}, "spine": {"x": 22}, "upperarm.L": {"x": 35},
        "upperarm.R": {"x": 35}, "root": {"loc": (0, 0, -0.22)}},
    13: {"thigh.L": {"x": -10}, "thigh.R": {"x": 10}, "shin.L": {"x": 20}, "shin.R": {"x": 25},
         "upperarm.L": {"x": -120, "y": 20}, "upperarm.R": {"x": -120, "y": -20}, "spine": {"x": -8}},
    21: {"thigh.L": {"x": -40}, "thigh.R": {"x": -40}, "shin.L": {"x": 65}, "shin.R": {"x": 65},
         "spine": {"x": 24}, "upperarm.L": {"x": -40}, "upperarm.R": {"x": -40},
         "root": {"loc": (0, 0, -0.18)}},
    28: {},
})

make_action("HitReact", 16, {
    0: {},
    5: {"chest": {"x": -14, "z": 8}, "head": {"x": -14}, "spine": {"x": -6},
        "upperarm.L": {"x": 15, "y": 15}, "upperarm.R": {"x": 15, "y": -15}},
    16: {},
})

# Смерть: падає на коліна, тоді ниць уперед.
make_action("Death", 56, {
    0: {},
    12: {"chest": {"x": -20}, "head": {"x": -25}, "upperarm.L": {"y": 40, "x": -30},
         "upperarm.R": {"y": -40, "x": -30}},
    26: {"thigh.L": {"x": -80}, "thigh.R": {"x": -80}, "shin.L": {"x": 140}, "shin.R": {"x": 140},
         "foot.L": {"x": -40}, "foot.R": {"x": -40}, "spine": {"x": 15}, "chest": {"x": 10},
         "upperarm.L": {"x": 10, "y": 20}, "upperarm.R": {"x": 10, "y": -20}, "root": {"loc": (0, 0, -0.42)}},
    42: {"root": {"x": 70, "loc": (0, -0.35, -0.55)}, "thigh.L": {"x": -60}, "thigh.R": {"x": -60},
         "shin.L": {"x": 110}, "shin.R": {"x": 110}, "upperarm.L": {"x": -90, "y": 15},
         "upperarm.R": {"x": -90, "y": -15}, "head": {"x": 20}},
    56: {"root": {"x": 84, "loc": (0, -0.45, -0.62)}, "thigh.L": {"x": -30}, "thigh.R": {"x": -30},
         "shin.L": {"x": 60}, "shin.R": {"x": 60}, "upperarm.L": {"x": -150, "y": 20},
         "upperarm.R": {"x": -150, "y": -20}, "head": {"x": 25}},
})

# --- світіння лави ---
glow = bpy.data.images.load(EMISSIVE)
for mat in mesh_obj.data.materials:
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = glow
    links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    mat.use_backface_culling = True

''')
open(DST, "w", encoding="utf-8").write(s)
print("ok")
