# Розтяг ребер (лише тих, що мають грані) по кожній дії + де найгірше.
#   blender -b --factory-startup -P stretch2.py -- <glb>
import sys
import bpy
import numpy as np
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
for mesh in meshes:
    rest = np.array([(mesh.matrix_world @ v.co)[:] for v in mesh.data.vertices])
    used = set()
    for p in mesh.data.polygons:
        for k in p.edge_keys:
            used.add(k)
    edges = np.array(sorted(used))
    r = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
    groups = mesh.vertex_groups
    def dominant(i):
        v = mesh.data.vertices[i]
        best = max(v.groups, key=lambda g: g.weight, default=None)
        return groups[best.group].name if best else "-"
    for act in bpy.data.actions:
        arm.animation_data.action = act
        lo, hi = act.frame_range
        worst = 0.0; n5 = 0; where = None
        for f in range(int(lo), int(hi) + 1, 2):
            bpy.context.scene.frame_set(f)
            ev = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            posed = np.array([(mesh.matrix_world @ v.co)[:] for v in ev.data.vertices])
            p = np.linalg.norm(posed[edges[:, 0]] - posed[edges[:, 1]], axis=1)
            ext = p - r
            k = int(np.argmax(ext))
            if ext[k] > worst:
                worst = ext[k]
                a, b = edges[k]
                where = (f, rest[a].round(2), dominant(a), dominant(b))
            n5 = max(n5, int((ext > 0.04).sum()))
        print("STRETCH %-9s %-10s ext %.3f m, >4cm %4d  worst %s" % (mesh.name[:9], act.name, worst, n5, where))
