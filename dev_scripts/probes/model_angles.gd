extends Node3D
## Тимчасово (лише в test_env): модель з різних кутів на сірій підлозі.
const MODEL := "res://tools/kit_orig/SM_IceStatue.glb"
## [нахил камери вниз, поворот навколо, відстань, висота цілі]
var VIEWS := [[10, 0, 6.0, 1.4], [10, 90, 6.0, 1.4], [10, 180, 6.0, 1.4], [10, 270, 6.0, 1.4],
	[88, 0, 6.5, 1.2], [48, 0, 6.5, 1.2], [48, 135, 6.5, 1.2], [25, 0, 2.6, 2.2]]
func _ready() -> void:
	var path := MODEL
	var tag := "m"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="): path = a.get_slice("=", 1)
		if a.begins_with("--tag="): tag = a.get_slice("=", 1)
		if a.begins_with("--zoom="):
			var z := a.get_slice("=", 1).to_float()
			for v in VIEWS:
				v[2] *= z
				v[3] *= z
	var model: Node3D = load(path).instantiate()
	add_child(model)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lift="): model.position.y = a.get_slice("=", 1).to_float()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.35, 0.35, 0.38)
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.45, 0.5)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 50
	add_child(camera)
	for i in VIEWS.size():
		var v: Array = VIEWS[i]
		var pitch := deg_to_rad(v[0])
		var yaw := deg_to_rad(v[1])
		var target := Vector3(0, v[3], 0)
		camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * v[2]
		camera.look_at(target, Vector3.UP if v[0] < 85 else Vector3.FORWARD)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/%s_view_%d.png" % [tag, i])
	print("SHOT ok")
	get_tree().quit(0)
