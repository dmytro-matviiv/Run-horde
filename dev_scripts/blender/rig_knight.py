# -*- coding: utf-8 -*-
"""Темний лицар (згенерована модель гравця, без скелета) -> босс з анімаціями.

Запуск (фоном, без вікна):
  blender -b --factory-startup -P rig_knight.py -- <вхід.glb> <вихід.glb> [трикутників]

1. Імпорт, перенесення повороту в геометрію, спрощення (Decimate).
2. Скелет з 18 кісток: суглоби поставлено за силуетом моделі (зріст H,
   частки висоти — див. JOINTS). Модель дивиться в -Y (glTF +Z).
3. Ваги вершин — за відносною відстанню до кістки (відстань / "товщина"
   кістки), 6-й степінь, не більше трьох кісток на вершину. Меч (усе, що
   попереду тіла нижче кистей) — повністю на правій кисті.
4. Анімації — ключі поворотів кісток навколо осей арматури (X — нахил
   вперед/назад, Y — нахил убік, Z — поворот), окремими Action:
   Idle, Walk, Turn, Weapon, Cast, Jump, HitReact, Death.
5. Експорт GLB з усіма Action, текстури 1024.
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = argv[0], argv[1]
TARGET_TRIS = int(argv[2]) if len(argv) > 2 else 12000
FPS = 30

# --- сцена ---
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=SRC)
mesh_obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
for o in bpy.context.scene.objects:
    o.select_set(False)
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mesh_obj.name = "DarkKnight"

tris = sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons)
mod = mesh_obj.modifiers.new("decimate", "DECIMATE")
mod.ratio = min(1.0, TARGET_TRIS / tris)
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
print("TRIS", tris, "->", sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons))

coords = np.array([v.co[:] for v in mesh_obj.data.vertices])
H = float(coords[:, 2].max())
print("HEIGHT", H)

# --- скелет. Координати "гри": x — убік, y — вгору (частка H), z — уперед.
# Blender: (x, -z, y*H). Права рука з мечем — на +x.
def bl(x, y, z):
    return Vector((x, -z, y * H))

BONES = [
    # назва, батько, голова, хвіст, товщина
    ("root", None, bl(0, 0.0, 0), bl(0, 0.08, 0), 0.0),
    ("hips", "root", bl(0, 0.48, 0), bl(0, 0.58, 0), 0.13),
    ("spine", "hips", bl(0, 0.58, 0), bl(0, 0.70, 0), 0.13),
    ("chest", "spine", bl(0, 0.70, 0), bl(0, 0.82, 0), 0.14),
    ("neck", "chest", bl(0, 0.82, 0), bl(0, 0.87, 0), 0.06),
    ("head", "neck", bl(0, 0.87, 0), bl(0, 1.0, 0.0), 0.08),
    # Ліва рука тримає меч: кисть — перед лівим стегном, на руків'ї.
    ("upperarm.L", "chest", bl(-0.09, 0.79, -0.01), bl(-0.18, 0.63, 0.0), 0.05),
    ("forearm.L", "upperarm.L", bl(-0.18, 0.63, 0.0), bl(-0.15, 0.50, 0.06), 0.045),
    ("hand.L", "forearm.L", bl(-0.15, 0.50, 0.06), bl(-0.09, 0.47, 0.12), 0.04),
    ("upperarm.R", "chest", bl(0.09, 0.79, -0.01), bl(0.18, 0.65, 0.0), 0.05),
    ("forearm.R", "upperarm.R", bl(0.18, 0.65, 0.0), bl(0.21, 0.50, 0.05), 0.045),
    ("hand.R", "forearm.R", bl(0.21, 0.50, 0.05), bl(0.215, 0.45, 0.09), 0.04),
    ("thigh.L", "hips", bl(-0.07, 0.48, 0.0), bl(-0.08, 0.26, 0.01), 0.07),
    ("shin.L", "thigh.L", bl(-0.08, 0.26, 0.01), bl(-0.09, 0.05, -0.01), 0.055),
    ("foot.L", "shin.L", bl(-0.09, 0.05, -0.01), bl(-0.09, 0.0, 0.08), 0.04),
    ("thigh.R", "hips", bl(0.07, 0.48, 0.0), bl(0.075, 0.26, 0.01), 0.07),
    ("shin.R", "thigh.R", bl(0.075, 0.26, 0.01), bl(0.08, 0.05, -0.01), 0.055),
    ("foot.R", "shin.R", bl(0.08, 0.05, -0.01), bl(0.08, 0.0, 0.08), 0.04),
]

arm_data = bpy.data.armatures.new("KnightRig")
arm_obj = bpy.data.objects.new("KnightRig", arm_data)
bpy.context.scene.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode="EDIT")
for name, parent, head, tail, _ in BONES:
    bone = arm_data.edit_bones.new(name)
    bone.head, bone.tail = head, tail
    bone.roll = 0.0
    if parent:
        bone.parent = arm_data.edit_bones[parent]
        bone.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")

# --- ваги ---
names = [b[0] for b in BONES if b[4] > 0]
heads = np.array([[*b[2]] for b in BONES if b[4] > 0])
tails = np.array([[*b[3]] for b in BONES if b[4] > 0])
radii = np.array([b[4] for b in BONES if b[4] > 0])
seg = tails - heads
seg_len2 = (seg ** 2).sum(1)
rel = np.zeros((len(coords), len(names)))
for k in range(len(names)):
    t = np.clip(((coords - heads[k]) @ seg[k]) / seg_len2[k], 0.0, 1.0)
    nearest = heads[k] + t[:, None] * seg[k]
    rel[:, k] = np.linalg.norm(coords - nearest, axis=1) / radii[k]
weights = 1.0 / np.maximum(rel, 0.05) ** 6
order = np.argsort(-weights, axis=1)
keep = np.zeros_like(weights)
for r in range(3):
    idx = order[:, r]
    keep[np.arange(len(coords)), idx] = weights[np.arange(len(coords)), idx]
keep /= keep.sum(1, keepdims=True)
# Меч — одна сітка з тілом, тож вирізаємо його "капсулою" вздовж клинка:
# від руків'я в лівій кисті до вістря попереду-праворуч. Усе в ній — на
# лівій кисті цілком, інакше клинок тягнувся б за іншими кістками.
# (тут висота в метрах, не в частках H: точки зняті прямо з сітки)
grip, tip = np.array([-0.085, -0.115, 0.47]), np.array([0.21, -0.455, 0.235])
axis = tip - grip
t = np.clip(((coords - grip) @ axis) / (axis @ axis), -0.15, 1.0)
dist = np.linalg.norm(coords - (grip + t[:, None] * axis), axis=1)
sword = (dist < 0.035) & (coords[:, 1] < -0.09)
keep[sword] = 0.0
keep[sword, names.index("hand.L")] = 1.0
print("SWORD VERTS", int(sword.sum()))
# Ваги: спершу "тепловим" методом Blender (ARMATURE_AUTO) — він розуміє,
# де закінчується рука й починається плащ. Не впорався (вершини без ваг)
# — запасні ваги за відстанню (keep) вище.
# Згенерована сітка не замкнена — тепловий метод на ній не сходиться.
# Тому ваги рахуємо на замкненій копії (вокселі), а тоді переносимо на
# справжню сітку модифікатором Data Transfer.
proxy = mesh_obj.copy()
proxy.data = mesh_obj.data.copy()
bpy.context.scene.collection.objects.link(proxy)
remesh = proxy.modifiers.new("remesh", "REMESH")
remesh.mode = "VOXEL"
remesh.voxel_size = 0.009
bpy.ops.object.select_all(action="DESELECT")
proxy.select_set(True)
bpy.context.view_layer.objects.active = proxy
bpy.ops.object.modifier_apply(modifier="remesh")
dec = proxy.modifiers.new("dec", "DECIMATE")
dec.ratio = min(1.0, 40000 / max(1, len(proxy.data.polygons)))
bpy.ops.object.modifier_apply(modifier="dec")
print("PROXY faces", len(proxy.data.polygons))
proxy.select_set(True)
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
proxy_empty = sum(1 for v in proxy.data.vertices if not any(g.weight > 0.001 for g in v.groups))
print("PROXY unweighted", proxy_empty, "of", len(proxy.data.vertices))
for name in names + ["root"]:
    if mesh_obj.vertex_groups.get(name) is None:
        mesh_obj.vertex_groups.new(name=name)
transfer = mesh_obj.modifiers.new("transfer", "DATA_TRANSFER")
transfer.object = proxy
transfer.use_vert_data = True
transfer.data_types_verts = {"VGROUP_WEIGHTS"}
transfer.vert_mapping = "POLYINTERP_NEAREST"
transfer.layers_vgroup_select_src = "ALL"
transfer.layers_vgroup_select_dst = "NAME"
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.modifier_apply(modifier="transfer")
bpy.data.objects.remove(proxy, do_unlink=True)
unweighted = [v.index for v in mesh_obj.data.vertices
              if not any(g.weight > 0.001 for g in v.groups)]
print("HEAT unweighted", len(unweighted), "of", len(mesh_obj.data.vertices))
if len(unweighted) > len(mesh_obj.data.vertices) * 0.02:
    for g in list(mesh_obj.vertex_groups):
        mesh_obj.vertex_groups.remove(g)
    for k, name in enumerate(names):
        group = mesh_obj.vertex_groups.new(name=name)
        for i in np.nonzero(keep[:, k] > 0.01)[0]:
            group.add([int(i)], float(keep[i, k]), "REPLACE")
    print("WEIGHTS: fallback distance")
else:
    for i in unweighted:
        k = int(np.argmax(keep[i]))
        mesh_obj.vertex_groups[names[k]].add([i], 1.0, "REPLACE")
    # Корінь не деформує — його вагу віддаємо стегнам.
    root_group = mesh_obj.vertex_groups.get("root")
    if root_group is not None:
        hips_group = mesh_obj.vertex_groups["hips"]
        for v in mesh_obj.data.vertices:
            for g in v.groups:
                if g.group == root_group.index and g.weight > 0.0:
                    hips_group.add([v.index], g.weight, "ADD")
        mesh_obj.vertex_groups.remove(root_group)
    # Згладити межі між кістками: різкий перехід (сусідні вершини на різних
    # кістках) у позі розтягувався в довгі смуги.
    bpy.ops.object.select_all(action="DESELECT")
    mesh_obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_obj
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=4)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=3)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Кисті з руків'ям і меч — жорстко на кистях: перехід "кисть — стегно"
    # біля руків'я рвало в смугу, щойно рука піднімала меч.
    def rigid(bone_name, mask):
        ids = [int(i) for i in np.nonzero(mask)[0]]
        for g in mesh_obj.vertex_groups:
            if g.name != bone_name:
                g.remove(ids)
        mesh_obj.vertex_groups[bone_name].add(ids, 1.0, "REPLACE")
        return len(ids)
    def near_bone(bone_name, radius):
        k = [b[0] for b in BONES].index(bone_name)
        head, tail = np.array([*BONES[k][2]]), np.array([*BONES[k][3]])
        axis = tail - head
        t = np.clip(((coords - head) @ axis) / (axis @ axis), 0.0, 1.0)
        return np.linalg.norm(coords - (head + t[:, None] * axis), axis=1) < radius
    hand_rigid = sword | near_bone("hand.L", 0.06)
    print("RIGID hand.L", rigid("hand.L", hand_rigid))
    # Кисть із мечем зрослася з плащем на стегні (сітка суцільна). Решта
    # плаща не повинна "тягнутись" за рукою: з вершин, де головна кістка —
    # нога чи стегна, прибираємо вагу руки зовсім...
    arm_groups = {mesh_obj.vertex_groups[n].index for n in names if n.split(".")[0] in ("upperarm", "forearm", "hand")}
    leg_groups = {mesh_obj.vertex_groups[n].index for n in names if n.split(".")[0] in ("thigh", "shin", "foot", "hips")}
    lower = np.zeros(len(coords), bool)
    for v in mesh_obj.data.vertices:
        if hand_rigid[v.index] or not v.groups:
            continue
        main = max(v.groups, key=lambda g: g.weight).group
        if main in leg_groups:
            lower[v.index] = True
            for g in list(v.groups):
                if g.group in arm_groups:
                    mesh_obj.vertex_groups[g.group].remove([v.index])
    # Полотнища плаща між ногами (спереду й ззаду, |x| < 0.06 м) — не дошка
    # на стегні: висять від пояса, ноги лише трохи ведуть їх за собою.
    hips_g = mesh_obj.vertex_groups["hips"]
    thigh_l, thigh_r = mesh_obj.vertex_groups["thigh.L"], mesh_obj.vertex_groups["thigh.R"]
    panel = [i for i in np.nonzero(lower & (np.abs(coords[:, 0]) < 0.06) & (coords[:, 2] < 0.5))[0]]
    for i in panel:
        v = mesh_obj.data.vertices[int(i)]
        for g in list(v.groups):
            mesh_obj.vertex_groups[g.group].remove([int(i)])
        side = float(np.clip(coords[i, 0] / 0.06, -1.0, 1.0))
        hips_g.add([int(i)], 0.6, "REPLACE")
        thigh_l.add([int(i)], 0.2 * (1.0 - side), "REPLACE")
        thigh_r.add([int(i)], 0.2 * (1.0 + side), "REPLACE")
    print("ROBE panel verts", len(panel))
    # Піхви на правому стегні (нижче кисті, 0.30-0.44 м) теплові ваги
    # віддали правій руці — і вони махали разом з нею. Піхви висять на поясі.
    thigh_r_g = mesh_obj.vertex_groups["thigh.R"]
    right_arm = {mesh_obj.vertex_groups[n].index for n in ("upperarm.R", "forearm.R", "hand.R")}
    sheath = []
    for v in mesh_obj.data.vertices:
        if coords[v.index, 2] < 0.44 and coords[v.index, 0] > 0.1 and v.groups                 and max(v.groups, key=lambda g: g.weight).group in right_arm:
            sheath.append(v.index)
    for i in sheath:
        for g in list(mesh_obj.data.vertices[i].groups):
            mesh_obj.vertex_groups[g.group].remove([i])
        hips_g.add([i], 0.7, "REPLACE")
        thigh_r_g.add([i], 0.3, "REPLACE")
    print("SHEATH verts", len(sheath))
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    # ...а грані, що зшивають кисть із плащем, вирізаємо: у спокої їх
    # закриває сама кисть, а піднята рука вже не тягне за собою смугу.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh_obj.data)
    seam = [f for f in bm.faces if any(hand_rigid[v.index] for v in f.verts) and any(lower[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=seam, context="FACES_ONLY")
    bm.to_mesh(mesh_obj.data)
    bm.free()
    print("SEAM faces removed", len(seam))
    print("WEIGHTS: heat")
mesh_obj.parent = arm_obj
armature_mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
armature_mod.object = arm_obj

# --- анімації ---
REST = {b.name: b.matrix_local.to_quaternion() for b in arm_data.bones}
AXES = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}

def local_rotation(bone, spec):
    """spec — {"x": градуси, ...}: поворот навколо осей арматури в позі спокою."""
    q = Quaternion()
    for axis in ("z", "y", "x"):
        if axis in spec:
            q = Quaternion(AXES[axis], math.radians(spec[axis])) @ q
    rest = REST[bone]
    return rest.inverted() @ q @ rest

def make_action(name, length, keys, loop=False):
    """keys: {кадр: {кістка: {"x": .., "y": .., "z": .., "loc": (x, y, z)}}}.
    Кістки без ключа в кадрі — у спокої."""
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm_obj.animation_data_create()
    arm_obj.animation_data.action = action
    frames = sorted(keys)
    if loop and frames[-1] != length:
        keys[length] = keys[frames[0]]
        frames.append(length)
    for frame in frames:
        for pb in arm_obj.pose.bones:
            spec = keys[frame].get(pb.name, {})
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = local_rotation(pb.name, spec)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            if pb.name == "root":
                offset = Vector(spec.get("loc", (0, 0, 0)))
                pb.location = REST["root"].inverted() @ offset
                pb.keyframe_insert("location", frame=frame)
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, frames[0], action)
    arm_obj.animation_data.action = None
    print("ACTION", name, frames[-1], "кадрів")

# Знаки: нахил уперед хребта — +x; нога/рука вперед — -x (вони звисають).
# Права рука (з мечем) — "R", ліва — "L".
make_action("Idle", 60, {
    0: {"chest": {"x": 1}, "head": {"x": 2}, "upperarm.L": {"y": 2}, "upperarm.R": {"y": -2}},
    30: {"chest": {"x": -2}, "spine": {"x": 1}, "head": {"x": -1, "z": 4},
         "upperarm.L": {"y": 5}, "upperarm.R": {"y": -4}, "root": {"loc": (0, 0, -0.004)}},
}, loop=True)

def walk_pose(phase):
    s = math.sin(phase)
    c = math.cos(phase)
    return {
        "thigh.L": {"x": -20 * s}, "thigh.R": {"x": 20 * s},
        "shin.L": {"x": 26 * max(0.0, -s) + 5}, "shin.R": {"x": 26 * max(0.0, s) + 5},
        "foot.L": {"x": -10 * s}, "foot.R": {"x": 10 * s},
        "upperarm.L": {"x": 22 * s, "y": 4}, "upperarm.R": {"x": -10 * s, "y": -4},
        "forearm.L": {"x": -12}, "forearm.R": {"x": -18},
        "spine": {"z": 6 * s, "x": 4}, "chest": {"z": -5 * s},
        "root": {"loc": (0, 0, -0.012 * abs(c) * H)},
    }
make_action("Walk", 32, {f: walk_pose(f / 32 * math.tau) for f in range(0, 32, 4)}, loop=True)

# Поворот на місці: переступає з ноги на ногу.
def turn_pose(phase):
    s = math.sin(phase)
    return {"thigh.L": {"x": -10 * max(0.0, s), "z": 8 * s}, "thigh.R": {"x": 10 * max(0.0, -s), "z": 8 * s},
            "shin.L": {"x": 18 * max(0.0, s)}, "shin.R": {"x": 18 * max(0.0, -s)},
            "spine": {"z": 10 * s}, "upperarm.L": {"x": 8 * s}, "upperarm.R": {"x": -6 * s},
            "root": {"loc": (0, 0, -0.008 * abs(s) * H)}}
make_action("Turn", 24, {f: turn_pose(f / 24 * math.tau) for f in range(0, 24, 4)}, loop=True)

make_action("Weapon", 26, {
    0: {},
    9: {"upperarm.L": {"x": -150, "y": 20}, "forearm.L": {"x": -40}, "hand.L": {"x": 20},
        "chest": {"z": -25, "x": -6}, "spine": {"z": -10}, "upperarm.R": {"x": -25, "y": -15},
        "thigh.R": {"x": -15}, "thigh.L": {"x": 10}},
    14: {"upperarm.L": {"x": -40, "y": -15}, "forearm.L": {"x": -10}, "hand.L": {"x": -30},
         "chest": {"z": 25, "x": 18}, "spine": {"z": 10, "x": 8}, "upperarm.R": {"x": 15},
         "thigh.R": {"x": -25}, "shin.R": {"x": 20}, "thigh.L": {"x": 15}, "root": {"loc": (0, 0, -0.03 * H)}},
    20: {"upperarm.L": {"x": -35, "y": -10}, "chest": {"z": 12, "x": 10}, "thigh.R": {"x": -15},
         "root": {"loc": (0, 0, -0.015 * H)}},
    26: {},
})

make_action("Cast", 36, {
    0: {},
    8: {"upperarm.L": {"x": -95, "y": 20}, "upperarm.R": {"x": -95, "y": -20},
        "forearm.L": {"x": -25}, "forearm.R": {"x": -25}, "chest": {"x": -10}, "head": {"x": -12}},
    16: {"upperarm.L": {"x": -150, "y": 30}, "upperarm.R": {"x": -150, "y": -30},
         "forearm.L": {"x": -15}, "forearm.R": {"x": -15}, "chest": {"x": -14}, "head": {"x": -18},
         "root": {"loc": (0, 0, 0.01 * H)}},
    24: {"upperarm.L": {"x": -70, "y": 10}, "upperarm.R": {"x": -70, "y": -10},
         "forearm.L": {"x": -5}, "forearm.R": {"x": -5}, "chest": {"x": 16}, "spine": {"x": 8},
         "thigh.L": {"x": -20}, "shin.L": {"x": 15}, "root": {"loc": (0, 0, -0.03 * H)}},
    36: {},
})

make_action("Jump", 26, {
    0: {},
    6: {"thigh.L": {"x": -45}, "thigh.R": {"x": -45}, "shin.L": {"x": 80}, "shin.R": {"x": 80},
        "foot.L": {"x": -30}, "foot.R": {"x": -30}, "spine": {"x": 20}, "upperarm.L": {"x": 30},
        "upperarm.R": {"x": 30}, "root": {"loc": (0, 0, -0.12 * H)}},
    12: {"thigh.L": {"x": -10}, "thigh.R": {"x": 15}, "shin.L": {"x": 20}, "shin.R": {"x": 30},
         "upperarm.L": {"x": -120}, "upperarm.R": {"x": -130}, "spine": {"x": -8}},
    20: {"thigh.L": {"x": -40}, "thigh.R": {"x": -40}, "shin.L": {"x": 70}, "shin.R": {"x": 70},
         "spine": {"x": 22}, "upperarm.R": {"x": -40}, "root": {"loc": (0, 0, -0.1 * H)}},
    26: {},
})

make_action("HitReact", 14, {
    0: {},
    4: {"chest": {"x": -16, "z": 8}, "head": {"x": -14}, "spine": {"x": -6},
        "upperarm.L": {"x": 20, "y": 15}, "upperarm.R": {"x": 15, "y": -12}},
    14: {},
})

make_action("Death", 50, {
    0: {},
    10: {"chest": {"x": -20, "z": 12}, "head": {"x": -20}, "upperarm.L": {"x": 20, "y": 35},
         "upperarm.R": {"x": 10, "y": -35}, "spine": {"x": -8}},
    22: {"thigh.L": {"x": -55}, "thigh.R": {"x": -40}, "shin.L": {"x": 95}, "shin.R": {"x": 80},
         "spine": {"x": 15}, "chest": {"x": 10}, "head": {"x": 25}, "upperarm.L": {"x": 10, "y": 20},
         "upperarm.R": {"x": 5, "y": -20}, "root": {"loc": (0, 0, -0.2 * H)}},
    38: {"root": {"x": -80, "loc": (0, 0.05 * H, -0.05 * H)}, "thigh.L": {"x": -30}, "shin.L": {"x": 40},
         "upperarm.L": {"y": 50}, "upperarm.R": {"y": -50}, "head": {"x": -20}},
    50: {"root": {"x": -88, "loc": (0, 0.06 * H, -0.06 * H)}, "thigh.L": {"x": -20}, "shin.L": {"x": 25},
         "upperarm.L": {"y": 60}, "upperarm.R": {"y": -60}, "head": {"x": -25}},
})

# --- текстури й експорт ---
for image in bpy.data.images:
    if image.size[0] > 1024:
        image.scale(1024, 1024)
bpy.ops.object.select_all(action="DESELECT")
arm_obj.select_set(True)
mesh_obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_skins=True, export_image_format="AUTO", export_yup=True)
print("EXPORTED", DST)
