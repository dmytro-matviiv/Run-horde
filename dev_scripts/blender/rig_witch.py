# -*- coding: utf-8 -*-
"""Інейна чаклунка (модель гравця з Rodin; свій скелет замість Rodin — там
посох і поли мантії розмазувались). Конвеєр rig_warlock.py: суглоби за
силуетом, теплові ваги на вокселях, посох (права кисть) — твердий за
вузькою маскою (лише древко й кристал, без мантії).
Анімації: Idle, Walk, Run, Weapon (списи лівою), Cast (посох угору — і в
підлогу), Support (чари вперед), Channel (ульта: посох угору, петля),
HitReact, Death.

  blender -b --factory-startup -P rig_witch.py -- <вхід.glb> <вихід.glb>
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
mesh_obj = max((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: len(o.data.polygons))
mesh_obj.modifiers.clear()
mesh_obj.parent = None
for g in list(mesh_obj.vertex_groups):
    mesh_obj.vertex_groups.remove(g)
for o in list(bpy.context.scene.objects):
    if o is not mesh_obj:
        bpy.data.objects.remove(o, do_unlink=True)
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
for o in bpy.context.scene.objects:
    o.select_set(False)
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mesh_obj.name = "FrostWitch"

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

# Чаклунка в мантії: посох у правій руці (на -x) стоїть древком на підлозі,
# ліва рука трохи відведена. Суглоби — з її скелета Rodin.
BONES = [
    ("root", None, bl(0, 0.0, 0.1), bl(0, 0.12, 0.1), 0.0),
    ("hips", "root", bl(-0.01, 1.00, 0.11), bl(-0.01, 1.22, 0.10), 0.24),
    ("spine", "hips", bl(-0.01, 1.22, 0.10), bl(-0.01, 1.32, 0.09), 0.22),
    ("chest", "spine", bl(-0.01, 1.32, 0.09), bl(-0.01, 1.43, 0.09), 0.22),
    ("neck", "chest", bl(-0.01, 1.43, 0.09), bl(-0.01, 1.51, 0.08), 0.09),
    ("head", "neck", bl(-0.01, 1.51, 0.08), bl(-0.01, 1.86, 0.08), 0.16),
    ("upperarm.R", "chest", bl(-0.18, 1.36, 0.09), bl(-0.28, 1.20, 0.09), 0.08),
    ("forearm.R", "upperarm.R", bl(-0.28, 1.20, 0.09), bl(-0.45, 1.04, 0.20), 0.07),
    ("hand.R", "forearm.R", bl(-0.45, 1.04, 0.20), bl(-0.46, 1.24, 0.19), 0.06),
    ("upperarm.L", "chest", bl(0.16, 1.36, 0.09), bl(0.26, 1.19, 0.10), 0.08),
    ("forearm.L", "upperarm.L", bl(0.26, 1.19, 0.10), bl(0.43, 1.17, 0.15), 0.07),
    ("hand.L", "forearm.L", bl(0.43, 1.17, 0.15), bl(0.53, 1.17, 0.17), 0.06),
    ("thigh.R", "hips", bl(-0.11, 1.01, 0.09), bl(-0.18, 0.56, 0.06), 0.15),
    ("shin.R", "thigh.R", bl(-0.18, 0.56, 0.06), bl(-0.17, 0.09, -0.01), 0.14),
    ("foot.R", "shin.R", bl(-0.17, 0.09, -0.01), bl(-0.17, 0.03, 0.29), 0.09),
    ("thigh.L", "hips", bl(0.10, 1.01, 0.10), bl(0.13, 0.56, 0.07), 0.15),
    ("shin.L", "thigh.L", bl(0.13, 0.56, 0.07), bl(0.12, 0.10, 0.06), 0.14),
    ("foot.L", "shin.L", bl(0.12, 0.10, 0.06), bl(0.13, 0.03, 0.34), 0.09),
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
# Посох — цілком на правій кисті, але лише за вузькою маскою: древко
# (ледь похиле, ~3.5 см завтовшки) і кристал угорі. Широка коробка раніше
# захоплювала поли мантії й рукав — їх тягнуло разом із посохом.
x, y, z = coords[:, 0], coords[:, 1], coords[:, 2]
shaft_y = -0.16 - 0.045 * np.minimum(z, 1.0)
shaft = (np.abs(x + 0.465) < 0.04) & (np.abs(y - shaft_y) < 0.05)
crystal = (z > 1.45) & (x < -0.34) & (y < -0.14)
# Окуття внизу древка ширше; мантія тут лише позаду (y > -0.10).
foot = (z < 0.16) & (np.abs(x + 0.46) < 0.06) & (y < -0.105) & (y > -0.24)
staff = shaft | crystal | foot | near_bone("hand.R", 0.05)
print("RIGID staff", rigid("hand.R", staff))
# Низ древка в сітці зварений з полою мантії: коли посох піднімається,
# спільні трикутники тягнулись у довгу смугу. Ріжемо стик (лише грані,
# вершини лишаються — індекси не зсуваються).
import bmesh
bm = bmesh.new()
bm.from_mesh(mesh_obj.data)
bm.verts.ensure_lookup_table()
cut = [f for f in bm.faces
       if len({bool(staff[v.index]) for v in f.verts}) == 2 and f.calc_center_median().z < 0.9]
bmesh.ops.delete(bm, geom=cut, context="FACES_ONLY")
bm.to_mesh(mesh_obj.data)
bm.free()
print("CUT staff seam faces", len(cut))
# Руки не тягнуть волосся й мантію позаду та внизу (теплові ваги туди
# "протекли"), голова — тулуб. Не різко (різкий зріз рвав сітку), а плавно:
# вагу кістки множимо на коефіцієнт 0..1 (решта кісток після нормалізації
# беруть більше); вершині, якій нічого не лишилось, — запасна кістка.
def soft_drop(bone_names, keep_factor, receiver):
    receiver_group = mesh_obj.vertex_groups[receiver]
    index = {mesh_obj.vertex_groups[n].index: n for n in bone_names}
    for v in mesh_obj.data.vertices:
        if staff[v.index] or keep_factor[v.index] >= 0.999:
            continue
        moved = 0.0
        for g in v.groups:
            if g.group in index:
                moved += g.weight * (1.0 - keep_factor[v.index])
                g.weight *= keep_factor[v.index]
        if moved > 0.0 and sum(g.weight for g in v.groups) < 0.05:
            receiver_group.add([v.index], moved, "ADD")
arm_keep = np.clip((0.06 - y) / 0.08, 0.0, 1.0) * np.clip((z - 0.8) / 0.25, 0.0, 1.0)
soft_drop(["upperarm.R", "forearm.R", "hand.R", "upperarm.L", "forearm.L", "hand.L"], arm_keep, "chest")
soft_drop(["head", "neck"], np.clip((z - 1.2) / 0.2, 0.0, 1.0), "chest")
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")
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

# Знаки: нахил уперед хребта — +x; рука/нога вперед — -x; права рука
# вбік — +y, ліва вбік — -y. Посох на правій кисті: щоб він лишався
# прямовисним, кисть повертаємо назад на суму кутів плеча й передпліччя.
STAND = {}


def pose(extra, base=None):
    base = STAND if base is None else base
    out = {k: dict(v) for k, v in base.items()}
    for bone, spec in extra.items():
        merged = dict(out.get(bone, {}))
        for axis, value in spec.items():
            merged[axis] = merged.get(axis, 0) + value if axis != "loc" else value
        out[bone] = merged
    return out


def staff_up(upper, fore, side=0.0):
    """Права рука піднята (кути вперед), посох прямовисний."""
    return {"upperarm.R": {"x": -upper, "y": side}, "forearm.R": {"x": -fore},
            "hand.R": {"x": upper + fore, "y": -side}}


# Стійка: спокійно дихає, ліва долоня з морозом ледь поводить.
make_action("Idle", 72, {
    0: pose({"chest": {"x": 1}, "upperarm.L": {"x": -4, "y": -4}, "forearm.L": {"z": 4}}),
    36: pose({"chest": {"x": -2}, "head": {"z": 5, "x": -2}, "upperarm.L": {"x": -10, "y": -8},
              "forearm.L": {"z": -8}, "root": {"loc": (0, 0, -0.012)}}),
}, loop=True)


def walk_pose(phase, stride):
    s = math.sin(phase)
    c = math.cos(phase)
    # Під мантією ноги ходять коротко — інакше поли тягнуться в смуги.
    return pose({
        "thigh.L": {"x": -stride * s}, "thigh.R": {"x": stride * s},
        "shin.L": {"x": stride * 0.6 * max(0.0, -s)}, "shin.R": {"x": stride * 0.6 * max(0.0, s)},
        "upperarm.L": {"x": 10 * s, "y": -4}, "upperarm.R": {"x": -4 * s}, "hand.R": {"x": 4 * s},
        "spine": {"z": 3 * s, "x": 3}, "chest": {"z": -3 * s}, "head": {"z": 2 * s, "x": -2},
        "root": {"loc": (0, 0, -0.015 * abs(c))},
    })


make_action("Walk", 36, {f: walk_pose(f / 36 * math.tau, 13) for f in range(0, 36, 4)}, loop=True)
make_action("Run", 24, {f: walk_pose(f / 24 * math.tau, 18) for f in range(0, 24, 3)}, loop=True)

# Віяло списів: ліва долоня назад до плеча — і різко вперед.
make_action("Weapon", 24, {
    0: pose({}),
    8: pose({"upperarm.L": {"x": 20, "y": -25}, "forearm.L": {"x": -50, "z": 20}, "chest": {"z": 16},
             "spine": {"z": 6}}),
    12: pose({"upperarm.L": {"x": -78, "y": 6}, "forearm.L": {"x": 6}, "hand.L": {"x": -15},
              "chest": {"z": -14, "x": 5}, "spine": {"z": -5}, "head": {"x": -3}}),
    18: pose({"upperarm.L": {"x": -70, "y": 4}, "forearm.L": {"x": 4}, "chest": {"z": -9}}),
    24: pose({}),
})

# Крижана стіна / Кришталевий вибух: посох угору — і з силою в підлогу.
make_action("Cast", 36, {
    0: pose({}),
    12: pose({**staff_up(55, 25), "upperarm.L": {"x": -70, "y": -35}, "forearm.L": {"x": -20},
              "chest": {"x": -10}, "spine": {"x": -4}, "head": {"x": -10}}),
    18: pose({**staff_up(14, 8), "upperarm.L": {"x": -35, "y": -20}, "chest": {"x": 12}, "spine": {"x": 7},
              "head": {"x": 6}, "root": {"loc": (0, 0, -0.05)}}),
    28: pose({**staff_up(10, 5), "chest": {"x": 8}, "spine": {"x": 5}, "root": {"loc": (0, 0, -0.03)}}),
    36: pose({}),
})

# Крижаний панцир / Обмороження: ліва рука простягнута вперед до цілі.
make_action("Support", 36, {
    0: pose({}),
    9: pose({"upperarm.L": {"x": -85, "y": -10}, "forearm.L": {"x": -10}, "hand.L": {"x": -20},
             "chest": {"z": -12, "x": -3}, "head": {"z": -8}, **staff_up(10, 5)}),
    27: pose({"upperarm.L": {"x": -90, "y": -14}, "forearm.L": {"x": -12}, "hand.L": {"x": -25},
              "chest": {"z": -14, "x": -5}, "head": {"z": -10}, **staff_up(12, 6)}),
    36: pose({}),
})


# Крижане поле (ульта, петля): посох високо над головою, ліва рука вбік,
# тіло ледь гойдається — стоїть і тримає чари.
def channel_pose(phase):
    s = math.sin(phase)
    return pose({**staff_up(80, 30, 6), "upperarm.L": {"x": -25 + 5 * s, "y": -70},
                 "forearm.L": {"x": -10, "z": 8 * s}, "hand.L": {"x": -20},
                 "chest": {"x": -9, "z": 4 * s}, "spine": {"x": -4}, "head": {"x": -14, "z": -3 * s},
                 "root": {"loc": (0, 0, 0.02 * s)}})


make_action("Channel", 48, {f: channel_pose(f / 48 * math.tau) for f in range(0, 48, 6)}, loop=True)

make_action("HitReact", 14, {
    0: pose({}),
    4: pose({"chest": {"x": -12, "z": -8}, "head": {"x": -10}, "spine": {"x": -5},
             "upperarm.L": {"x": 18, "y": -12}}),
    14: pose({}),
})

# Смерть: посох випадає з руки, вона осідає на коліна — і падає ниць.
make_action("Death", 60, {
    0: pose({}),
    12: pose({"chest": {"x": 14}, "head": {"x": 16}, "upperarm.L": {"x": -30, "y": 20}, "forearm.L": {"x": -60},
              "hand.R": {"y": 20}}),
    28: pose({"thigh.L": {"x": -80}, "thigh.R": {"x": -80}, "shin.L": {"x": 140}, "shin.R": {"x": 140},
              "foot.L": {"x": -40}, "foot.R": {"x": -40}, "chest": {"x": 20}, "head": {"x": 20},
              "hand.R": {"y": 60}, "root": {"loc": (0, 0, -0.32)}}),
    46: pose({"root": {"x": 60, "loc": (0, 0, -0.08)}, "thigh.L": {"x": -50}, "thigh.R": {"x": -50},
              "shin.L": {"x": 90}, "shin.R": {"x": 90}, "upperarm.L": {"x": -60}, "head": {"x": -10},
              "hand.R": {"y": 80}}),
    60: pose({"root": {"x": 82, "loc": (0, 0, 0.0)}, "thigh.L": {"x": -20}, "thigh.R": {"x": -20},
              "shin.L": {"x": 30}, "shin.R": {"x": 30}, "upperarm.L": {"x": -90}, "head": {"x": -15},
              "hand.R": {"y": 85}}),
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
