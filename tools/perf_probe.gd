extends Node

## Заміряє, наскільки важка сцена: скільки викликів малювання, вузлів і
## джерел світла. Саме ці числа й з'їдають телефон.

const SCENE := "res://scenes/dungeon/dungeon.tscn"

func _ready() -> void:
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	await get_tree().create_timer(3.0).timeout
	get_tree().paused = false
	await get_tree().create_timer(1.0).timeout

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
