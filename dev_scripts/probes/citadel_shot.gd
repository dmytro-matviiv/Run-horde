extends Node3D
## Тимчасово (лише в test_env): Крижана цитадель з кута ігрової камери
## (відстань 10.5, нахил 48°) над залами зі статуями; кількість трикутників
## у кадрі — зі статуями й без (--plain: усі колони кам'яні).
func _ready() -> void:
	PerfSettings.persist_settings = false
	var plain := OS.get_cmdline_user_args().has("--plain")
	var level: Dictionary = DungeonLevels.get_level(2)
	var theme: Dictionary = level.get("theme", DungeonBuilder.DEFAULT_THEME)
	if plain:
		theme = theme.duplicate()
		theme.decor = "crypt"
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
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.7
	add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	var pitch := deg_to_rad(48.0)
	# Точки, над якими стоїть герой: велика зала й вхідна.
	var spots := [Vector3(24 * 2.0, 1.2, 16 * 2.0), Vector3(9 * 2.0, 1.2, 14 * 2.0), Vector3(24 * 2.0, 1.2, 38 * 2.0), Vector3(30 * 2.0, 1.2, 4 * 2.0)]
	for i in spots.size():
		var target: Vector3 = spots[i]
		camera.position = target + Vector3(0, sin(pitch), cos(pitch)) * 10.5
		camera.look_at(target)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		print("VIEW %d %s: трикутників %d, викликів %d" % [i, "plain" if plain else "statues", prims, draws])
		if not plain:
			get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/citadel_view_%d.png" % i)
	get_tree().quit(0)
