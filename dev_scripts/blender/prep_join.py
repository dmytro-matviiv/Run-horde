# Модель з багатьох частин -> один меш для гри.
#   blender -b --factory-startup -P prep_join.py -- <src.glb> <dst.glb> <трикутників> <довжина_м>
# Усі меші зливаються в один (матеріали лишаються), спрощення до потрібної
# кількості трикутників, низ — на нулі, центр — над нулем, найбільший
# горизонтальний вимір — <довжина_м>. Друкує межі й осі для перевірки.
import sys
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST, TARGET, LENGTH = argv[0], argv[1], int(argv[2]), float(argv[3])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active
for o in list(bpy.context.scene.objects):
    if o != mesh:
        bpy.data.objects.remove(o, do_unlink=True)

tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
mod = mesh.modifiers.new("dec", "DECIMATE")
mod.ratio = min(1.0, TARGET / tris)
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="dec")
print("TRIS", tris, "->", sum(len(p.vertices) - 2 for p in mesh.data.polygons))

co = [v.co.copy() for v in mesh.data.vertices]
lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
size = hi - lo
scale = LENGTH / max(size.x, size.y)
center = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z))
for v in mesh.data.vertices:
    v.co = (v.co - center) * scale
print("SIZE x %.2f y(глибина) %.2f z(висота) %.2f" % (size.x * scale, size.y * scale, size.z * scale))
for mat in mesh.data.materials:
    print("MAT", mat.name)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=False, export_yup=True)
print("EXPORTED", DST)
