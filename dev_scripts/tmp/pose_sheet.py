# Аркуш поз: кілька "Дія:кадр" в одній картинці (сітка), вигляд спереду
# згори 3/4 (як ігрова камера) — швидко глянути, чи не рветься сітка.
#   blender -b --factory-startup -P pose_sheet.py -- <glb> <out.png> "Idle:0,Weapon:16,..." [yaw_deg]
import math
import sys

import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, SPEC = argv[0], argv[1], argv[2]
YAW = math.radians(float(argv[3])) if len(argv) > 3 else math.radians(25.0)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Icosphere"]
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and o not in meshes:
        bpy.data.objects.remove(o, do_unlink=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "TEXTURE"
SIZE = 360
scene.render.resolution_x = SIZE
scene.render.resolution_y = SIZE
scene.render.film_transparent = False
scene.view_settings.view_transform = "Standard"
pts = np.array([(m.matrix_world @ v.co)[:] for m in meshes for v in m.data.vertices])
lo, hi = pts.min(0), pts.max(0)
center = Vector(((lo + hi) / 2).tolist())
extent = float((hi - lo).max()) * 1.35
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = extent
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
d = Vector((math.sin(YAW), -math.cos(YAW), 0.9)).normalized()
cam.location = center + d * extent * 3
cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
items = [s.split(":") for s in SPEC.split(",")]
cols = min(4, len(items))
rows = (len(items) + cols - 1) // cols
sheet = np.ones((rows * SIZE, cols * SIZE, 4), dtype=np.float32)
for n, (action, frame) in enumerate(items):
    if arm is not None:
        arm.animation_data_create()
        arm.animation_data.action = bpy.data.actions[action]
    scene.frame_set(int(frame))
    path = OUT + ".tmp.png"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(SIZE, SIZE, 4)
    bpy.data.images.remove(img)
    r, c = n // cols, n % cols
    sheet[(rows - 1 - r) * SIZE:(rows - r) * SIZE, c * SIZE:(c + 1) * SIZE] = px
out = bpy.data.images.new("sheet", cols * SIZE, rows * SIZE, alpha=True)
out.pixels = sheet.ravel()
out.filepath_raw = OUT
out.file_format = "PNG"
out.save()
print("SHEET", OUT, len(items))
