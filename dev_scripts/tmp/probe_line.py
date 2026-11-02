# Вершини біля лінії в площині xz: для смуг по z друкує x/y (центр, межі).
#   blender -b --factory-startup -P probe_line.py -- <in.glb> ax az bx bz radius
import sys
import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
SRC = argv[0]
ax, az, bx, bz, rad = (float(v) for v in argv[1:6])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
mesh = max((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: len(o.data.polygons))
for o in list(bpy.context.scene.objects):
    if o is not mesh:
        bpy.data.objects.remove(o, do_unlink=True)
mesh.modifiers.clear()
mesh.parent = None
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
co = np.array([v.co[:] for v in mesh.data.vertices])
a = np.array([ax, az]); b = np.array([bx, bz])
p = co[:, [0, 2]]
d = b - a
t = np.clip(((p - a) @ d) / (d @ d), 0, 1)
dist = np.linalg.norm(p - (a + t[:, None] * d), axis=1)
near = dist < rad
for k in range(12):
    sel = near & (t >= k / 12) & (t < (k + 1) / 12)
    if sel.any():
        c = co[sel]
        print("T %.2f n %4d  x %.3f..%.3f  y %.3f..%.3f (med %.3f)  z %.3f..%.3f" % (
            k / 12, sel.sum(), c[:, 0].min(), c[:, 0].max(), c[:, 1].min(), c[:, 1].max(), np.median(c[:, 1]), c[:, 2].min(), c[:, 2].max()))
