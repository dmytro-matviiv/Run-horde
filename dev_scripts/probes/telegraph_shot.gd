extends Node3D
## Тимчасово (лише в test_env): нові попередження з арту в залі боса трьох
## данжів (темна підлога, світла крижана, фінальна) з кута ігрової камери.
## Аргументи: --level=N (кілька через кому).
func _ready() -> void:
	PerfSettings.persist_settings = false
	var levels := [0, 2, 14]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			levels = Array(arg.trim_prefix("--level=").split(",")).map(func(s): return int(s))
	for index in levels:
		await _shoot(index)
	get_tree().quit(0)

func _shoot(index: int) -> void:
	var level: Dictionary = DungeonLevels.get_level(index)
	var theme: Dictionary = level.get("theme", DungeonBuilder.DEFAULT_THEME)
	var rows: Array = level.map
	var root := Node3D.new()
	add_child(root)
	var result: Dictionary = DungeonBuilder.build_base(rows, root, theme)
	for chunk: Dictionary in result.chunks:
		DungeonBuilder.build_chunk(rows, chunk, PerfSettings.get_value("decor_density"), theme)
		chunk.node.visible = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.03, 0.05)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.62, 0.75)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.7
	root.add_child(sun)
	var c: Vector3 = result.boss
	c.y = DungeonBuilder.FLOOR_TOP + (0.4 if OS.get_cmdline_user_args().has("--high") else 0.05)
	var items := []
	var lava := CombatVfx.make_telegraph(Color(1.0, 0.45, 0.1, 0.9), 2.4, PI, true)
	items.append([lava, c + Vector3(-4.5, 0, -1.5), 0.0, 0.55])
	var cone := CombatVfx.make_telegraph(Color(1.0, 0.22, 0.15, 0.85), 2.6, deg_to_rad(55.0))
	items.append([cone, c + Vector3(0.5, 0, -3.5), PI, 0.5])
	var line := CombatVfx.make_line_telegraph(Color(1.0, 0.3, 0.2, 0.85), 8.0, 1.8, "chevrons", true)
	items.append([line, c + Vector3(4.5, 0, -1.0), 0.0, 0.4])
	var rune := CombatVfx.make_telegraph(Color(0.7, 0.25, 1.0, 0.9), 2.2, PI, true)
	items.append([rune, c + Vector3(-3.0, 0, 3.2), 0.0, 0.7])
	var green := CombatVfx.make_telegraph(Color(0.4, 0.9, 0.5, 0.9), 1.6, PI, true)
	items.append([green, c + Vector3(1.5, 0, 2.0), 0.0, 0.3])
	var flames := CombatVfx.make_line_telegraph(Color(1.0, 0.5, 0.15), 7.0, 1.5, "flames")
	items.append([flames, c + Vector3(7.5, 0, 2.5), PI * 0.5, 1.0])
	for item in items:
		var node: MeshInstance3D = item[0]
		root.add_child(node)
		node.global_position = item[1]
		node.rotation.y = item[2]
		node.set_instance_shader_parameter(&"progress", item[3])
	var camera := Camera3D.new()
	camera.fov = 50.0
	root.add_child(camera)
	var pitch := deg_to_rad(48.0)
	var target := c + Vector3(1.0, 0, 0)
	camera.position = target + Vector3(0, sin(pitch), cos(pitch)) * 14.0
	camera.look_at(target)
	camera.make_current()
	await get_tree().create_timer(0.7).timeout
	CombatVfx.impact_decal(root, c + Vector3(-1.0, 0, 5.5), 1.8, Color(1.0, 0.45, 0.1), 2.0)
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/telegraph_%d.png" % index)
	print("SHOT ", index)
	root.queue_free()
	await get_tree().process_frame
