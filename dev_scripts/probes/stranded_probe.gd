extends Node
## Тимчасово (test_env): ворог на меблях — (1) поява в центрі столу,
## (2) поставлений на верх коробки — чи зводиться на підлогу.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	GameState.dungeon_level = 0
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	await _wait(2.5)
	var box: CollisionShape3D = null
	for c in _dungeon.find_child("Obstacles", true, false).get_children():
		if String(c.name).begins_with("Decor"):
			box = c
			break
	var def: Dictionary = {}
	for d in DungeonLevels.get_level(0).enemies.r:
		if String(d.name) == "Склепний чаклун":
			def = d.duplicate(true)
	def["no_elite"] = true
	var center := box.global_position
	var e: Enemy3D = _dungeon.call("_spawn_enemy", Vector3(center.x, 0.0, center.z), def, false)
	await _wait(0.3)
	print("PROBE поява на столі: зсунуто на %.2f м, висота %.2f" % [Vector2(e.global_position.x - center.x, e.global_position.z - center.z).length(), e.global_position.y])
	_dungeon.get_node("Player").global_position = Vector3(center.x + 4.0, 0.3, center.z)
	e.global_position = Vector3(center.x, 2.8, center.z)
	await _wait(2.0)
	print("PROBE поставлений зверху: висота %.2f, від центру %.2f м" % [e.global_position.y, Vector2(e.global_position.x - center.x, e.global_position.z - center.z).length()])
	print("PROBE пауза ", get_tree().paused)
	print("PROBE фізика %s, спить %s, stranded_left %.2f, busy %s" % [e.is_physics_processing(), e.is_sleeping(), e.get("_stranded_left"), e.abilities.map(func(a): return a.is_busy())])
	get_tree().quit(0)
