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
def ws(i):
    return ", ".join("%s %.2f" % (groups[g.group], g.weight) for g in sorted(mesh.data.vertices[i].groups, key=lambda g: -g.weight)[:3])
# у позі — нижче 0.55 м і далеко вперед/назад від тіла (|y| > 0.2), не рука
far = (posed[:, 2] < 0.55) & (np.abs(posed[:, 1]) > 0.2)
c = Counter()
for i in np.nonzero(far)[0]:
    c[ws(i).split(" ")[0]] += 1
print("FAR", far.sum(), c.most_common(8))
for i in np.nonzero(far)[0][:12]:
    print(" rest", rest[i].round(3), "posed", posed[i].round(3), ws(i))
