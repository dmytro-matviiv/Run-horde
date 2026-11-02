# Найвисунутіші вперед вершини голови (з кольором текстури) — пошук зайвого
# "кігтя" біля ока.  blender -b -P front_points.py -- <src.glb>
import sys
import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
mesh = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.polygons))
img = next(i for i in bpy.data.images if "diffuse" in i.name)
w, h = img.size
px = np.array(img.pixels[:]).reshape(h, w, 4)
uv = mesh.data.uv_layers.active.data
co = np.array([(mesh.matrix_world @ v.co)[:] for v in mesh.data.vertices])
vcol = np.zeros((len(co), 3))
for poly in mesh.data.polygons:
    for li in poly.loop_indices:
        vi = mesh.data.loops[li].vertex_index
        u, v = uv[li].uv
        vcol[vi] = px[int(min(max(v, 0), 0.999) * h), int(min(max(u, 0), 0.999) * w), :3]
head = (co[:, 2] > 0.85) & (co[:, 1] < -0.45)
print("HEAD verts", head.sum(), "y min", co[head, 1].min())
dark = head & (vcol.mean(1) < 0.25)
for x0 in np.arange(-0.4, 0.41, 0.05):
    sel = dark & (co[:, 0] >= x0) & (co[:, 0] < x0 + 0.05)
    if sel.sum():
        print("x %.2f..%.2f dark %d  y %.2f..%.2f  z %.2f..%.2f" % (x0, x0 + 0.05, sel.sum(), co[sel, 1].min(),
              co[sel, 1].max(), co[sel, 2].min(), co[sel, 2].max()))
