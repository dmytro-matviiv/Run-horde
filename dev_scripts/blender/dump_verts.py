import sys, bpy, numpy as np
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
m = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = m
m.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
c = np.array([v.co[:] for v in m.data.vertices])
np.save(argv[1], c)
print("BOUNDS", c.min(0), c.max(0))
