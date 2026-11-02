# Rodin-модель зі скелетом: де кістки (світові координати спокою) і як
# розкладені вершини по висоті — щоб знайти зброю.
#   blender -b --factory-startup -P inspect_rodin.py -- <src.glb>
import sys
import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
mesh = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.polygons))
for b in arm.data.bones:
    if any(k in b.name for k in ("Hand", "ForeArm", "Head", "Hips", "Foot", "Spine2")) and not any(
            f in b.name for f in ("Thumb", "Index", "Middle", "Ring", "Pinky")):
        h = arm.matrix_world @ b.head_local
        print("BONE %-14s %6.2f %6.2f %6.2f" % (b.name, h.x, h.y, h.z))
co = np.array([(mesh.matrix_world @ v.co)[:] for v in mesh.data.vertices])
print("BOUNDS", co.min(0).round(2), co.max(0).round(2))
H = co[:, 2].max()
for z in np.linspace(H, 0, 22):
    s = co[np.abs(co[:, 2] - z) < H / 44]
    if len(s) == 0:
        continue
    xs = np.sort(s[:, 0])
    segs = []
    start = prev = xs[0]
    for x in xs[1:]:
        if x - prev > 0.04 * H:
            segs.append((start, prev))
            start = x
        prev = x
    segs.append((start, prev))
    print("z%.2f" % z, " ".join("[%.2f..%.2f y%.2f..%.2f]" % (
        a, b, s[(s[:, 0] >= a) & (s[:, 0] <= b)][:, 1].min(), s[(s[:, 0] >= a) & (s[:, 0] <= b)][:, 1].max())
        for a, b in segs))
