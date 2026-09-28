extends Node

## Заміряє, наскільки важка сцена: скільки викликів малювання, вузлів і
## джерел світла, скільки часу процесор витрачає на кадр. Саме ці числа
## й з'їдають телефон.
##
## Запуск з командного рядка:
##   godot --path . res://tools/perf_probe.tscn -- --quality=0 --scene=dungeon
## quality: 0 низька, 1 середня, 2 висока; scene: dungeon або island.

const ProbeUtil := preload("res://tools/probe_util.gd")

const SCENES := {
	"dungeon": "res://scenes/dungeon/dungeon.tscn",
	"island": "res://scenes/world/base_island.tscn",
}

func _ready() -> void:
	PerfSettings.persist_settings = false
	# --level=N — який рівень данжу перевіряти (0, 1, 2).
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, argument.get_slice("=", 1).to_int())
			GameState.dungeon_level = argument.get_slice("=", 1).to_int()
	var options := _parse_args()
	var quality: int = int(options.get("quality", "2"))
	var scene_key: String = options.get("scene", "dungeon")
	PerfSettings.apply_quality(quality, false)
	# Міряємо чисту швидкість, без стелі кадрів і без очікування монітора:
	# інакше всі рівні впирались би в ту саму частоту екрана.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	var scene: Node = load(SCENES[scene_key]).instantiate()
	add_child(scene)
	await _dismiss_ability_choice(scene)
	# --no-ui: сховати інтерфейс, щоб побачити вартість самого 3D.
	if options.has("no-ui") and scene.has_node("HUD"):
		scene.get_node("HUD").visible = false
	# Даємо потоковому підвантаженню влаштуватись, а тоді міряємо
	# усталений стан, а не мить побудови.
	await get_tree().create_timer(5.0).timeout

	var worst := 100000.0
	var total_fps := 0.0
	var total_logic_ms := 0.0
	var samples := 240
	for i in samples:
		await get_tree().process_frame
		var fps := 1.0 / maxf(get_process_delta_time(), 0.0001)
		worst = minf(worst, fps)
		total_fps += fps
		total_logic_ms += (Performance.get_monitor(Performance.TIME_PROCESS)
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0

	var lights := 0
	for node in scene.find_children("*", "Light3D", true, false):
		if (node as Light3D).is_visible_in_tree():
			lights += 1
	var awake := 0
	for node in scene.find_children("*", "CharacterBody3D", true, false):
		if node is Enemy3D and (node as Node).is_physics_processing():
			awake += 1

	print("PERF[%s, якість %s]" % [scene_key, PerfSettings.get_quality_title()])
	print("PERF:   кадри середні %d, найгірші %d" % [int(total_fps / samples), int(worst)])
	print("PERF:   логіка+фізика %.2f мс на кадр" % (total_logic_ms / samples))
	print("PERF:   викликів малювання %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("PERF:   примітивів %d" % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("PERF:   вузлів у дереві %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("PERF:   увімкненого світла %d, ворогів не сплять %d" % [lights, awake])
	print("PERF:   роздільність 3D %d%%" % roundi(get_tree().root.scaling_3d_scale * 100.0))
	get_tree().quit(0)

## Данж починається з вибору здібності; обираємо першу-ліпшу, щойно
## вікно з'явиться (воно з'являється після збирання рівня).
func _dismiss_ability_choice(scene: Node) -> void:
	if not scene.has_node("HUD"):
		return
	for i in 200:
		await get_tree().process_frame
		for node in scene.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen"):
				ProbeUtil.press_first_card(node)
				get_tree().paused = false
				return

func _parse_args() -> Dictionary:
	var result := {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var parts := argument.substr(2).split("=", true, 1)
			result[parts[0]] = parts[1]
		elif argument.begins_with("--"):
			result[argument.substr(2)] = "1"
	return result
