extends Node3D
## Тимчасово (лише в test_env): розкладка Крижаної цитаделі — огляд згори
## всього рівня і знімки біля кожної статуї з кута ігрової камери.
func _ready() -> void:
	PerfSettings.persist_settings = false
	var level: Dictionary = DungeonLevels.get_level(2)
	var theme: Dictionary = level.get("theme", DungeonBuilder.DEFAULT_THEME)
	var rows: Array = level.map
	var root := Node3D.new()
	add_child(root)
	var result: Dictionary = DungeonBuilder.build_base(rows, root, theme)
	for chunk: Dictionary in result.chunks:
		DungeonBuilder.build_chunk(rows, chunk, 1.0, theme)
		chunk.node.visible = true
	var layout: Dictionary = DungeonBuilder._layout_for(rows)
	var kinds := {"main": 0, "edge": 0, "accent": 0}
	for cell in layout.floor:
		kinds[layout.floor[cell][0]] += 1
	print("LAYOUT статуй %d, брил %d, стійок %d, припасів %d, прапорів %d, скринь %d, плити %s" % [layout.landmarks.size(), layout.rocks.size(), layout.racks.size(), layout.supplies.size(), layout.banners.size(), layout.chests.size(), kinds])
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.03, 0.05)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.62, 0.75)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	sun.light_energy = 0.7
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 100.0
	camera.position = Vector3(49, 60, 49)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/citadel_overview.png")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 50.0
	var pitch := deg_to_rad(48.0)
	var i := 0
	var spots: Array = layout.landmarks.keys().slice(0, 1) + layout.racks.keys().slice(0, 3) + layout.supplies.keys().slice(0, 2) + layout.banners.keys().slice(0, 2)
	for cell: Vector2i in spots:
		var target := Vector3(cell.x * 2.0, 1.2, cell.y * 2.0 + (0.5 if OS.get_cmdline_user_args().has("--close") else 3.0))
		camera.position = target + Vector3(0, sin(pitch), cos(pitch)) * (4.5 if OS.get_cmdline_user_args().has("--close") else 10.5)
		camera.rotation = Vector3.ZERO
		camera.look_at(target)
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/citadel_spot_%d.png" % i)
		i += 1
	print("SHOT ok ", i)
	get_tree().quit(0)
