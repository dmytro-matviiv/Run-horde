# -*- coding: utf-8 -*-
"""Хранитель Склепів, бос 1-го данжу (модель гравця з Rodin, без скелета). Той самий конвеєр,
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
TARGET_TRIS = 12000
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
mesh_obj.name = "CryptKeeper"

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

# Хранитель Склепів: центр тіла на x = 0.16; молот-надгробок у правій руці
# (-x), ліва рука (+x) з ланцюгом ключів опущена вздовж тіла.
CX = 0.16
BONES = [
    ("root", None, bl(CX, 0.0, 0), bl(CX, 0.12, 0), 0.0),
    ("hips", "root", bl(CX, 0.72, 0.0), bl(CX, 0.95, 0.0), 0.30),
    ("spine", "hips", bl(CX, 0.95, 0.0), bl(CX, 1.18, 0.0), 0.32),
    ("chest", "spine", bl(CX, 1.18, 0.0), bl(CX, 1.42, 0.02), 0.34),
    ("neck", "chest", bl(CX, 1.42, 0.02), bl(0.14, 1.55, 0.05), 0.14),
    ("head", "neck", bl(0.14, 1.55, 0.05), bl(0.13, 1.85, 0.08), 0.20),
    ("upperarm.R", "chest", bl(-0.12, 1.38, 0.0), bl(-0.33, 1.12, 0.02), 0.13),
    ("forearm.R", "upperarm.R", bl(-0.33, 1.12, 0.02), bl(-0.47, 0.95, 0.06), 0.12),
    ("hand.R", "forearm.R", bl(-0.47, 0.95, 0.06), bl(-0.52, 0.88, 0.08), 0.10),
    ("upperarm.L", "chest", bl(0.48, 1.38, 0.0), bl(0.66, 1.08, 0.0), 0.13),
    ("forearm.L", "upperarm.L", bl(0.66, 1.08, 0.0), bl(0.74, 0.82, 0.02), 0.12),
    ("hand.L", "forearm.L", bl(0.74, 0.82, 0.02), bl(0.76, 0.62, 0.03), 0.11),
    ("thigh.R", "hips", bl(-0.04, 0.72, 0.0), bl(-0.08, 0.38, 0.0), 0.17),
    ("shin.R", "thigh.R", bl(-0.08, 0.38, 0.0), bl(-0.10, 0.10, 0.0), 0.14),
    ("foot.R", "shin.R", bl(-0.10, 0.10, 0.0), bl(-0.10, 0.0, 0.18), 0.12),
    ("thigh.L", "hips", bl(0.38, 0.72, 0.0), bl(0.42, 0.38, 0.0), 0.17),
    ("shin.L", "thigh.L", bl(0.42, 0.38, 0.0), bl(0.43, 0.10, 0.0), 0.14),
    ("foot.L", "shin.L", bl(0.43, 0.10, 0.0), bl(0.43, 0.0, 0.18), 0.12),
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
# Молот-надгробок (держак і голова) — цілком на правій кисті.
x = coords[:, 0]
hammer = (x < -0.44) | near_bone("hand.R", 0.1)
print("RIGID hammer", rigid("hand.R", hammer))
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
# (молот-надгробок) на -x, ліва (ланцюг із ключами) на +x.
STANCE = {"thigh.L": {"x": -4}, "thigh.R": {"x": 4}, "shin.L": {"x": 6}, "shin.R": {"x": 6}}


def pose(extra, base=None):
    base = STANCE if base is None else base
    out = {k: dict(v) for k, v in base.items()}
    for bone, spec in extra.items():
        merged = dict(out.get(bone, {}))
        for axis, value in spec.items():
            merged[axis] = merged.get(axis, 0) + value if axis != "loc" else value
        out[bone] = merged
    return out


make_action("Idle", 70, {
    0: pose({"chest": {"x": 2}, "root": {"loc": (0, 0, -0.01)}}),
    35: pose({"chest": {"x": -2}, "head": {"z": 6}, "upperarm.L": {"y": 4}, "root": {"loc": (0, 0, -0.03)}}),
}, loop=True)


def walk_pose(phase, stride, lean):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({
        "thigh.L": {"x": -stride * s}, "thigh.R": {"x": stride * s},
        "shin.L": {"x": stride * max(0.0, -s) + 6}, "shin.R": {"x": stride * max(0.0, s) + 6},
        "foot.L": {"x": -6 * s}, "foot.R": {"x": 6 * s},
        "upperarm.L": {"x": 14 * s}, "upperarm.R": {"x": -5 * s},
        "spine": {"z": 6 * s, "x": lean}, "chest": {"z": -5 * s}, "head": {"z": 3 * s},
        "root": {"loc": (0, 0, -0.035 * abs(c))},
    }, {})


# Важка хода: короткий крок, корпус перевалюється.
make_action("Walk", 40, {f: walk_pose(f / 40 * math.tau, 18, 3) for f in range(0, 40, 4)}, loop=True)
make_action("Run", 26, {f: walk_pose(f / 26 * math.tau, 30, 10) for f in range(0, 26, 2)}, loop=True)

# Звичайний удар: молот з-за плеча навскіс.
make_action("Weapon", 30, {
    0: pose({}),
    10: pose({"upperarm.R": {"x": -110, "y": -25}, "forearm.R": {"x": -55}, "chest": {"z": 25, "x": -6},
              "spine": {"z": 10}}),
    15: pose({"upperarm.R": {"x": -40, "y": 20}, "forearm.R": {"x": -10}, "chest": {"z": -25, "x": 14},
              "spine": {"z": -10, "x": 8}, "thigh.R": {"x": -18}, "shin.R": {"x": 18}, "root": {"loc": (0, 0, -0.06)}}),
    22: pose({"upperarm.R": {"x": -30, "y": 15}, "chest": {"z": -15, "x": 10}, "root": {"loc": (0, 0, -0.04)}}),
    30: pose({}),
})

# Удар надгробком: обома руками над головою — і з присідом об підлогу.
make_action("Slam", 44, {
    0: pose({}),
    16: pose({"upperarm.R": {"x": -165, "y": 10}, "forearm.R": {"x": -40}, "upperarm.L": {"x": -150, "y": -25},
              "forearm.L": {"x": -50}, "chest": {"x": -16}, "spine": {"x": -8}, "head": {"x": -10},
              "root": {"loc": (0, 0, 0.02)}}),
    22: pose({"upperarm.R": {"x": -55, "y": 10}, "forearm.R": {"x": -5}, "upperarm.L": {"x": -55, "y": -15},
              "forearm.L": {"x": -10}, "chest": {"x": 30}, "spine": {"x": 18}, "head": {"x": 10},
              "thigh.L": {"x": -35}, "thigh.R": {"x": -35}, "shin.L": {"x": 50}, "shin.R": {"x": 50},
              "root": {"loc": (0, 0, -0.18)}}),
    34: pose({"upperarm.R": {"x": -50}, "upperarm.L": {"x": -45, "y": -10}, "chest": {"x": 26}, "spine": {"x": 15},
              "thigh.L": {"x": -30}, "thigh.R": {"x": -30}, "shin.L": {"x": 45}, "shin.R": {"x": 45},
              "root": {"loc": (0, 0, -0.16)}}),
    44: pose({}),
})

# Обертання ланцюгом: ліва рука витягнута вбік, корпус крутиться по колу.
def spin_pose(phase):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({"upperarm.L": {"y": -70, "x": -20 * c}, "forearm.L": {"x": -10},
                 "spine": {"z": 22 * s}, "chest": {"z": 22 * s}, "head": {"z": -10 * s},
                 "thigh.L": {"x": -10}, "thigh.R": {"x": -10}, "shin.L": {"x": 15}, "shin.R": {"x": 15},
                 "root": {"loc": (0, 0, -0.05)}})


make_action("Spin", 24, {f: spin_pose(f / 24 * math.tau) for f in range(0, 24, 3)}, loop=True)

# Відмикає саркофаг: нахилився до стіни, ліва рука крутить ключ.
def unlock_pose(phase):
    s = math.sin(phase)
    return pose({"spine": {"x": 22}, "chest": {"x": 10}, "head": {"x": 8},
                 "upperarm.L": {"x": -70, "y": -5}, "forearm.L": {"x": -30, "y": 40 * s},
                 "upperarm.R": {"x": 10, "y": -10}, "thigh.L": {"x": -25}, "shin.L": {"x": 30},
                 "thigh.R": {"x": 10}, "root": {"loc": (0, 0, -0.08)}})


make_action("Unlock", 30, {f: unlock_pose(f / 30 * math.tau) for f in range(0, 30, 5)}, loop=True)

# Рев: присів, стиснувся — і розпрямився з руками в боки.
make_action("Roar", 50, {
    0: pose({}),
    12: pose({"upperarm.L": {"x": -30, "y": 25}, "upperarm.R": {"x": -30, "y": -25}, "forearm.L": {"x": -80},
              "forearm.R": {"x": -80}, "chest": {"x": 28}, "spine": {"x": 15}, "head": {"x": 20},
              "thigh.L": {"x": -28}, "thigh.R": {"x": -28}, "shin.L": {"x": 40}, "shin.R": {"x": 40},
              "root": {"loc": (0, 0, -0.14)}}),
    24: pose({"upperarm.L": {"y": -70, "x": -40}, "upperarm.R": {"y": 70, "x": -40}, "forearm.L": {"x": -10},
              "forearm.R": {"x": -10}, "chest": {"x": -22}, "spine": {"x": -8}, "head": {"x": -30}}),
    38: pose({"upperarm.L": {"y": -65, "x": -35}, "upperarm.R": {"y": 65, "x": -35}, "chest": {"x": -20},
              "head": {"x": -28, "z": 6}}),
    50: pose({}),
})

# Кидок свічки з плеча: ліва рука знизу вгору вперед.
make_action("Throw", 26, {
    0: pose({}),
    8: pose({"upperarm.L": {"x": 30, "y": -10}, "forearm.L": {"x": -60}, "chest": {"z": -15}}),
    13: pose({"upperarm.L": {"x": -120, "y": -10}, "forearm.L": {"x": -10}, "chest": {"z": 18, "x": 6}}),
    20: pose({"upperarm.L": {"x": -90}, "chest": {"z": 8}}),
    26: pose({}),
})

make_action("HitReact", 14, {
    0: pose({}),
    4: pose({"chest": {"x": -12, "z": 8}, "head": {"x": -12}, "spine": {"x": -5}}),
    14: pose({}),
})

# Смерть (як у щитоносця): хитнувся назад — і важко, як колода, ниць.
LIMP = {"upperarm.L": {"x": 5, "y": 10}, "forearm.L": {"x": -10},
        "upperarm.R": {"x": 5, "y": -12}, "forearm.R": {"x": -10},
        "spine": {"x": 14}, "chest": {"x": 8}, "thigh.L": {"x": -12}, "thigh.R": {"x": -8},
        "shin.L": {"x": 20}, "shin.R": {"x": 16}}
make_action("Death", 56, {
    0: pose({}),
    10: pose({"chest": {"x": -14}, "head": {"x": -20}, "spine": {"x": -6}, "upperarm.L": {"x": 15},
              "upperarm.R": {"x": 20, "y": 5}}),
    22: pose({"root": {"x": 25}, "chest": {"x": 6}, "head": {"x": 8}}, LIMP),
    38: pose({"root": {"x": 84, "loc": (0, 0, 0.02)}, "upperarm.L": {"x": -30},
              "upperarm.R": {"x": -40, "y": 15}, "head": {"x": -25}}, LIMP),
    46: pose({"root": {"x": 80, "loc": (0, 0, 0.05)}, "upperarm.L": {"x": -35},
              "upperarm.R": {"x": -45, "y": 15}, "head": {"x": -20}}, LIMP),
    56: pose({"root": {"x": 84, "loc": (0, 0, 0.02)}, "upperarm.L": {"x": -30},
              "upperarm.R": {"x": -40, "y": 15}, "head": {"x": -22}}, LIMP),
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
