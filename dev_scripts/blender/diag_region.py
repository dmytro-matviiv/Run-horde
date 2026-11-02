import sys
from collections import Counter
import bpy, numpy as np
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
mesh = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
rest = np.array([(mesh.matrix_world @ v.co)[:] for v in mesh.data.vertices])
arm.animation_data.action = bpy.data.actions[argv[1]]
bpy.context.scene.frame_set(int(argv[2]))
ev = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
posed = np.array([(mesh.matrix_world @ v.co)[:] for v in ev.data.vertices])
groups = {g.index: g.name for g in mesh.vertex_groups}
# Blender: -y = вперед, z = вгору
m = (-posed[:, 1] > 0.14) & (posed[:, 2] > 0.25) & (posed[:, 2] < 0.6)
cnt = Counter()
for i in np.nonzero(m)[0]:
    v = mesh.data.vertices[i]
    main = groups[max(v.groups, key=lambda g: g.weight).group] if v.groups else "-"
    cnt[main] += 1
print("REGION", m.sum(), cnt.most_common(6))
sel = np.nonzero(m)[0]
print("REST forward range", (-rest[sel, 1]).min().round(3), (-rest[sel, 1]).max().round(3), "height", rest[sel, 2].min().round(3), rest[sel, 2].max().round(3), "x", rest[sel, 0].min().round(3), rest[sel, 0].max().round(3))
