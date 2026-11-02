# Рендер моделі спереду/збоку/зверху з виділеною маскою вершин (червоним).
#   blender -b --factory-startup -P mask_view.py -- <in.glb> <out_prefix> "<numpy вираз від x,y,z>"
# Координати — світові Blender (z угору, -y уперед), як у bones_all.py.
import sys
import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, EXPR = argv[0], argv[1], argv[2] if len(argv) > 2 else "x < -99"
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
mask = eval(EXPR)
print("MASK", int(mask.sum()), "of", len(co), "bbox", co.min(0).round(3), co.max(0).round(3))
if mask.any():
    print("MASK bbox", co[mask].min(0).round(3), co[mask].max(0).round(3))
sel = mesh.copy()
sel.data = mesh.data.copy()
bpy.context.scene.collection.objects.link(sel)
import bmesh
bm = bmesh.new()
bm.from_mesh(sel.data)
bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not mask[v.index]], context="VERTS")
bm.to_mesh(sel.data)
bm.free()
red = bpy.data.materials.new("red")
red.diffuse_color = (1, 0, 0, 1)
sel.data.materials.clear()
sel.data.materials.append(red)
sel.scale = (1.003, 1.003, 1.003)
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.render.resolution_x = 700
scene.render.resolution_y = 700
lo, hi = co.min(0), co.max(0)
center = Vector(((lo + hi) / 2).tolist())
size = float((hi - lo).max()) * 1.1
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = size
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
views = {"front": Vector((0, -1, 0)), "side": Vector((1, 0, 0)), "top": Vector((0, -0.25, 1)).normalized()}
for name, d in views.items():
    cam.location = center + d * size * 2
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = "%s_%s.png" % (OUT, name)
    bpy.ops.render.render(write_still=True)
print("DONE")
