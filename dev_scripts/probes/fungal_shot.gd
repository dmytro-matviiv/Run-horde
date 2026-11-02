extends Node3D
## Тимчасово (лише в test_env): архітектура грибних нетрів без бою й HUD —
## уся геометрія рівня, світло й камера над залом із грибом-колоною.
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
	env.environment.ambient_light_color = Color(0.55, 0.7, 0.6)
	env.environment.ambient_light_energy = 0.9
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.8
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	var shots := 0
	for z in rows.size():
		var row: String = rows[z]
		for x in row.length():
			if shots >= 2:
				break
			if row[x] != "." or x % 6 != 0 or z % 6 != 0:
				continue
			var open := true
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				open = open and DungeonBuilder.is_walkable(rows, x + o.x, z + o.y)
			if not open:
				continue
			var target := Vector3(x * 2.0, 0.6, z * 2.0)
			camera.position = target + Vector3(0, 5.5, 4.5)
			camera.look_at(target)
			await get_tree().create_timer(0.6).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/fungal_col_%d.png" % shots)
			shots += 1
	print("SHOT ok ", shots)
	get_tree().quit(0)
