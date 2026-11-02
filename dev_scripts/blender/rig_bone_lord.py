# -*- coding: utf-8 -*-
"""Кістяний Володар, бос 4-го данжу (модель гравця з Rodin; свій скелет —
у Rodin коса розмазувалась би разом із рукою й плащем). Конвеєр
rig_witch.py: суглоби за скелетом Rodin, теплові ваги на вокселях, коса —
тверда на окремій кістці "scythe" (дитя правої кисті) за вузькою маскою
(ламана вздовж кістяного держака + лезо), стик коси з тілом розрізано.
Кістка "scythe" у кидку стискається в нуль — коса "летить" окремою моделлю.

Анімації: Idle, Walk, Run, Weapon (удар косою згори), Sweep (широкий укіс
на 180°), Throw (кидок коси й ловля), Plant (встромляє косу в землю),
Roar, Collapse/Down/Rise (розсипається на кістки й збирається), HitReact,
Death.

  blender -b --factory-startup -P rig_bone_lord.py -- <вхід.glb> <вихід.glb> <коса.glb>
"""
import math
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST, SCYTHE_DST = argv[0], argv[1], argv[2]
TARGET_TRIS = 14000
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
mesh_obj.name = "BoneLord"

tris = sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons)
mod = mesh_obj.modifiers.new("decimate", "DECIMATE")
mod.ratio = min(1.0, TARGET_TRIS / tris)
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
print("TRIS", tris, "->", sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons))

coords = np.array([v.co[:] for v in mesh_obj.data.vertices])
print("HEIGHT", float(coords[:, 2].max()))

# --- скелет: координати Blender (x — убік, ліва рука на +x; -y — уперед;
# z — угору), суглоби зі скелета Rodin. Бос присадкуватий, коса в правій.
V = Vector
BONES = [
    ("root", None, V((0.25, 0.10, 0.0)), V((0.25, 0.10, 0.12)), 0.0),
    ("hips", "root", V((0.25, 0.15, 0.58)), V((0.26, 0.13, 0.72)), 0.22),
    ("spine", "hips", V((0.26, 0.13, 0.72)), V((0.27, 0.10, 0.89)), 0.26),
    ("chest", "spine", V((0.27, 0.10, 0.89)), V((0.27, 0.08, 1.00)), 0.30),
    ("head", "chest", V((0.27, 0.06, 1.00)), V((0.27, 0.00, 1.24)), 0.15),
    ("upperarm.R", "chest", V((0.04, 0.08, 0.94)), V((-0.12, 0.13, 0.76)), 0.12),
    ("forearm.R", "upperarm.R", V((-0.12, 0.13, 0.76)), V((-0.27, 0.08, 0.56)), 0.10),
    ("hand.R", "forearm.R", V((-0.27, 0.08, 0.56)), V((-0.32, -0.02, 0.48)), 0.07),
    ("scythe", "hand.R", V((-0.29, 0.02, 0.52)), V((-0.40, -0.14, 0.68)), 0.0),
    ("upperarm.L", "chest", V((0.50, 0.07, 0.95)), V((0.67, 0.13, 0.76)), 0.12),
    ("forearm.L", "upperarm.L", V((0.67, 0.13, 0.76)), V((0.80, 0.12, 0.57)), 0.10),
    ("hand.L", "forearm.L", V((0.80, 0.12, 0.57)), V((0.85, 0.08, 0.44)), 0.08),
    ("thigh.R", "hips", V((0.14, 0.12, 0.56)), V((0.03, 0.10, 0.32)), 0.12),
    ("shin.R", "thigh.R", V((0.03, 0.10, 0.32)), V((-0.01, 0.15, 0.10)), 0.10),
    ("foot.R", "shin.R", V((-0.01, 0.15, 0.10)), V((-0.10, 0.0, 0.01)), 0.08),
    ("thigh.L", "hips", V((0.36, 0.12, 0.56)), V((0.47, 0.05, 0.31)), 0.12),
    ("shin.L", "thigh.L", V((0.47, 0.05, 0.31)), V((0.50, 0.12, 0.10)), 0.10),
    ("foot.L", "shin.L", V((0.50, 0.12, 0.10)), V((0.60, -0.04, 0.01)), 0.08),
]

arm_data = bpy.data.armatures.new("LordRig")
arm_obj = bpy.data.objects.new("LordRig", arm_data)
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

# --- ваги (як rig_witch.py: тепловий метод на вокселях + запасні за відстанню) ---
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

# Коса (маска в координатах сітки): ламана вздовж держака + усе, що далі
# x = -0.42 (лезо й верх держака: тіло так далеко не сягає).
x, y, z = coords[:, 0], coords[:, 1], coords[:, 2]
SHAFT = np.array([[-0.12, 0.08, 0.19], [-0.19, 0.03, 0.31], [-0.28, -0.06, 0.47], [-0.40, -0.14, 0.68],
                  [-0.65, -0.195, 1.06], [-0.73, -0.22, 1.17]])
dist = np.full(len(coords), 9.0)
for i in range(len(SHAFT) - 1):
    a, b = SHAFT[i], SHAFT[i + 1]
    t = np.clip(((coords - a) @ (b - a)) / ((b - a) @ (b - a)), 0.0, 1.0)
    dist = np.minimum(dist, np.linalg.norm(coords - (a + t[:, None] * (b - a)), axis=1))
scythe = (dist < 0.055) | ((x < -0.42) & (z > 0.3))
print("SCYTHE verts", int(scythe.sum()))

proxy = mesh_obj.copy()
proxy.data = mesh_obj.data.copy()
bpy.context.scene.collection.objects.link(proxy)
remesh = proxy.modifiers.new("remesh", "REMESH")
remesh.mode = "VOXEL"
remesh.voxel_size = 0.015
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
# Коса й корінь — не для теплових ваг (інакше коса "тягне" груди).
for bone_name in ("scythe", "root"):
    arm_data.bones[bone_name].use_deform = False
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
for bone_name in ("scythe", "root"):
    arm_data.bones[bone_name].use_deform = True
for name in names + ["root", "scythe"]:
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
for g in ("root", "scythe"):
    grp = mesh_obj.vertex_groups.get(g)
    if grp is not None and g == "root":
        hips_group = mesh_obj.vertex_groups["hips"]
        for v in mesh_obj.data.vertices:
            for ge in v.groups:
                if ge.group == grp.index and ge.weight > 0.0:
                    hips_group.add([v.index], ge.weight, "ADD")
        mesh_obj.vertex_groups.remove(grp)
unweighted = [v.index for v in mesh_obj.data.vertices if not any(g.weight > 0.001 for g in v.groups)]
print("HEAT unweighted", len(unweighted), "of", len(mesh_obj.data.vertices))
if len(unweighted) > len(mesh_obj.data.vertices) * 0.1:
    for g in list(mesh_obj.vertex_groups):
        mesh_obj.vertex_groups.remove(g)
    for k, name in enumerate(names):
        group = mesh_obj.vertex_groups.new(name=name)
        for i in np.nonzero(keep[:, k] > 0.01)[0]:
            group.add([int(i)], float(keep[i, k]), "REPLACE")
    mesh_obj.vertex_groups.new(name="scythe")
    print("WEIGHTS: fallback distance")
else:
    for i in unweighted:
        k = int(np.argmax(keep[i]))
        mesh_obj.vertex_groups[names[k]].add([i], 1.0, "REPLACE")
    print("WEIGHTS: heat")
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=5)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=3)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")


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


# Плащ і поли позаду: руки їх не тягнуть (плавно, як у чаклунки), голова —
# комір і шарф нижче підборіддя.
def soft_drop(bone_names, keep_factor, receiver):
    receiver_group = mesh_obj.vertex_groups[receiver]
    index = {mesh_obj.vertex_groups[n].index: n for n in bone_names}
    for v in mesh_obj.data.vertices:
        if scythe[v.index] or keep_factor[v.index] >= 0.999:
            continue
        moved = 0.0
        for g in v.groups:
            if g.group in index:
                moved += g.weight * (1.0 - keep_factor[v.index])
                g.weight *= keep_factor[v.index]
        if moved > 0.0 and sum(g.weight for g in v.groups) < 0.05:
            receiver_group.add([v.index], moved, "ADD")


# Плащ і поли: тепловий метод "протік" у них від рук і ніг (плащ уздовж
# опущеної руки). Кістка кінцівки тримає лише те, що поруч із нею (броня
# товста — радіус щедрий), далі вага плавно віддається тулубу.
def bone_distance(bone_name):
    k = [b[0] for b in BONES].index(bone_name)
    head, tail = np.array([*BONES[k][2]]), np.array([*BONES[k][3]])
    axis = tail - head
    t = np.clip(((coords - head) @ axis) / (axis @ axis), 0.0, 1.0)
    return np.linalg.norm(coords - (head + t[:, None] * axis), axis=1)


LIMBS = {"upperarm.R": 0.2, "forearm.R": 0.15, "hand.R": 0.12, "upperarm.L": 0.2, "forearm.L": 0.15,
         "hand.L": 0.17, "thigh.R": 0.14, "shin.R": 0.13, "foot.R": 0.13, "thigh.L": 0.14, "shin.L": 0.13,
         "foot.L": 0.13, "head": 0.2}
ARMS = ("upperarm.R", "forearm.R", "hand.R", "upperarm.L", "forearm.L", "hand.L")
LOW = z < 0.7
for bone_name, radius in LIMBS.items():
    limb_keep = np.clip((radius + 0.06 - bone_distance(bone_name)) / 0.06, 0.0, 1.0)
    # Низ плаща — стегнам, верх — грудям: так при нахилі він гнеться плавно.
    soft_drop([bone_name], np.where(LOW, limb_keep, 1.0), "hips")
    soft_drop([bone_name], np.where(LOW, 1.0, limb_keep), "chest")
soft_drop(["head"], np.clip((z - 0.93) / 0.08, 0.0, 1.0), "chest")
# Плащ позаду (і спина під ним): ваги за висотою — стегна внизу, хребет,
# груди вгорі, з плавним переходом. Так поли гнуться разом із тулубом, а не
# рвуться між "грудьми" й "стегнами".
far_from_arms = np.minimum.reduce([bone_distance(n) for n in ARMS]) > 0.14
cape = (y > 0.2) & (z < 0.95) & (x > -0.12) & (x < 0.66) & far_from_arms & ~scythe
tents = {"hips": (0.45, 0.32), "spine": (0.78, 0.2), "chest": (0.98, 0.22)}
cape_w = {n: np.clip(1.0 - np.abs(z - c) / w, 0.0, 1.0) for n, (c, w) in tents.items()}
cape_w["hips"] = np.where(z < 0.45, 1.0, cape_w["hips"])
total = sum(cape_w.values())
cape_ids = [int(i) for i in np.nonzero(cape)[0]]
for g in mesh_obj.vertex_groups:
    g.remove(cape_ids)
for n, w in cape_w.items():
    group = mesh_obj.vertex_groups[n]
    for i in cape_ids:
        if w[i] > 0.0:
            group.add([i], float(w[i] / total[i]), "REPLACE")
print("CAPE verts", len(cape_ids))
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=3)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=3)
bpy.ops.object.mode_set(mode="OBJECT")
# Після згладжування — точково (згладжування розносить вагу назад):
# коліно біля опущеної кисті з косою — не рука; груди спереду — не плече
# (права рука лише x < 0.04, ліва — x > 0.5); плащ за правою рукою — не рука.
knee = (z < 0.42) & (x > -0.2) & (x < 0.1)
soft_drop(["hand.R", "forearm.R", "upperarm.R"], np.where(knee, 0.0, 1.0), "shin.R")
front = (z > 0.7) & (y < 0.0)
soft_drop(["upperarm.R", "forearm.R"], np.where(front, np.clip((0.12 - x) / 0.1, 0.0, 1.0), 1.0), "chest")
soft_drop(["upperarm.L", "forearm.L"], np.where(front, np.clip((x - 0.42) / 0.1, 0.0, 1.0), 1.0), "chest")
behind = (y > 0.15) & (z < 0.85)
for bone_name in ("upperarm.R", "upperarm.L"):
    soft_drop([bone_name], np.where(behind, np.clip((0.14 - bone_distance(bone_name)) / 0.04, 0.0, 1.0), 1.0),
              "chest")
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")

hand = near_bone("hand.R", 0.06) & ~scythe
print("RIGID hand", rigid("hand.R", hand))
print("RIGID scythe", rigid("scythe", scythe))
# Стик коси з тілом (пальці на держаку, низ держака біля ноги) — різати,
# інакше в кидку (коса стискається) й на замаху грані тягнуться смугою.
bm = bmesh.new()
bm.from_mesh(mesh_obj.data)
bm.verts.ensure_lookup_table()
cut = [f for f in bm.faces if len({bool(scythe[v.index]) for v in f.verts}) == 2]
bmesh.ops.delete(bm, geom=cut, context="FACES_ONLY")
bm.to_mesh(mesh_obj.data)
bm.free()
print("CUT scythe seam faces", len(cut))

# --- окрема модель коси для кидка (без скелета, центр — у нулі) ---
scythe_obj = mesh_obj.copy()
scythe_obj.data = mesh_obj.data.copy()
bpy.context.scene.collection.objects.link(scythe_obj)
for g in list(scythe_obj.vertex_groups):
    scythe_obj.vertex_groups.remove(g)
bm = bmesh.new()
bm.from_mesh(scythe_obj.data)
bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not scythe[v.index]], context="VERTS")
bm.to_mesh(scythe_obj.data)
bm.free()
pts = np.array([v.co[:] for v in scythe_obj.data.vertices])
center = (pts.min(0) + pts.max(0)) * 0.5
for v in scythe_obj.data.vertices:
    v.co = Vector(v.co) - Vector(center.tolist())
print("SCYTHE prop verts", len(pts), "size", (pts.max(0) - pts.min(0)).round(3))

mesh_obj.parent = arm_obj
armature_mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
armature_mod.object = arm_obj

# --- анімації ---
REST = {b.name: b.matrix_local.to_quaternion() for b in arm_data.bones}
AXES = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}


def local_rotation(bone, spec):
    q = Quaternion()
    for axis in ("z", "y", "x"):
        if axis in spec:
            q = Quaternion(AXES[axis], math.radians(spec[axis])) @ q
    rest = REST[bone]
    return rest.inverted() @ q @ rest


def make_action(name, length, keys, loop=False):
    """keys: {кадр: {кістка: {"x": .., "y": .., "z": .., "loc": (x, y, z), "s": масштаб}}}."""
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
                pb.location = REST["root"].inverted() @ Vector(spec.get("loc", (0, 0, 0)))
                pb.keyframe_insert("location", frame=frame)
            if pb.name == "scythe":
                s = spec.get("s", 1.0)
                pb.scale = (s, s, s)
                pb.keyframe_insert("scale", frame=frame)
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, frames[0], action)
    arm_obj.animation_data.action = None
    print("ACTION", name, frames[-1], "кадрів")


# Знаки: нахил уперед хребта — +x; рука/нога вперед — -x; права рука
# вбік — +y, ліва вбік — -y; поворот корпусу ліворуч — +z.
STAND = {}


def pose(extra, base=None):
    base = STAND if base is None else base
    out = {k: dict(v) for k, v in base.items()}
    for bone, spec in extra.items():
        merged = dict(out.get(bone, {}))
        for axis, value in spec.items():
            merged[axis] = merged.get(axis, 0) + value if axis not in ("loc", "s") else value
        out[bone] = merged
    return out


make_action("Idle", 72, {
    0: pose({"chest": {"x": 2}, "upperarm.R": {"x": -2}, "root": {"loc": (0, 0, -0.005)}}),
    36: pose({"chest": {"x": -3}, "head": {"z": 6, "x": -3}, "upperarm.L": {"y": -5, "x": -4},
              "forearm.L": {"x": -6}, "upperarm.R": {"x": -6}, "root": {"loc": (0, 0, -0.02)}}),
}, loop=True)


def walk_pose(phase, stride, lean):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({
        "thigh.L": {"x": -stride * s}, "thigh.R": {"x": stride * s},
        "shin.L": {"x": stride * 0.8 * max(0.0, -s)}, "shin.R": {"x": stride * 0.8 * max(0.0, s)},
        "foot.L": {"x": -5 * s}, "foot.R": {"x": 5 * s},
        "upperarm.L": {"x": 14 * s}, "upperarm.R": {"x": -5 * s},
        "spine": {"z": 6 * s, "x": lean}, "chest": {"z": -5 * s}, "head": {"z": 3 * s},
        "root": {"loc": (0, 0, -0.025 * abs(c))},
    })


make_action("Walk", 40, {f: walk_pose(f / 40 * math.tau, 20, 4) for f in range(0, 40, 4)}, loop=True)
make_action("Run", 26, {f: walk_pose(f / 26 * math.tau, 32, 12) for f in range(0, 26, 2)}, loop=True)

# Удар косою згори навскіс: замах над правим плечем (0.7 с) — і вниз.
make_action("Weapon", 40, {
    0: pose({}),
    16: pose({"upperarm.R": {"x": -105, "y": 15}, "forearm.R": {"x": -60}, "chest": {"x": -10, "z": -18},
              "spine": {"z": -8}, "head": {"x": -6}}),
    21: pose({"upperarm.R": {"x": -108, "y": 18}, "forearm.R": {"x": -65}, "chest": {"x": -12, "z": -20},
              "spine": {"z": -9}}),
    26: pose({"upperarm.R": {"x": -30, "y": 8}, "forearm.R": {"x": -10}, "chest": {"x": 22, "z": 22},
              "spine": {"x": 10, "z": 8}, "thigh.R": {"x": -15}, "shin.R": {"x": 15}, "root": {"loc": (0, 0, -0.05)}}),
    32: pose({"upperarm.R": {"x": -25, "y": 6}, "chest": {"x": 16, "z": 18}, "spine": {"x": 6},
              "root": {"loc": (0, 0, -0.04)}}),
    40: pose({}),
})

# Широкий укіс: корпус закручується праворуч, коса відведена вбік і назад
# (0.9 с) — і різкий мах по дузі перед собою справа наліво.
make_action("Sweep", 50, {
    0: pose({}),
    18: pose({"chest": {"z": -42, "x": -4}, "spine": {"z": -16}, "upperarm.R": {"y": 55, "x": 15},
              "forearm.R": {"x": -25}, "upperarm.L": {"x": -20, "y": -20}, "thigh.L": {"x": -12}, "shin.L": {"x": 14},
              "root": {"loc": (0, 0, -0.04)}}),
    26: pose({"chest": {"z": -48, "x": -4}, "spine": {"z": -18}, "upperarm.R": {"y": 60, "x": 18},
              "forearm.R": {"x": -25}, "upperarm.L": {"x": -22, "y": -22}, "thigh.L": {"x": -14}, "shin.L": {"x": 16},
              "root": {"loc": (0, 0, -0.05)}}),
    31: pose({"chest": {"z": 30, "x": 8}, "spine": {"z": 12}, "upperarm.R": {"y": 45, "x": -60},
              "forearm.R": {"x": -10}, "upperarm.L": {"y": -30}, "root": {"loc": (0, 0, -0.07)}}),
    36: pose({"chest": {"z": 52, "x": 10}, "spine": {"z": 18}, "upperarm.R": {"y": 15, "x": -75},
              "forearm.R": {"x": -10}, "upperarm.L": {"y": -35}, "root": {"loc": (0, 0, -0.06)}}),
    50: pose({}),
})

# Кидок коси: замах із-за голови (0.6 с), кидок — і рука порожня, поки коса
# летить бумерангом (до 2.2 с); ловить її й повертається в стійку.
EMPTY = {"scythe": {"s": 0.001}}
make_action("Throw", 80, {
    0: pose({}),
    12: pose({"upperarm.R": {"x": -118, "y": 12}, "forearm.R": {"x": -75}, "chest": {"z": -28, "x": -10},
              "spine": {"z": -10}}),
    17: pose({"upperarm.R": {"x": -70, "y": 10}, "forearm.R": {"x": -8}, "chest": {"z": 26, "x": 14},
              "spine": {"z": 10}, "root": {"loc": (0, 0, -0.04)}}),
    18: pose({"upperarm.R": {"x": -62, "y": 10}, "forearm.R": {"x": -6}, "chest": {"z": 28, "x": 14},
              "spine": {"z": 10}, "root": {"loc": (0, 0, -0.04)}, **EMPTY}),
    30: pose({"upperarm.R": {"x": -40, "y": 12}, "chest": {"z": 10, "x": 6}, **EMPTY}),
    60: pose({"upperarm.R": {"x": -55, "y": 25}, "forearm.R": {"x": -20}, "chest": {"z": -6}, **EMPTY}),
    65: pose({"upperarm.R": {"x": -70, "y": 28}, "forearm.R": {"x": -25}, "chest": {"z": -10}, **EMPTY}),
    66: pose({"upperarm.R": {"x": -70, "y": 28}, "forearm.R": {"x": -25}, "chest": {"z": -10, "x": -4}}),
    72: pose({"upperarm.R": {"x": -30, "y": 10}, "chest": {"z": -4}}),
    80: pose({}),
})

# Армія мертвих: коса обома руками над головою — і вістрям у землю; так і
# стоїть, поки з-під землі лізуть мерці.
PLANTED = {"upperarm.R": {"x": -55, "y": -10}, "forearm.R": {"x": -15}, "hand.R": {"x": 115}, "upperarm.L": {"x": -60, "y": 25},
           "forearm.L": {"x": -30}, "chest": {"x": 30, "z": 10}, "spine": {"x": 14}, "head": {"x": -18},
           "thigh.L": {"x": -30}, "thigh.R": {"x": -30}, "shin.L": {"x": 40}, "shin.R": {"x": 40},
           "root": {"loc": (0, 0, -0.12)}}
make_action("Plant", 60, {
    0: pose({}),
    14: pose({"upperarm.R": {"x": -115, "y": -5}, "forearm.R": {"x": -45}, "upperarm.L": {"x": -110, "y": 20},
              "forearm.L": {"x": -40}, "chest": {"x": -16}, "spine": {"x": -6}, "head": {"x": -14},
              "root": {"loc": (0, 0, 0.02)}}),
    21: pose(PLANTED),
    60: pose(PLANTED),
})

make_action("Roar", 50, {
    0: pose({}),
    12: pose({"upperarm.L": {"x": -30, "y": 25}, "upperarm.R": {"x": -30, "y": -25}, "forearm.L": {"x": -70},
              "forearm.R": {"x": -70}, "chest": {"x": 28}, "spine": {"x": 15}, "head": {"x": 20},
              "thigh.L": {"x": -25}, "thigh.R": {"x": -25}, "shin.L": {"x": 35}, "shin.R": {"x": 35},
              "root": {"loc": (0, 0, -0.1)}}),
    24: pose({"upperarm.L": {"y": -65, "x": -40}, "upperarm.R": {"y": 65, "x": -40}, "forearm.L": {"x": -10},
              "forearm.R": {"x": -10}, "chest": {"x": -22}, "spine": {"x": -8}, "head": {"x": -30}}),
    38: pose({"upperarm.L": {"y": -60, "x": -35}, "upperarm.R": {"y": 60, "x": -35}, "chest": {"x": -20},
              "head": {"x": -28, "z": 6}}),
    50: pose({}),
})

# Розсипається: коліна підгинаються, тулуб валиться вперед, руки безвольні —
# купа кісток на підлозі. "Down" — ця сама купа (петля, поки лежить), "Rise" —
# збирається знову.
PILE = {"root": {"x": 38, "loc": (0, 0, -0.42)}, "thigh.L": {"x": -95, "y": -20}, "thigh.R": {"x": -95, "y": 20},
        "shin.L": {"x": 150}, "shin.R": {"x": 150}, "foot.L": {"x": -40}, "foot.R": {"x": -40},
        "spine": {"x": 30, "z": 12}, "chest": {"x": 35, "z": -10}, "head": {"x": 40, "z": 25},
        "upperarm.L": {"x": 30, "y": -55}, "forearm.L": {"x": -20}, "upperarm.R": {"x": 25, "y": 60},
        "forearm.R": {"x": -15}}
make_action("Collapse", 30, {
    0: pose({}),
    9: pose({"thigh.L": {"x": -30}, "thigh.R": {"x": -30}, "shin.L": {"x": 45}, "shin.R": {"x": 45},
             "spine": {"x": 20}, "chest": {"x": 15}, "head": {"x": 25}, "upperarm.L": {"x": 10, "y": -15},
             "upperarm.R": {"x": 10, "y": 15}, "root": {"loc": (0, 0, -0.12)}}),
    20: pose({"root": {"x": 20, "loc": (0, 0, -0.34)}, "thigh.L": {"x": -85}, "thigh.R": {"x": -85},
              "shin.L": {"x": 140}, "shin.R": {"x": 140}, "spine": {"x": 28}, "chest": {"x": 30},
              "head": {"x": 35, "z": 15}, "upperarm.L": {"x": 20, "y": -35}, "upperarm.R": {"x": 20, "y": 40}}),
    30: pose(PILE),
})
make_action("Down", 40, {0: pose(PILE), 20: pose(PILE, pose({"head": {"z": 4}}))}, loop=True)
make_action("Rise", 36, {
    0: pose(PILE),
    12: pose({"root": {"x": 15, "loc": (0, 0, -0.3)}, "thigh.L": {"x": -80}, "thigh.R": {"x": -80},
              "shin.L": {"x": 130}, "shin.R": {"x": 130}, "spine": {"x": 20}, "chest": {"x": 18},
              "head": {"x": 10}, "upperarm.L": {"x": -10, "y": -20}, "upperarm.R": {"x": -10, "y": 20}}),
    24: pose({"upperarm.L": {"y": -55, "x": -30}, "upperarm.R": {"y": 55, "x": -30}, "chest": {"x": -18},
              "head": {"x": -25}, "root": {"loc": (0, 0, 0.02)}}),
    36: pose({}),
})

make_action("HitReact", 14, {
    0: pose({}),
    4: pose({"chest": {"x": -12, "z": 8}, "head": {"x": -12}, "spine": {"x": -5}, "upperarm.L": {"x": 15}}),
    14: pose({}),
})

DEAD = pose({"root": {"x": 70, "loc": (0, 0, -0.3)}, "upperarm.R": {"x": 40, "y": 70}, "upperarm.L": {"x": 30, "y": -60}},
            PILE)
make_action("Death", 60, {
    0: pose({}),
    10: pose({"chest": {"x": -16}, "head": {"x": -22}, "spine": {"x": -6}, "upperarm.L": {"x": 15},
              "upperarm.R": {"x": 15, "y": 8}}),
    26: pose({"root": {"x": 20, "loc": (0, 0, -0.34)}, "thigh.L": {"x": -85}, "thigh.R": {"x": -85},
              "shin.L": {"x": 140}, "shin.R": {"x": 140}, "spine": {"x": 28}, "chest": {"x": 30},
              "head": {"x": 35}}),
    42: pose(PILE),
    60: DEAD,
})

# --- текстури й експорт ---
for image in bpy.data.images:
    if image.size[0] > 1024:
        image.scale(1024, 1024)
for mat in mesh_obj.data.materials:
    if mat is None or not mat.use_nodes:
        continue
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is not None:
        for sock_name in ("Metallic", "Roughness"):
            for link in list(bsdf.inputs[sock_name].links):
                mat.node_tree.links.remove(link)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.8
for img in list(bpy.data.images):
    if img.users == 0:
        bpy.data.images.remove(img)
bpy.ops.object.select_all(action="DESELECT")
arm_obj.select_set(True)
mesh_obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_skins=True, export_image_format="AUTO", export_yup=True)
print("EXPORTED", DST)
bpy.ops.object.select_all(action="DESELECT")
scythe_obj.select_set(True)
for image in bpy.data.images:
    if image.size[0] > 512:
        image.scale(512, 512)
bpy.ops.export_scene.gltf(filepath=SCYTHE_DST, export_format="GLB", use_selection=True,
                          export_animations=False, export_skins=False, export_yup=True)
print("EXPORTED", SCYTHE_DST)
