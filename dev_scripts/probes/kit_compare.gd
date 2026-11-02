extends Node3D
## Тимчасово (лише в test_env): оригінал набору (ліворуч) і легка версія
## (праворуч) поруч — чи збігається вигляд.
const PAIRS := [
	["res://tools/kit_orig/SM_Floor_A_Glow.glb", "res://assets/models/fungal/kit/floor_glow.glb"],
	["res://tools/kit_orig/SM_Wall_D_Shrooms.glb", "res://assets/models/fungal/kit/wall_shrooms.glb"],
	["res://tools/kit_orig/SM_Wall_C_Roots.glb", "res://assets/models/fungal/kit/wall_roots.glb"],
]
func _ready() -> void:
	for i in PAIRS.size():
		var orig: Node3D = load(PAIRS[i][0]).instantiate()
		orig.scale = Vector3.ONE * 0.5
		orig.position = Vector3(-1.3, 0, i * -2.6)
		add_child(orig)
		# Верх підлоги в оригіналі вивернутий — щоб узагалі побачити, малюємо з обох боків.
		for mesh_instance in orig.find_children("*", "MeshInstance3D", true, false):
			var mat: StandardMaterial3D = (mesh_instance as MeshInstance3D).mesh.surface_get_material(0).duplicate()
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			(mesh_instance as MeshInstance3D).material_override = mat
		var low: Node3D = load(PAIRS[i][1]).instantiate()
		low.position = Vector3(1.3, 0, i * -2.6)
		add_child(low)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.1, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 40
	add_child(camera)
	camera.position = Vector3(0, 7.5, 5.0)
	camera.look_at(Vector3(0, 0.6, -2.6))
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/kit_compare.png")
	print("SHOT ok")
	get_tree().quit(0)
