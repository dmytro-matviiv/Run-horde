# Невеликий предмет (снаряд, реквізит) з Rodin -> легка модель для гри.
#   blender -b --factory-startup -P prep_prop.py -- <src.glb> <dst.glb> <трикутників> <розмір_м> <текстура_px> [світіння.png]
# Розмір — найбільший вимір моделі; центр моделі — у нулі (снаряд крутиться
# довкола себе). Карта metallic-roughness прибирається, світіння — додається.
import sys
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST, TARGET, SIZE, TEX = argv[0], argv[1], int(argv[2]), float(argv[3]), int(argv[4])
EMISSIVE = argv[5] if len(argv) > 5 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
mesh = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
mod = mesh.modifiers.new("dec", "DECIMATE")
mod.ratio = min(1.0, TARGET / tris)
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="dec")
print("TRIS", tris, "->", sum(len(p.vertices) - 2 for p in mesh.data.polygons))

corners = [Vector(v.co) for v in mesh.data.vertices]
lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
center = (lo + hi) * 0.5
scale = SIZE / max(hi - lo)
for v in mesh.data.vertices:
    v.co = (v.co - center) * scale
print("SIZE", tuple(round(x, 3) for x in (hi - lo) * scale))

for mat in mesh.data.materials:
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    for name in ("Metallic", "Roughness"):
        for link in list(bsdf.inputs[name].links):
            links.remove(link)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.8
    if EMISSIVE:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(EMISSIVE)
        links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.5
for img in list(bpy.data.images):
    if img.size[0] > TEX:
        img.scale(TEX, TEX)
    print("IMAGE", img.name, tuple(img.size))
# Неприв'язані картинки (metallic-roughness) у файл не підуть.
for img in list(bpy.data.images):
    if img.users == 0:
        bpy.data.images.remove(img)

bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_yup=True)
print("EXPORTED", DST)
