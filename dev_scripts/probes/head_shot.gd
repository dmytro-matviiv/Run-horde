extends Node3D
## Тимчасово (test_env): крупний план точки моделі з кількох боків.
##   -- --model=res://... --target=x,y,z --dist=0.8 --tag=x
func _ready() -> void:
	var path := ""
	var target := Vector3.ZERO
	var dist := 0.8
	var tag := "head"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="): path = a.get_slice("=", 1)
		if a.begins_with("--target="):
			var p := a.get_slice("=", 1).split(",")
			target = Vector3(float(p[0]), float(p[1]), float(p[2]))
		if a.begins_with("--dist="): dist = a.get_slice("=", 1).to_float()
		if a.begins_with("--tag="): tag = a.get_slice("=", 1)
	var model: Node3D = load(path).instantiate()
	add_child(model)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.15, 0.15, 0.18)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 40
	add_child(camera)
	var views := [Vector3(0, 0.2, 1), Vector3(-1, 0.3, 0.6), Vector3(-1, 0.2, -0.2), Vector3(1, 0.3, 0.6)]
	for i in views.size():
		camera.position = target + (views[i] as Vector3).normalized() * dist
		camera.look_at(target)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/%s_%d.png" % [tag, i])
	get_tree().quit(0)
