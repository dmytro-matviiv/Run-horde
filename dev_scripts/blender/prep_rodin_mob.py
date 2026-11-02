# Rodin rigged mob -> game-ready mob.
#   blender -b --factory-startup -P prep_rodin_mob.py -- <src.glb> <dst.glb> <target_tris> <rename "Src=Dst,...">
# - finger bones merged into the hand (weights) and removed: mobile skinning;
# - mesh decimated to target_tris (weights interpolated by Decimate);
# - textures 1K, metallic-roughness map dropped (constant rough);
# - actions renamed to the game's names (Idle, Walk, Run, Weapon, Jump, HitReact, Death...),
#   others removed.
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST, TARGET = argv[0], argv[1], int(argv[2])
RENAME = dict(pair.split("=") for pair in argv[3].split(",")) if len(argv) > 3 else {}
# Обрізка кадрів "Weapon=12-50,Jump=4-64" і пришвидшення "Jump=1.6" (після перейменування).
TRIM = {k: tuple(int(x) for x in v.split("-")) for k, v in (p.split("=") for p in argv[4].split(","))} if len(argv) > 4 and argv[4] else {}
SPEED = {k: float(v) for k, v in (p.split("=") for p in argv[5].split(","))} if len(argv) > 5 and argv[5] else {}
# Копії дій до обрізки: "Jump>Windup" — з однієї анімації дві (присід і стрибок).
DUP = dict(p.split(">") for p in argv[6].split(",")) if len(argv) > 6 and argv[6] else {}
# Наскільки знизити підскок кореня: "Jump=0.5" — удвічі нижчий стрибок.
LIFT = {k: float(v) for k, v in (p.split("=") for p in argv[7].split(","))} if len(argv) > 7 and argv[7] else {}
# Дії, у яких корінь (Hips) лишається на місці: рухом керує гра.
IN_PLACE = ("Idle", "Run", "Walk", "Weapon", "Weapon2", "Jump", "HitReact", "Roar", "Charge", "Slide", "Slam", "Cast", "Support", "Windup", "Fly", "Breath", "Tail", "Wing", "Land")


def fcurves(act):
    try:
        return list(act.fcurves)
    except AttributeError:
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    out.extend(bag.fcurves)
        return out


def prepare_action(act):
    curves = fcurves(act)
    name = act.name
    if name in TRIM:
        first, last = TRIM[name]
        for fc in curves:
            for k in list(fc.keyframe_points)[::-1]:
                if k.co[0] < first - 0.01 or k.co[0] > last + 0.01:
                    fc.keyframe_points.remove(k)
            for k in fc.keyframe_points:
                k.co[0] -= first
                k.handle_left[0] -= first
                k.handle_right[0] -= first
    if name in SPEED:
        factor = 1.0 / SPEED[name]
        for fc in curves:
            for k in fc.keyframe_points:
                k.co[0] *= factor
                k.handle_left[0] *= factor
                k.handle_right[0] *= factor
    if name in IN_PLACE:
        for fc in curves:
            if fc.data_path != 'pose.bones["Hips"].location':
                continue
            points = list(fc.keyframe_points)
            if not points:
                continue
            first_value = points[0].co[1]
            last_value = points[-1].co[1]
            t0, t1 = points[0].co[0], points[-1].co[0]
            for k in points:
                if fc.array_index in (0, 2):
                    # Уперед і вбік — стоїть на місці.
                    k.co[1] = first_value
                    k.handle_left[1] = first_value
                    k.handle_right[1] = first_value
                elif name in LIFT:
                    lifted = first_value + (k.co[1] - first_value) * LIFT[name]
                    shift = lifted - k.co[1]
                    k.co[1] = lifted
                    k.handle_left[1] += shift
                    k.handle_right[1] += shift
                elif name in ("Run", "Walk", "Idle"):
                    # Вгору-вниз: прибрати повзучість, щоб цикл замикався.
                    drift = (last_value - first_value) * (k.co[0] - t0) / max(t1 - t0, 1e-6)
                    k.co[1] -= drift
                    k.handle_left[1] -= drift
                    k.handle_right[1] -= drift
            fc.update()
    frames = [k.co[0] for fc in curves for k in fc.keyframe_points]
    if frames:
        act.frame_range = (min(frames), max(frames))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
# Найбільший меш зі скіном (у файлі бувають і службові меші-форми кісток).
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
print("MESHES", [(o.name, len(o.data.polygons), len(o.vertex_groups)) for o in meshes])
mesh = max(meshes, key=lambda o: (len(o.vertex_groups) > 0, len(o.data.polygons)))
for o in meshes:
    if o is not mesh and len(o.vertex_groups) == 0 and o.parent is not None and o.parent.type == "ARMATURE":
        pass
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Pinky")

# 1) fingers -> hand weights
groups = {g.name: g for g in mesh.vertex_groups}
for side in ("Left", "Right"):
    hand = groups.get(side + "Hand")
    finger_groups = [g for n, g in groups.items() if n.startswith(side + "Hand") and any(f in n for f in FINGERS)]
    for v in mesh.data.vertices:
        extra = 0.0
        for ge in v.groups:
            g = mesh.vertex_groups[ge.group]
            if g in finger_groups:
                extra += ge.weight
        if extra > 0.0 and hand is not None:
            hand.add([v.index], extra, "ADD")
    for g in finger_groups:
        mesh.vertex_groups.remove(g)

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
removed = 0
for b in list(arm.data.edit_bones):
    if any(f in b.name for f in FINGERS) and "Hand" in b.name:
        arm.data.edit_bones.remove(b)
        removed += 1
bpy.ops.object.mode_set(mode="OBJECT")
print("FINGER BONES REMOVED", removed, "BONES LEFT", len(arm.data.bones))

# 1б) зброя — жорстко на кисті: усі вершини в коробці (світові координати
# в позі спокою) лише на одній кістці. Так меч/посох не розмазується.
# argv[8]: "RightHand:xmin,xmax,ymin,ymax,zmin,zmax;..."
RIGID = argv[8] if len(argv) > 8 else ""
for spec in [r for r in RIGID.split(";") if r]:
    bone, box = spec.split(":")
    x0, x1, y0, y1, z0, z1 = (float(v) for v in box.split(","))
    target = mesh.vertex_groups.get(bone) or mesh.vertex_groups.new(name=bone)
    ids = []
    for v in mesh.data.vertices:
        w = mesh.matrix_world @ v.co
        if x0 <= w.x <= x1 and y0 <= w.y <= y1 and z0 <= w.z <= z1:
            ids.append(v.index)
    for g in mesh.vertex_groups:
        if g != target:
            g.remove(ids)
    target.add(ids, 1.0, "REPLACE")
    print("RIGID", bone, len(ids))

# 2) decimate (above the armature modifier, applied)
tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
ratio = min(1.0, TARGET / max(tris, 1))
bpy.context.view_layer.objects.active = mesh
mod = mesh.modifiers.new("Decimate", "DECIMATE")
mod.ratio = ratio
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_move_to_index(modifier="Decimate", index=0)
bpy.ops.object.modifier_apply(modifier="Decimate")
tris_after = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
print("TRIS", tris, "->", tris_after)

# normalize weights, max 4 influences
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")

# 3) textures
for mat in mesh.data.materials:
    if mat is None or not mat.use_nodes:
        continue
    nodes = mat.node_tree.nodes
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is not None:
        for name in ("Metallic", "Roughness"):
            sock = bsdf.inputs[name]
            for link in list(sock.links):
                mat.node_tree.links.remove(link)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.8
for img in bpy.data.images:
    if img.size[0] > 1024:
        img.scale(1024, 1024)
        img.pack()
    print("IMAGE", img.name, tuple(img.size))

# 4) actions
for act in list(bpy.data.actions):
    base = act.name.split("|")[-1]
    # Точна назва важливіша за частину ("HumanRunning" не має з'їсти "HumanRunningSlide").
    hit = RENAME.get(base) or next((dst for src, dst in RENAME.items() if base in (src, "Human" + src)), None)
    if hit is None:
        hit = next((dst for src, dst in RENAME.items() if src in base and not any(
            other != src and other in base and len(other) > len(src) for other in RENAME)), None)
    if hit is None:
        bpy.data.actions.remove(act)
    else:
        act.name = hit
        act.use_fake_user = True
        if hit in DUP:
            copy = act.copy()
            copy.name = DUP[hit]
            copy.use_fake_user = True
            prepare_action(copy)
        prepare_action(act)
# Дві дії під одну назву (Run і Run.001) — друга зайва.
for act in list(bpy.data.actions):
    if "." in act.name:
        bpy.data.actions.remove(act)
print("ACTIONS", sorted(a.name for a in bpy.data.actions))

bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
mesh.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_skins=True, export_image_format="AUTO", export_yup=True)
print("EXPORTED", DST)
