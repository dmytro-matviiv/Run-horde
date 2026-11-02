# -*- coding: utf-8 -*-
"""Склепний чаклун (модель гравця з Rodin, без скелета). Той самий конвеєр,
що rig_final.py: суглоби за силуетом (у метрах, А-поза), теплові ваги на
вокселях, а щит (ліве передпліччя) і булава (права кисть) — тверді.
Анімації: Idle, Walk, Run/Charge (таран зі щитом уперед), Weapon (булавою
зверху), Weapon2 (удар щитом), Stunned (оглушений після стіни), Block,
HitReact, Death.

  blender -b --factory-startup -P rig_shield_orc.py -- <вхід.glb> <вихід.glb>
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = argv[0], argv[1]
TARGET_TRIS = 7000
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
mesh_obj.name = "CryptWarlock"

tris = sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons)
mod = mesh_obj.modifiers.new("decimate", "DECIMATE")
mod.ratio = min(1.0, TARGET_TRIS / tris)
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
print("TRIS", tris, "->", sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons))

coords = np.array([v.co[:] for v in mesh_obj.data.vertices])
H = float(coords[:, 2].max())
print("HEIGHT", H)

# --- скелет (у метрах; "гра": x — убік, y — вгору, z — уперед).
# Blender: (x, -z, y). Права рука — на +x.
def bl(x, y, z):
    return Vector((x, -z, y))

# Згорблений чаклун: голова й груди подані вперед, горб ззаду. Посох
# (права рука) — на -x, ліва рука (чари) — на +x, витягнута вперед.
CX = 0.03
BONES = [
    ("root", None, bl(CX, 0.0, 0), bl(CX, 0.12, 0), 0.0),
    ("hips", "root", bl(CX, 0.80, 0.0), bl(CX, 1.00, 0.0), 0.24),
    ("spine", "hips", bl(CX, 1.00, 0.0), bl(CX, 1.20, -0.02), 0.26),
    ("chest", "spine", bl(CX, 1.20, -0.02), bl(0.0, 1.45, 0.02), 0.28),
    ("neck", "chest", bl(0.0, 1.45, 0.02), bl(-0.03, 1.55, 0.08), 0.12),
    ("head", "neck", bl(-0.03, 1.55, 0.08), bl(-0.05, 1.85, 0.12), 0.20),
    ("upperarm.R", "chest", bl(-0.28, 1.38, 0.0), bl(-0.40, 1.10, 0.0), 0.10),
    ("forearm.R", "upperarm.R", bl(-0.40, 1.10, 0.0), bl(-0.47, 0.95, 0.0), 0.09),
    ("hand.R", "forearm.R", bl(-0.47, 0.95, 0.0), bl(-0.62, 0.95, 0.0), 0.08),
    ("upperarm.L", "chest", bl(0.36, 1.36, 0.0), bl(0.50, 1.12, 0.05), 0.10),
    ("forearm.L", "upperarm.L", bl(0.50, 1.12, 0.05), bl(0.58, 0.98, 0.18), 0.09),
    ("hand.L", "forearm.L", bl(0.58, 0.98, 0.18), bl(0.72, 0.95, 0.28), 0.09),
    ("thigh.R", "hips", bl(-0.12, 0.80, 0.0), bl(-0.15, 0.42, -0.05), 0.14),
    ("shin.R", "thigh.R", bl(-0.15, 0.42, -0.05), bl(-0.18, 0.08, -0.10), 0.12),
    ("foot.R", "shin.R", bl(-0.18, 0.08, -0.10), bl(-0.19, 0.0, 0.02), 0.10),
    ("thigh.L", "hips", bl(0.22, 0.80, 0.0), bl(0.28, 0.42, 0.05), 0.14),
    ("shin.L", "thigh.L", bl(0.28, 0.42, 0.05), bl(0.30, 0.08, 0.0), 0.12),
    ("foot.L", "shin.L", bl(0.30, 0.08, 0.0), bl(0.30, 0.0, 0.14), 0.10),
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
sword = np.zeros(len(coords), bool)
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
remesh.voxel_size = 0.02
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
if len(unweighted) > len(mesh_obj.data.vertices) * 0.1:
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
    print("WEIGHTS: heat")
# Згладжування меж і тверді щит та булава — для будь-яких ваг.
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=3)
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
# Посох — цілком на правій кисті.
x = coords[:, 0]
staff = (x < -0.53) | near_bone("hand.R", 0.08)
print("RIGID staff", rigid("hand.R", staff))
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

# Знаки: нахил уперед хребта — +x; рука/нога вперед — -x. Права рука
# (посох) на -x, ліва (чари) на +x.
STOOP = {"spine": {"x": 4}, "head": {"x": -4}}


def pose(extra, base=None):
    base = STOOP if base is None else base
    out = {k: dict(v) for k, v in base.items()}
    for bone, spec in extra.items():
        merged = dict(out.get(bone, {}))
        for axis, value in spec.items():
            merged[axis] = merged.get(axis, 0) + value if axis != "loc" else value
        out[bone] = merged
    return out


# Стійка: важко дихає, ліва рука з чарами ледь поводить.
make_action("Idle", 70, {
    0: pose({"chest": {"x": 3}, "upperarm.L": {"x": -4}, "forearm.L": {"z": 4}}),
    35: pose({"chest": {"x": -2}, "head": {"z": 6, "x": -3}, "upperarm.L": {"x": -10, "y": 6},
              "forearm.L": {"z": -6}, "root": {"loc": (0, 0, -0.015)}}),
}, loop=True)


def walk_pose(phase, stride):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({
        "thigh.L": {"x": -stride * s}, "thigh.R": {"x": stride * s},
        "shin.L": {"x": stride * max(0.0, -s) + 4}, "shin.R": {"x": stride * max(0.0, s) + 4},
        "upperarm.L": {"x": 12 * s}, "upperarm.R": {"x": -6 * s},
        "spine": {"z": 5 * s, "x": 4}, "chest": {"z": -4 * s}, "head": {"z": 3 * s},
        "root": {"loc": (0, 0, -0.02 * abs(c))},
    })


# Шаркає: короткий крок, посох іде разом із рукою.
make_action("Walk", 36, {f: walk_pose(f / 36 * math.tau, 16) for f in range(0, 36, 4)}, loop=True)
make_action("Run", 24, {f: walk_pose(f / 24 * math.tau, 26) for f in range(0, 24, 3)}, loop=True)

# Чари стрілою: ліва долоня різко вперед.
make_action("Weapon", 24, {
    0: pose({}),
    8: pose({"upperarm.L": {"x": 25, "y": -10}, "forearm.L": {"x": -40}, "chest": {"z": 14}}),
    12: pose({"upperarm.L": {"x": -70, "y": 10}, "forearm.L": {"x": 10}, "chest": {"z": -14, "x": 6},
              "head": {"x": -4}}),
    18: pose({"upperarm.L": {"x": -60, "y": 8}, "forearm.L": {"x": 5}, "chest": {"z": -8}}),
    24: pose({}),
})

# Підняття кісток: посох угору — і з силою в підлогу, ліва рука вгору.
make_action("Cast", 36, {
    0: pose({}),
    10: pose({"upperarm.R": {"x": -28, "y": -6}, "forearm.R": {"x": -12}, "upperarm.L": {"x": -80, "y": 25},
              "forearm.L": {"x": -20}, "chest": {"x": -14}, "spine": {"x": -6}, "head": {"x": -14}}),
    16: pose({"upperarm.R": {"x": -10}, "forearm.R": {"x": -5}, "upperarm.L": {"x": -30, "y": 10},
              "chest": {"x": 16}, "spine": {"x": 10}, "head": {"x": 8}, "thigh.R": {"x": -15}, "shin.R": {"x": 20},
              "root": {"loc": (0, 0, -0.07)}}),
    26: pose({"upperarm.R": {"x": -12}, "chest": {"x": 12}, "spine": {"x": 8}, "root": {"loc": (0, 0, -0.05)}}),
    36: pose({}),
})

# Темний щит: ліва рука простягнута вбік-уперед, тримає чари.
make_action("Support", 36, {
    0: pose({}),
    8: pose({"upperarm.L": {"x": -55, "y": -20}, "forearm.L": {"x": 10}, "chest": {"z": -12}, "head": {"z": -10}}),
    26: pose({"upperarm.L": {"x": -60, "y": -24}, "forearm.L": {"x": 14}, "chest": {"z": -14, "x": -4},
              "head": {"z": -12}}),
    36: pose({}),
})

make_action("HitReact", 14, {
    0: pose({}),
    4: pose({"chest": {"x": -14, "z": -8}, "head": {"x": -12}, "spine": {"x": -6},
             "upperarm.L": {"x": 20, "y": -10}}),
    14: pose({}),
})

# Смерть: осідає на коліна — і падає ниць.
make_action("Death", 60, {
    0: pose({}),
    12: pose({"chest": {"x": 14}, "head": {"x": 16}, "upperarm.L": {"x": -30, "y": 20}, "forearm.L": {"x": -60}}),
    28: pose({"thigh.L": {"x": -80}, "thigh.R": {"x": -80}, "shin.L": {"x": 140}, "shin.R": {"x": 140},
              "foot.L": {"x": -40}, "foot.R": {"x": -40}, "chest": {"x": 20}, "head": {"x": 20},
              "root": {"loc": (0, 0, -0.30)}}),
    46: pose({"root": {"x": 60, "loc": (0, 0, -0.08)}, "thigh.L": {"x": -50}, "thigh.R": {"x": -50},
              "shin.L": {"x": 90}, "shin.R": {"x": 90}, "upperarm.L": {"x": -60}, "head": {"x": -10}}),
    60: pose({"root": {"x": 82, "loc": (0, 0, 0.0)}, "thigh.L": {"x": -20}, "thigh.R": {"x": -20},
              "shin.L": {"x": 30}, "shin.R": {"x": 30}, "upperarm.L": {"x": -90}, "head": {"x": -15}}),
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
