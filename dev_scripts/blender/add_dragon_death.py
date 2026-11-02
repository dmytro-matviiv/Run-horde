# Дракону — анімація смерті (у наборі Rodin її немає): хитається, падає
# на бік, голова й хвіст опускаються.
#   blender -b -P add_dragon_death.py -- <src.glb> <dst.glb>
import math
import sys
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
bpy.context.scene.render.fps = 24
arm.animation_data_create()
action = bpy.data.actions.new("Death")
action.use_fake_user = True
arm.animation_data.action = action
for act in bpy.data.actions:
    act.use_fake_user = True

# Кадр: (крен на бік, градуси; опускання, м; нахил шиї вниз, градуси).
KEYS = [(0, 0.0, 0.0, 0.0), (8, -8.0, 0.0, -10.0), (16, 10.0, -0.05, -20.0), (30, 70.0, -0.25, -35.0),
        (40, 84.0, -0.32, -40.0), (52, 86.0, -0.33, -42.0)]


def set_world(pb, matrix):
    pb.matrix = matrix
    bpy.context.view_layer.update()


for frame, roll, drop, neck in KEYS:
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    hips = arm.pose.bones["Hips"]
    rest = hips.bone.matrix_local
    pivot = rest.to_translation()
    turn = Matrix.Translation(pivot + Vector((0, 0, drop))) @ Matrix.Rotation(math.radians(roll), 4, "Y") @ Matrix.Translation(-pivot)
    set_world(hips, turn @ rest)
    for name in ("Neck", "Neck1", "Head"):
        if name in arm.pose.bones:
            pb = arm.pose.bones[name]
            local = pb.matrix.copy()
            head = local.to_translation()
            bend = Matrix.Translation(head) @ Matrix.Rotation(math.radians(neck / 3.0), 4, "X") @ Matrix.Translation(-head)
            set_world(pb, bend @ local)
    for pb in arm.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)
arm.animation_data.action = None
print("ACTIONS", sorted(a.name for a in bpy.data.actions))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_skins=True, export_image_format="AUTO", export_yup=True)
print("EXPORTED", DST)
