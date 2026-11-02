# Окремі шматки сітки поблизу точки — щоб знайти зайвий "кіготь".
#   blender -b -P loose_parts.py -- <src.glb> x y z radius [remove_ids] [dst.glb]
import sys
import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC = argv[0]
center = Vector((float(argv[1]), float(argv[2]), float(argv[3])))
radius = float(argv[4])
remove = [int(v) for v in argv[5].split(",")] if len(argv) > 5 and argv[5] else []
DST = argv[6] if len(argv) > 6 else ""
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
mesh = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.polygons))
bm = bmesh.new()
bm.from_mesh(mesh.data)
bm.verts.ensure_lookup_table()
seen = set()
parts = []
for v in bm.verts:
    if v.index in seen:
        continue
    stack = [v]
    comp = []
    seen.add(v.index)
    while stack:
        cur = stack.pop()
        comp.append(cur.index)
        for e in cur.link_edges:
            o = e.other_vert(cur)
            if o.index not in seen:
                seen.add(o.index)
                stack.append(o)
    parts.append(comp)
mw = mesh.matrix_world
print("PARTS", len(parts))
near = []
for i, comp in enumerate(parts):
    pts = [mw @ bm.verts[k].co for k in comp]
    c = sum(pts, Vector()) / len(pts)
    if (c - center).length < radius:
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        near.append(i)
        print("PART %d verts %d center (%.3f %.3f %.3f) size (%.3f %.3f %.3f)" % (
            i, len(comp), c.x, c.y, c.z, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z))
if remove and DST:
    kill = set()
    for i in remove:
        kill.update(parts[i])
    bmesh.ops.delete(bm, geom=[bm.verts[k] for k in kill], context="VERTS")
    bm.to_mesh(mesh.data)
    bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True)
    print("REMOVED", len(kill), "EXPORTED", DST)
