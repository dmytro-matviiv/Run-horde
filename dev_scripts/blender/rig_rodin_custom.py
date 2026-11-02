# -*- coding: utf-8 -*-
"""Моб із Rodin зі СВОЇМ набором анімацій на скелеті Rodin (ваги Rodin
лишаються — зброї в руках немає, розмазувати нічого). Пальці зливаються з
кистю, сітка спрощується, текстури 1K; дії Rodin — лише ті, що в KEEP
(перейменовані), решта — з файлу анімацій ANIMS (python), де доступні
make_action(name, length, keys, loop) і pose(...). Кути — навколо світових
осей Blender: x (нахил уперед +), y, z (поворот ліворуч +).

  blender -b --factory-startup -P rig_rodin_custom.py -- <src.glb> <dst.glb> <трикутників> <anims.py>
      [KEEP "HumanHeadHit=HitReact,..."] [SPLIT "LeftShackle,LeftChain1:Chain"]
SPLIT — грані, де всі вершини належать переважно цим кісткам, ідуть в
окремий меш (той самий скелет): гра може сховати тіло й лишити, наприклад,
ланцюг.
"""
import math
import sys

import bmesh
import bpy
from mathutils import Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST, TARGET, ANIMS = argv[0], argv[1], int(argv[2]), argv[3]
KEEP = dict(p.split("=") for p in argv[4].split(",")) if len(argv) > 4 and argv[4] else {}
SPLIT = argv[5] if len(argv) > 5 else ""
# LIMIT "LeftArm:0.12:Spine2,...": кістка тримає лише вершини ближче за
# радіус до себе (плавно, +5 см), решта ваги — кістці-приймачу. Rodin
# "протікає" вагами рук у поли балахона й живіт.
LIMIT = [p.split(":") for p in argv[6].split(",")] if len(argv) > 6 and argv[6] else []
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Pinky")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
mesh = max(meshes, key=lambda o: (len(o.vertex_groups) > 0, len(o.data.polygons)))
for o in meshes:
    if o is not mesh:
        bpy.data.objects.remove(o, do_unlink=True)

# 1) пальці -> кисть
groups = {g.name: g for g in mesh.vertex_groups}
for side in ("Left", "Right"):
    hand = groups.get(side + "Hand")
    finger_groups = [g for n, g in groups.items() if n.startswith(side + "Hand") and any(f in n for f in FINGERS)]
    for v in mesh.data.vertices:
        extra = sum(ge.weight for ge in v.groups if mesh.vertex_groups[ge.group] in finger_groups)
        if extra > 0.0 and hand is not None:
            hand.add([v.index], extra, "ADD")
    for g in finger_groups:
        mesh.vertex_groups.remove(g)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for b in list(arm.data.edit_bones):
    if any(f in b.name for f in FINGERS) and "Hand" in b.name:
        arm.data.edit_bones.remove(b)
bpy.ops.object.mode_set(mode="OBJECT")

# 2) спростити сітку
tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
bpy.context.view_layer.objects.active = mesh
mod = mesh.modifiers.new("Decimate", "DECIMATE")
mod.ratio = min(1.0, TARGET / max(tris, 1))
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_move_to_index(modifier="Decimate", index=0)
bpy.ops.object.modifier_apply(modifier="Decimate")
print("TRIS", tris, "->", sum(len(p.vertices) - 2 for p in mesh.data.polygons))
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")

import numpy as np

# 3) текстури
for mat in mesh.data.materials:
    if mat is None or not mat.use_nodes:
        continue
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is not None:
        for name in ("Metallic", "Roughness"):
            for link in list(bsdf.inputs[name].links):
                mat.node_tree.links.remove(link)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.8
for img in list(bpy.data.images):
    if img.users == 0:
        bpy.data.images.remove(img)
        continue
    if img.size[0] > 1024:
        img.scale(1024, 1024)

# 4) дії Rodin: лишаємо KEEP (корінь на місці по горизонталі), решту — геть
for act in list(bpy.data.actions):
    base = act.name.split("|")[-1]
    hit = KEEP.get(base) or KEEP.get(base.replace("Human", ""))
    if hit is None:
        bpy.data.actions.remove(act)
        continue
    act.name = hit
    act.use_fake_user = True
print("KEPT", sorted(a.name for a in bpy.data.actions))

# 5) окремий меш (ланцюг привида)
# "rust:Chain" — грані іржавого кольору (за текстурою) в окремий меш.
if SPLIT:
    mode, part_name = SPLIT.split(":")
    mat = mesh.data.materials[0]
    tex = next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"
               and any(l.to_socket.name == "Base Color" for l in n.outputs["Color"].links))
    img = tex.image
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = mesh.data.uv_layers.active.data
    rusty = []
    for poly in mesh.data.polygons:
        u = sum(uv[i].uv[0] for i in poly.loop_indices) / poly.loop_total
        vv = sum(uv[i].uv[1] for i in poly.loop_indices) / poly.loop_total
        r, g, b, _ = px[min(h - 1, max(0, int((vv % 1.0) * h))), min(w - 1, max(0, int((u % 1.0) * w)))]
        rusty.append(r - b > 0.12 and r > g + 0.03)
    part = mesh.copy()
    part.data = mesh.data.copy()
    bpy.context.scene.collection.objects.link(part)
    part.name = part_name
    for obj, keep_part in ((mesh, False), (part, True)):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        doomed = [f for f in bm.faces if rusty[f.index] != keep_part]
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.to_mesh(obj.data)
        bm.free()
    print("SPLIT", part_name, len(part.data.polygons), "faces; body", len(mesh.data.polygons))

def apply_limits(mesh):
    world = mesh.matrix_world
    pts = np.array([(world @ v.co)[:] for v in mesh.data.vertices])
    for bone_name, radius, receiver in LIMIT:
        bone = arm.data.bones.get(bone_name)
        src = mesh.vertex_groups.get(bone_name)
        dst = mesh.vertex_groups.get(receiver) or mesh.vertex_groups.new(name=receiver)
        if bone is None or src is None:
            continue
        head = np.array((arm.matrix_world @ bone.head_local)[:])
        tail = np.array((arm.matrix_world @ bone.tail_local)[:])
        axis = tail - head
        t = np.clip(((pts - head) @ axis) / max(axis @ axis, 1e-8), 0.0, 1.0)
        dist = np.linalg.norm(pts - (head + t[:, None] * axis), axis=1)
        keep_factor = np.clip((float(radius) + 0.05 - dist) / 0.05, 0.0, 1.0)
        moved_count = 0
        for v in mesh.data.vertices:
            if keep_factor[v.index] >= 0.999:
                continue
            for g in v.groups:
                if g.group == src.index and g.weight > 0.0:
                    moved = g.weight * (1.0 - keep_factor[v.index])
                    g.weight -= moved
                    dst.add([v.index], moved, "ADD")
                    moved_count += 1
        print("LIMIT", bone_name, moved_count)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")



apply_limits(mesh)

# 6) свої анімації
to_arm = arm.matrix_world.inverted().to_3x3()
AXES = {k: (to_arm @ v).normalized() for k, v in
        {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}.items()}
REST = {b.name: b.matrix_local.to_quaternion() for b in arm.data.bones}
ROOT = "Hips"


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
    arm.animation_data_create()
    arm.animation_data.action = action
    frames = sorted(keys)
    if loop and frames[-1] != length:
        keys[length] = keys[frames[0]]
        frames.append(length)
    for frame in frames:
        for pb in arm.pose.bones:
            spec = keys[frame].get(pb.name, {})
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = local_rotation(pb.name, spec)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            if pb.name == ROOT:
                offset = to_arm @ Vector(spec.get("loc", (0, 0, 0)))
                pb.location = REST[ROOT].inverted() @ offset
                pb.keyframe_insert("location", frame=frame)
            pb.scale = (1, 1, 1)
            pb.keyframe_insert("scale", frame=frame)
    arm.animation_data.action = None
    print("ACTION", name, frames[-1])


def pose(extra, base=None):
    base = {} if base is None else base
    out = {k: dict(v) for k, v in base.items()}
    for bone, spec in extra.items():
        merged = dict(out.get(bone, {}))
        for axis, value in spec.items():
            merged[axis] = merged.get(axis, 0) + value if axis != "loc" else value
        out[bone] = merged
    return out


exec(open(ANIMS, encoding="utf-8").read(), {"make_action": make_action, "pose": pose, "math": math})
print("ACTIONS", sorted(a.name for a in bpy.data.actions))

bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
for o in bpy.data.objects:
    if o.type == "MESH":
        o.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_skins=True, export_image_format="AUTO", export_yup=True)
print("EXPORTED", DST)
