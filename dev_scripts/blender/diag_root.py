import sys, bpy
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
def fcurves(act):
    try:
        return list(act.fcurves)
    except AttributeError:
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    out.extend(bag.fcurves)
        return out
for act in bpy.data.actions:
    for fc in fcurves(act):
        if fc.data_path == 'pose.bones["Hips"].location':
            vals = [k.co[1] for k in fc.keyframe_points]
            frames = [k.co[0] for k in fc.keyframe_points]
            print(act.name, "idx", fc.array_index, "frames %.0f-%.0f" % (frames[0], frames[-1]), "min %.3f max %.3f first %.3f last %.3f" % (min(vals), max(vals), vals[0], vals[-1]))
            if "Jump" in act.name and fc.array_index == 1:
                step = max(1, len(vals) // 30)
                print("   Y:", " ".join("%d:%.2f" % (frames[i], vals[i]) for i in range(0, len(vals), step)))
            if "Weapon" == act.name.split("|")[-1] and fc.array_index in (0, 2):
                step = max(1, len(vals) // 25)
                print("   H%d:" % fc.array_index, " ".join("%d:%.2f" % (frames[i], vals[i]) for i in range(0, len(vals), step)))
print("FPS", bpy.context.scene.render.fps)
