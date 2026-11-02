# Прибрати зайвий темний "кіготь" біля правого ока дракона (артефакт
# генерації): темні вершини правіше x0, висунуті вперед далі за y0.
#   blender -b -P remove_claw.py -- <src.glb> <dst.glb> x0 y0
import sys
import bpy
import bmesh
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST, X0, Y0 = argv[0], argv[1], float(argv[2]), float(argv[3])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
mesh = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.polygons))
img = next(i for i in bpy.data.images if "diffuse" in i.name)
w, h = img.size
px = np.array(img.pixels[:]).reshape(h, w, 4)
uv = mesh.data.uv_layers.active.data
dark_faces = []
for poly in mesh.data.polygons:
    pts = [mesh.matrix_world @ mesh.data.vertices[v].co for v in poly.vertices]
    if not all(p.x < X0 and p.y < Y0 and p.z > 0.9 for p in pts):
        continue
    cols = []
    for li in poly.loop_indices:
        u, v = uv[li].uv
        cols.append(px[int(min(max(v, 0), 0.999) * h), int(min(max(u, 0), 0.999) * w), :3].mean())
    if np.mean(cols) < 0.3:
        dark_faces.append(poly.index)
bm = bmesh.new()
bm.from_mesh(mesh.data)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in dark_faces], context="FACES")
bm.to_mesh(mesh.data)
print("REMOVED faces", len(dark_faces))
for act in bpy.data.actions:
    act.use_fake_user = True
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_skins=True, export_image_format="AUTO", export_yup=True)
print("EXPORTED", DST)
