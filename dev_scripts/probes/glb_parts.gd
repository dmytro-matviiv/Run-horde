extends Node3D

## Тимчасовий (лише в test_env): кожна частина GLB окремим кадром.
func _ready() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var out: String = OS.get_cmdline_user_args()[1]
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_file(path, state)
	var scene := document.generate_scene(state)
	add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.2, 0.21, 0.24)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 35.0
	add_child(camera)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var index := 0
	for node in meshes:
		for other in meshes:
			(other as Node3D).visible = other == node
		var m := node as MeshInstance3D
		var box: AABB = m.global_transform * m.get_aabb()
		var radius := maxf(box.size.length() * 0.5, 0.02)
		camera.global_position = box.get_center() + Vector3(0.9, 0.6, 0.5).normalized() * radius / tan(deg_to_rad(17.5)) * 1.1
		camera.look_at(box.get_center())
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%03d.png" % [out, index])
		print("GALLERY %03d %s %s" % [index, m.name, box.size.snapped(Vector3.ONE * 0.01)])
		index += 1
	get_tree().quit(0)
