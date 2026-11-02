# -*- coding: utf-8 -*-
"""Склепний слиз (модель гравця з Rodin, без скелета): купол без кінцівок.
Скелет із двох кісток — "core" (від підлоги, тримає весь купол) і "top"
(верхня половина): масштаб core сплющує/витягує слиз від підлоги, нахил
top — "голова" тягнеться вперед. Ваги — за висотою (плавно).
Анімації: Idle (дихає), Walk (перекочується пружно), Weapon (відкидається
й ляпає вперед), HitReact (сплющило), Death (розтікається калюжею).

  blender -b --factory-startup -P rig_slime.py -- <вхід.glb> <вихід.glb>
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = argv[0], argv[1]
FPS = 30

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=SRC)
mesh_obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
for o in bpy.context.scene.objects:
    o.select_set(False)
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mesh_obj.name = "CryptSlime"
coords = np.array([v.co[:] for v in mesh_obj.data.vertices])
H = float(coords[:, 2].max())
print("HEIGHT", H, "TRIS", sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons))

# --- скелет: Blender z — вгору, перед — -y ---
arm_data = bpy.data.armatures.new("SlimeRig")
arm_obj = bpy.data.objects.new("SlimeRig", arm_data)
bpy.context.scene.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode="EDIT")
root = arm_data.edit_bones.new("root")
root.head, root.tail = Vector((0, 0, 0)), Vector((0, 0, 0.1))
core = arm_data.edit_bones.new("core")
core.head, core.tail = Vector((0, 0, 0)), Vector((0, 0, H * 0.5))
core.parent = root
top = arm_data.edit_bones.new("top")
top.head, top.tail = Vector((0, 0, H * 0.5)), Vector((0, 0, H))
top.parent = core
for b in (root, core, top):
    b.roll = 0.0
bpy.ops.object.mode_set(mode="OBJECT")

# --- ваги за висотою ---
h = coords[:, 2] / H
t = np.clip((h - 0.35) / 0.3, 0.0, 1.0)
w_top = t * t * (3 - 2 * t)
w_core = 1.0 - w_top
g_core = mesh_obj.vertex_groups.new(name="core")
g_top = mesh_obj.vertex_groups.new(name="top")
for i in range(len(coords)):
    if w_core[i] > 0.001:
        g_core.add([i], float(w_core[i]), "REPLACE")
    if w_top[i] > 0.001:
        g_top.add([i], float(w_top[i]), "REPLACE")
mesh_obj.parent = arm_obj
mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
mod.object = arm_obj

# --- анімації ---
# Ключ: {кістка: {"x": градуси (нахил уперед, локальна вісь X), "z": градуси
# (поворот навколо вертикалі), "s": (ширина, висота, глибина), "loc": (x, y, z)
# — лише root, у метрах: x убік, y вгору, z уперед}}.
def key_pose(pb, spec):
    pb.rotation_mode = "QUATERNION"
    q = Quaternion((1, 0, 0), math.radians(spec.get("x", 0.0)))
    q = Quaternion((0, 1, 0), math.radians(spec.get("z", 0.0))) @ q
    pb.rotation_quaternion = q
    sx, sy, sz = spec.get("s", (1.0, 1.0, 1.0))
    # Локальні осі кістки, що дивиться вгору: X — убік, Y — вгору, Z — уперед.
    pb.scale = Vector((sx, sy, sz))
    if pb.name == "root":
        x, y, z = spec.get("loc", (0.0, 0.0, 0.0))
        pb.location = Vector((x, y, z))


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
            key_pose(pb, keys[frame].get(pb.name, {}))
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.keyframe_insert("scale", frame=frame)
            if pb.name == "root":
                pb.keyframe_insert("location", frame=frame)
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, frames[0], action)
    arm_obj.animation_data.action = None
    print("ACTION", name, frames[-1])


def squash(k):
    """k > 0 — вищий і вужчий, k < 0 — нижчий і ширший (об'єм приблизно той самий)."""
    return (1.0 - 0.5 * k, 1.0 + k, 1.0 - 0.5 * k)


make_action("Idle", 60, {
    0: {"core": {"s": squash(-0.04)}},
    30: {"core": {"s": squash(0.05)}, "top": {"z": 4, "x": -2}},
}, loop=True)

# Хода: пружний перекот — присів, витягнувся вперед-угору, ляснув.
make_action("Walk", 24, {
    0: {"core": {"s": squash(-0.12)}, "top": {"x": -4}},
    6: {"core": {"s": squash(0.12), "x": 6}, "top": {"x": 8}, "root": {"loc": (0, 0.06, 0)}},
    12: {"core": {"s": squash(-0.02), "x": 3}, "top": {"x": 2}, "root": {"loc": (0, 0.02, 0)}},
    18: {"core": {"s": squash(-0.16)}, "top": {"x": -6}},
}, loop=True)

# Удар: відкидається назад і вгору — і ляпає верхом уперед.
make_action("Weapon", 26, {
    0: {"core": {"s": squash(0.0)}},
    8: {"core": {"s": squash(0.22), "x": -10}, "top": {"x": -18}},
    13: {"core": {"s": squash(-0.2), "x": 16}, "top": {"x": 38}, "root": {"loc": (0, 0, 0.18)}},
    19: {"core": {"s": squash(-0.12), "x": 8}, "top": {"x": 18}, "root": {"loc": (0, 0, 0.1)}},
    26: {"core": {"s": squash(0.0)}},
})

make_action("HitReact", 14, {
    0: {"core": {"s": squash(0.0)}},
    3: {"core": {"s": squash(-0.28), "x": -6}, "top": {"x": -10}},
    8: {"core": {"s": squash(0.12)}},
    14: {"core": {"s": squash(0.0)}},
})

# Смерть: тремтить — і розтікається плоскою калюжею.
make_action("Death", 40, {
    0: {"core": {"s": squash(0.0)}},
    6: {"core": {"s": squash(0.18)}, "top": {"z": 10}},
    10: {"core": {"s": squash(-0.1)}, "top": {"z": -10}},
    24: {"core": {"s": (1.45, 0.25, 1.45)}, "top": {"x": 4}},
    40: {"core": {"s": (1.6, 0.12, 1.6)}},
})

# --- текстури й експорт ---
for image in bpy.data.images:
    if image.size[0] > 1024:
        image.scale(1024, 1024)
for mat in mesh_obj.data.materials:
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is not None:
        for name in ("Metallic", "Roughness"):
            for link in list(bsdf.inputs[name].links):
                mat.node_tree.links.remove(link)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.45
bpy.ops.object.select_all(action="DESELECT")
arm_obj.select_set(True)
mesh_obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_skins=True, export_image_format="AUTO", export_yup=True)
print("EXPORTED", DST)
