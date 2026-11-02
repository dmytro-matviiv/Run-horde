import sys
import bpy
import numpy as np
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
mesh = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
rest = np.array([(mesh.matrix_world @ v.co)[:] for v in mesh.data.vertices])
edges = np.array([e.vertices[:] for e in mesh.data.edges])
r = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
for act in bpy.data.actions:
    arm.animation_data.action = act
    lo, hi = act.frame_range
    worst = 0.0; n2 = 0; minz = 9
    for f in range(int(lo), int(hi) + 1, 3):
        bpy.context.scene.frame_set(f)
        ev = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        posed = np.array([(mesh.matrix_world @ v.co)[:] for v in ev.data.vertices])
        p = np.linalg.norm(posed[edges[:, 0]] - posed[edges[:, 1]], axis=1)
        ext = p - r
        worst_ext = max(globals().get("worst_ext", 0), ext.max()); globals()["worst_ext"] = worst_ext
        globals()["n5"] = max(globals().get("n5", 0), int((ext > 0.04).sum()))
        ratio = p / np.maximum(r, 1e-4)
        ratio[r < 0.004] = 1
        worst = max(worst, ratio.max()); n2 = max(n2, int((ratio > 1.8).sum()))
        minz = min(minz, posed[:, 2].min())
    print("STRETCH %-10s max %.2f  edges>1.8x %4d  ext %.3f m, >4cm %d" % (act.name, worst, n2, globals()["worst_ext"], globals()["n5"])); globals()["worst_ext"] = 0; globals()["n5"] = 0
