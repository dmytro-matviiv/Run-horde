# Для смуг по z: вершини, чий x біля лінії x(z) (від точки A до B у площині xz),
# гістограма y (кроком 0.04) — видно вузьке древко серед ширших частин тіла.
#   blender -b --factory-startup -P probe_yhist.py -- <in.glb> ax az bx bz halfwidth z0 z1 step
import sys
import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
SRC = argv[0]
ax, az, bx, bz, hw, z0, z1, step = (float(v) for v in argv[1:9])
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
x, y, z = co[:, 0], co[:, 1], co[:, 2]
zz = z0
while zz < z1:
    lx = ax + (bx - ax) * (zz - az) / (bz - az)
    sel = (z >= zz) & (z < zz + step) & (np.abs(x - lx) < hw)
    hist = {}
    for v in y[sel]:
        k = round(np.floor(v / 0.04) * 0.04, 2)
        hist[k] = hist.get(k, 0) + 1
    line = " ".join("%+.2f:%d" % (k, hist[k]) for k in sorted(hist))
    print("Z %.2f x~%.2f | %s" % (zz, lx, line))
    zz += step
