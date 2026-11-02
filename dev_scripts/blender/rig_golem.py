# -*- coding: utf-8 -*-
"""Лавовий голем (згенерована модель гравця, без скелета) -> бос 5-го данжу.
Той самий конвеєр, що rig_knight.py (скелет, теплові ваги через вокселеву
копію, анімації окремими Action), але суглоби — за силуетом голема (у
метрах), без меча, з картою світіння лави.

  blender -b --factory-startup -P rig_golem.py -- <вхід.glb> <вихід.glb> <світіння.png>
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = argv[0], argv[1]
EMISSIVE = argv[2]
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
mesh_obj.name = "LavaGolem"

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
remesh.voxel_size = 0.016
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
    # Кулаки — цілком на кистях.
    print("RIGID hand.L", rigid("hand.L", near_bone("hand.L", 0.14)))
    print("RIGID hand.R", rigid("hand.R", near_bone("hand.R", 0.14)))
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
