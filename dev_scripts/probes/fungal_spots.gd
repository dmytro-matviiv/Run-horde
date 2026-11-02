extends Node3D
## Тимчасово (лише в test_env): грибні нетрі в кількох місцях з кута
## ігрової камери — коридор, кути, зала боса.
func _ready() -> void:
	PerfSettings.persist_settings = false
	var level: Dictionary = DungeonLevels.get_level(1)
	var theme: Dictionary = level.get("theme", DungeonBuilder.DEFAULT_THEME)
	var rows: Array = level.map
	var root := Node3D.new()
	add_child(root)
	var result: Dictionary = DungeonBuilder.build_base(rows, root, theme)
	for chunk: Dictionary in result.chunks:
		DungeonBuilder.build_chunk(rows, chunk, 1.0, theme)
		chunk.node.visible = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.03, 0.03)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.7, 0.62)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.7
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 50
	add_child(camera)
	# Коридор (рівно два протилежні виходи) і вузол із кутом, де стіни сходяться.
	var targets: Array[Vector3] = []
	var corridor_found := false
	var corner_found := false
	for z in range(1, rows.size() - 1):
		var row: String = rows[z]
		for x in range(1, row.length() - 1):
			if not DungeonBuilder.is_walkable(rows, x, z):
				continue
			var n := DungeonBuilder.is_walkable(rows, x, z - 1)
			var s := DungeonBuilder.is_walkable(rows, x, z + 1)
			var w := DungeonBuilder.is_walkable(rows, x - 1, z)
			var e := DungeonBuilder.is_walkable(rows, x + 1, z)
			if not corridor_found and n and s and not w and not e and DungeonBuilder.is_walkable(rows, x, z + 2):
				targets.append(Vector3(x * 2.0, 0.5, z * 2.0))
				corridor_found = true
			# Опуклий кут: сусід по діагоналі — стіна, а обидва прямі — прохід.
			if not corner_found and n and w and not DungeonBuilder.is_walkable(rows, x - 1, z - 1) and x > 3 and z > 3:
				targets.append(Vector3(x * 2.0 - 1.0, 0.5, z * 2.0 - 1.0))
				corner_found = true
	targets.append(result.boss + Vector3(0, 0.5, 0))
	for i in targets.size():
		camera.position = targets[i] + Vector3(0, 7.0, 5.5)
		camera.look_at(targets[i])
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/fungal_spot_%d.png" % i)
	print("SHOT ok ", targets.size())
	get_tree().quit(0)
