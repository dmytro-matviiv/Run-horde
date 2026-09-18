extends Node

## Заміряє, наскільки важка сцена: скільки викликів малювання, вузлів і
## джерел світла. Саме ці числа й з'їдають телефон.

const SCENE := "res://scenes/dungeon/dungeon.tscn"

func _ready() -> void:
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	await get_tree().create_timer(3.0).timeout
	for node in scene.get_node("HUD").get_children():
		if node.has_signal("upgrade_chosen"):
			node.upgrade_chosen.emit(&"weapon_damage")
	get_tree().paused = false
	# Даємо потоковому підвантаженню влаштуватись, а тоді міряємо
	# усталений стан, а не мить побудови.
	await get_tree().create_timer(6.0).timeout

	var worst := 1000.0
	var total := 0.0
	var samples := 0
	for i in 120:
		await get_tree().process_frame
		var fps := Engine.get_frames_per_second()
		worst = minf(worst, fps)
		total += fps
		samples += 1
	print("PERF: кадри середні %d, найгірші %d" % [int(total / samples), int(worst)])

	var lights := 0
	var meshes := 0
	for node in scene.find_children("*", "Node3D", true, false):
		if node is OmniLight3D or node is SpotLight3D or node is DirectionalLight3D:
			lights += 1
		elif node is MeshInstance3D:
			meshes += 1

	print("PERF: викликів малювання %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("PERF: примітивів %d" % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("PERF: вузлів у дереві %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("PERF: мешів %d, джерел світла %d" % [meshes, lights])
	print("PERF: кадрів за секунду %d" % Engine.get_frames_per_second())
	get_tree().quit(0)
