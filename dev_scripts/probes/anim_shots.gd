extends Node3D
## Тимчасово (лише в test_env): кадри кожної анімації моделі.
##   -- --model=res://... --tag=x [--yaw=35]
func _ready() -> void:
	var path := ""
	var tag := "anim"
	var yaw := 35.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="): path = a.get_slice("=", 1)
		if a.begins_with("--tag="): tag = a.get_slice("=", 1)
		if a.begins_with("--yaw="): yaw = a.get_slice("=", 1).to_float()
	var model: Node3D = load(path).instantiate()
	add_child(model)
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	print("ANIMS ", player.get_animation_list())
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.25, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 40
	add_child(camera)
	var r := deg_to_rad(yaw)
	var zoom := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zoom="): zoom = a.get_slice("=", 1).to_float()
	camera.position = (Vector3(sin(r), 0.3, cos(r)) * 2.0 + Vector3(0, 0.6, 0)) * zoom
	camera.look_at(Vector3(0, 0.5, 0) * zoom)
	var samples := 5
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--samples="): samples = a.get_slice("=", 1).to_int()
		if a.begins_with("--only="): only = a.get_slice("=", 1)
	for anim_name in player.get_animation_list():
		var anim := player.get_animation(anim_name)
		if only != "" and not only.split(",").has(String(anim_name).get_slice("|", String(anim_name).get_slice_count("|") - 1)):
			continue
		print("ANIM ", anim_name, " length ", anim.length)
		for k in samples:
			player.play(anim_name)
			player.seek(anim.length * k / float(samples - 1) * 0.999, true)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/%s_%s_%d.png" % [tag, anim_name.get_slice("|", anim_name.get_slice_count("|") - 1), k])
	print("SHOT ok")
	get_tree().quit(0)
