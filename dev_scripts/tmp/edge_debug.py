# Найгірше ребро дії на кадрі: обидві вершини з координатами й усіма вагами.
#   blender -b --factory-startup -P edge_debug.py -- <glb> <дія> <кадр>
import sys
import bpy
import numpy as np
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
mesh = max((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: len(o.data.polygons))
arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
rest = np.array([(mesh.matrix_world @ v.co)[:] for v in mesh.data.vertices])
used = set()
for p in mesh.data.polygons:
    for k in p.edge_keys:
        used.add(k)
edges = np.array(sorted(used))
r = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
arm.animation_data.action = bpy.data.actions[argv[1]]
bpy.context.scene.frame_set(int(argv[2]))
ev = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
posed = np.array([(mesh.matrix_world @ v.co)[:] for v in ev.data.vertices])
ext = np.linalg.norm(posed[edges[:, 0]] - posed[edges[:, 1]], axis=1) - r
for k in np.argsort(-ext)[:6]:
    print("EDGE ext %.3f" % ext[k])
    for i in edges[k]:
        v = mesh.data.vertices[i]
        w = ", ".join("%s %.2f" % (mesh.vertex_groups[g.group].name, g.weight) for g in v.groups if g.weight > 0.01)
        print("   v%d rest %s posed %s | %s" % (i, rest[i].round(3), posed[i].round(3), w))
