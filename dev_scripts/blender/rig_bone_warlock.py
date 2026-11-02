# -*- coding: utf-8 -*-
"""Кістяний чаклун, 4-й данж (модель гравця з Rodin; свій скелет — у Rodin
посох і мантія розмазувались би). Конвеєр rig_witch.py: суглоби за
скелетом Rodin, теплові ваги на вокселях, посох із черепом барана (права
кисть) — твердий за вузькою маскою (циліндр древка + череп угорі), стик
посоха з тілом розрізано; руки не тягнуть мантію (плавно, за відстанню).
Анімації: Idle, Walk, Run, Weapon (кістяна стріла лівою), Cast (посох
угору — і в землю: підняти мерців), Sink (провалюється в могилу), HitReact,
Death.

  blender -b --factory-startup -P rig_bone_warlock.py -- <вхід.glb> <вихід.glb>
"""
import math
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = argv[0], argv[1]
TARGET_TRIS = 7000
FPS = 30

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
mesh_obj.name = "BoneWarlock"

tris = sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons)
mod = mesh_obj.modifiers.new("decimate", "DECIMATE")
mod.ratio = min(1.0, TARGET_TRIS / tris)
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
print("TRIS", tris, "->", sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons))
coords = np.array([v.co[:] for v in mesh_obj.data.vertices])
print("HEIGHT", float(coords[:, 2].max()))

# --- скелет: Blender (x — убік, ліва рука на +x; -y — уперед; z — угору),
# суглоби зі скелета Rodin. Посох у правій руці стоїть древком на підлозі.
V = Vector
BONES = [
    ("root", None, V((0.06, 0.05, 0.0)), V((0.06, 0.05, 0.12)), 0.0),
    ("hips", "root", V((0.07, 0.05, 0.93)), V((0.06, 0.05, 1.10)), 0.22),
    ("spine", "hips", V((0.06, 0.05, 1.10)), V((0.06, 0.04, 1.22)), 0.2),
    ("chest", "spine", V((0.06, 0.04, 1.22)), V((0.06, 0.04, 1.35)), 0.2),
    ("head", "chest", V((0.06, 0.03, 1.40)), V((0.06, 0.02, 1.85)), 0.15),
    ("upperarm.R", "chest", V((-0.08, 0.05, 1.29)), V((-0.19, 0.04, 1.13)), 0.08),
    ("forearm.R", "upperarm.R", V((-0.19, 0.04, 1.13)), V((-0.37, -0.11, 1.05)), 0.08),
    ("hand.R", "forearm.R", V((-0.37, -0.11, 1.05)), V((-0.40, -0.16, 1.14)), 0.06),
    ("upperarm.L", "chest", V((0.23, 0.03, 1.28)), V((0.35, 0.01, 1.12)), 0.08),
    ("forearm.L", "upperarm.L", V((0.35, 0.01, 1.12)), V((0.49, -0.09, 1.17)), 0.08),
    ("hand.L", "forearm.L", V((0.49, -0.09, 1.17)), V((0.55, -0.13, 1.30)), 0.06),
    ("thigh.R", "hips", V((-0.05, 0.05, 0.93)), V((-0.08, 0.05, 0.52)), 0.14),
    ("shin.R", "thigh.R", V((-0.08, 0.05, 0.52)), V((-0.07, 0.08, 0.10)), 0.12),
    ("foot.R", "shin.R", V((-0.07, 0.08, 0.10)), V((-0.13, -0.18, 0.02)), 0.08),
    ("thigh.L", "hips", V((0.18, 0.05, 0.93)), V((0.20, 0.05, 0.52)), 0.14),
    ("shin.L", "thigh.L", V((0.20, 0.05, 0.52)), V((0.20, 0.08, 0.11)), 0.12),
    ("foot.L", "shin.L", V((0.20, 0.08, 0.11)), V((0.26, -0.18, 0.02)), 0.08),
]

arm_data = bpy.data.armatures.new("WarlockRig")
arm_obj = bpy.data.objects.new("WarlockRig", arm_data)
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

names = [b[0] for b in BONES if b[4] > 0]
heads = np.array([[*b[2]] for b in BONES if b[4] > 0])
tails = np.array([[*b[3]] for b in BONES if b[4] > 0])
radii = np.array([b[4] for b in BONES if b[4] > 0])
seg = tails - heads
seg_len2 = (seg ** 2).sum(1)
rel = np.zeros((len(coords), len(names)))
for k in range(len(names)):
    t = np.clip(((coords - heads[k]) @ seg[k]) / seg_len2[k], 0.0, 1.0)
    rel[:, k] = np.linalg.norm(coords - (heads[k] + t[:, None] * seg[k]), axis=1) / radii[k]
weights = 1.0 / np.maximum(rel, 0.05) ** 6
order = np.argsort(-weights, axis=1)
keep = np.zeros_like(weights)
for r in range(3):
    idx = order[:, r]
    keep[np.arange(len(coords)), idx] = weights[np.arange(len(coords)), idx]
keep /= keep.sum(1, keepdims=True)

x, y, z = coords[:, 0], coords[:, 1], coords[:, 2]
# Посох: циліндр древка (x -0.40, y -0.16; хребці над рукою товщі) + череп
# із рогами вгорі.
staff = ((np.hypot(x + 0.40, y + 0.16) < np.where(z < 0.75, 0.06, 0.11)) & (z < 1.4)) \
    | ((z >= 1.38) & (x < -0.16) & (y < 0.06))
print("STAFF verts", int(staff.sum()))

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
proxy.select_set(True)
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
arm_data.bones["root"].use_deform = False
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
arm_data.bones["root"].use_deform = True
for name in names:
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
unweighted = [v.index for v in mesh_obj.data.vertices if not any(g.weight > 0.001 for g in v.groups)]
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
    print("WEIGHTS: heat")
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=4)
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


def bone_distance(bone_name):
    k = [b[0] for b in BONES].index(bone_name)
    head, tail = np.array([*BONES[k][2]]), np.array([*BONES[k][3]])
    axis = tail - head
    t = np.clip(((coords - head) @ axis) / (axis @ axis), 0.0, 1.0)
    return np.linalg.norm(coords - (head + t[:, None] * axis), axis=1)


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


# Руки тримають лише рукава поруч (рукави широкі), мантію нижче — тулуб;
# голова — лише капюшон, не плечі.
for bone_name, radius in {"upperarm.R": 0.12, "forearm.R": 0.13, "hand.R": 0.1,
                          "upperarm.L": 0.12, "forearm.L": 0.13, "hand.L": 0.1}.items():
    soft_drop([bone_name], np.clip((radius + 0.05 - bone_distance(bone_name)) / 0.05, 0.0, 1.0),
              "hips" if bone_name.endswith("R") and False else "chest")
soft_drop(["head"], np.clip((z - 1.33) / 0.08, 0.0, 1.0), "chest")
# Ліва рука не тягне мантію на грудях і животі (лише x > 0.2), права — x < -0.1;
# стегна — не пояс (вище z 0.95 — тазу).
soft_drop(["upperarm.L", "forearm.L", "hand.L"], np.clip((x - 0.17) / 0.06, 0.0, 1.0), "chest")
soft_drop(["upperarm.R", "forearm.R"], np.clip((-0.07 - x) / 0.06, 0.0, 1.0), "chest")
soft_drop(["thigh.L", "thigh.R"], np.clip((1.0 - z) / 0.08, 0.0, 1.0), "hips")
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")

print("RIGID staff", rigid("hand.R", staff | (bone_distance("hand.R") < 0.05)))
bm = bmesh.new()
bm.from_mesh(mesh_obj.data)
bm.verts.ensure_lookup_table()
cut = [f for f in bm.faces
       if len({bool(staff[v.index]) for v in f.verts}) == 2]
bmesh.ops.delete(bm, geom=cut, context="FACES_ONLY")
bm.to_mesh(mesh_obj.data)
bm.free()
print("CUT staff seam faces", len(cut))
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
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, frames[0], action)
    arm_obj.animation_data.action = None
    print("ACTION", name, frames[-1], "кадрів")


# Знаки: нахил уперед хребта — +x; рука/нога вперед — -x; права рука
# вбік — +y, ліва вбік — -y. Посох на правій кисті: щоб він лишався
# прямовисним, кисть повертаємо назад на суму кутів плеча й передпліччя.
def pose(extra, base=None):
    base = {} if base is None else base
    out = {k: dict(v) for k, v in base.items()}
    for bone, spec in extra.items():
        merged = dict(out.get(bone, {}))
        for axis, value in spec.items():
            merged[axis] = merged.get(axis, 0) + value if axis != "loc" else value
        out[bone] = merged
    return out


def staff_up(upper, fore, side=0.0):
    return {"upperarm.R": {"x": -upper, "y": side}, "forearm.R": {"x": -fore},
            "hand.R": {"x": upper + fore, "y": -side}}


# Стійка: ліва долоня з зеленим вогником ледь поводить, голова хилиться.
make_action("Idle", 72, {
    0: pose({"chest": {"x": 1}, "forearm.L": {"z": 5}, "hand.L": {"x": -5}}),
    36: pose({"chest": {"x": -2}, "head": {"z": 6, "x": 3}, "upperarm.L": {"x": -6, "y": -5},
              "forearm.L": {"z": -8}, "hand.L": {"x": 8}, "root": {"loc": (0, 0, -0.01)}}),
}, loop=True)


def walk_pose(phase, stride):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({
        "thigh.L": {"x": -stride * s}, "thigh.R": {"x": stride * s},
        "shin.L": {"x": stride * 0.6 * max(0.0, -s)}, "shin.R": {"x": stride * 0.6 * max(0.0, s)},
        "upperarm.L": {"x": 8 * s}, "upperarm.R": {"x": -4 * s}, "hand.R": {"x": 4 * s},
        "spine": {"z": 3 * s, "x": 4}, "chest": {"z": -3 * s}, "head": {"z": 2 * s, "x": -2},
        "root": {"loc": (0, 0, -0.015 * abs(c))},
    })


make_action("Walk", 36, {f: walk_pose(f / 36 * math.tau, 11) for f in range(0, 36, 4)}, loop=True)
make_action("Run", 24, {f: walk_pose(f / 24 * math.tau, 15) for f in range(0, 24, 3)}, loop=True)

# Кістяна стріла: ліва долоня до плеча (0.5 с) — і різкий поштовх уперед.
make_action("Weapon", 26, {
    0: pose({}),
    10: pose({"upperarm.L": {"x": 15, "y": -20}, "forearm.L": {"x": -55, "z": 15}, "chest": {"z": 14},
              "spine": {"z": 5}}),
    15: pose({"upperarm.L": {"x": -75, "y": 4}, "forearm.L": {"x": 4}, "hand.L": {"x": -15},
              "chest": {"z": -14, "x": 5}, "spine": {"z": -5}}),
    20: pose({"upperarm.L": {"x": -68, "y": 3}, "forearm.L": {"x": 4}, "chest": {"z": -9}}),
    26: pose({}),
})

# Підняти мерців: посох угору обома руками — і з силою в землю (1 с).
make_action("Cast", 40, {
    0: pose({}),
    16: pose({**staff_up(55, 25), "upperarm.L": {"x": -110, "y": -25}, "forearm.L": {"x": -20},
              "chest": {"x": -10}, "spine": {"x": -4}, "head": {"x": -12}}),
    24: pose({**staff_up(12, 8), "upperarm.L": {"x": -40, "y": -30}, "chest": {"x": 14}, "spine": {"x": 8},
              "head": {"x": 8}, "root": {"loc": (0, 0, -0.06)}}),
    32: pose({**staff_up(10, 5), "upperarm.L": {"x": -30, "y": -35}, "chest": {"x": 10}, "spine": {"x": 6},
              "root": {"loc": (0, 0, -0.04)}}),
    40: pose({}),
})

# Втеча в могилу: згорбився, руки до грудей — провалюється (саме опускання
# робить гра).
SUNK = {"spine": {"x": 22}, "chest": {"x": 18}, "head": {"x": 15}, "upperarm.L": {"x": -30, "y": 15},
        "forearm.L": {"x": -70}, **staff_up(10, 10), "thigh.L": {"x": -25}, "thigh.R": {"x": -25},
        "shin.L": {"x": 35}, "shin.R": {"x": 35}, "root": {"loc": (0, 0, -0.1)}}
make_action("Sink", 24, {0: pose({}), 10: pose(SUNK), 24: pose(SUNK)})

make_action("HitReact", 14, {
    0: pose({}),
    4: pose({"chest": {"x": -12, "z": -8}, "head": {"x": -10}, "spine": {"x": -5}, "upperarm.L": {"x": 18, "y": -12}}),
    14: pose({}),
})

# Смерть: посох падає, кістяк осідає й розсипається ниць.
make_action("Death", 60, {
    0: pose({}),
    12: pose({"chest": {"x": 14}, "head": {"x": 16}, "upperarm.L": {"x": -30, "y": 20}, "forearm.L": {"x": -60},
              "hand.R": {"y": 20}}),
    28: pose({"thigh.L": {"x": -80}, "thigh.R": {"x": -80}, "shin.L": {"x": 140}, "shin.R": {"x": 140},
              "foot.L": {"x": -40}, "foot.R": {"x": -40}, "chest": {"x": 20}, "head": {"x": 20},
              "hand.R": {"y": 60}, "root": {"loc": (0, 0, -0.38)}}),
    46: pose({"root": {"x": 60, "loc": (0, 0, -0.1)}, "thigh.L": {"x": -50}, "thigh.R": {"x": -50},
              "shin.L": {"x": 90}, "shin.R": {"x": 90}, "upperarm.L": {"x": -60}, "head": {"x": -10},
              "hand.R": {"y": 80}}),
    60: pose({"root": {"x": 82, "loc": (0, 0, 0.0)}, "thigh.L": {"x": -20}, "thigh.R": {"x": -20},
              "shin.L": {"x": 30}, "shin.R": {"x": 30}, "upperarm.L": {"x": -90}, "head": {"x": -15},
              "hand.R": {"y": 85}}),
})

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
