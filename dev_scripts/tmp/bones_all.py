import bpy, sys
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.import_scene.gltf(filepath=argv[0])
for o in bpy.context.scene.objects:
    if o.type == "ARMATURE":
        for b in o.data.bones:
            h = o.matrix_world @ b.head_local; t = o.matrix_world @ b.tail_local
            if "Hand" in b.name and len(b.name) > 9 and b.name not in ("LeftHand", "RightHand"):
                continue
            print("B %-16s %6.2f %6.2f %6.2f -> %6.2f %6.2f %6.2f" % (b.name, *h, *t))
    if o.type == "MESH":
        print("MESH", o.name, len(o.data.polygons), [m.name for m in o.data.materials])
print("ACTIONS", [a.name for a in bpy.data.actions])
