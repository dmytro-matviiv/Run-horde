extends Node
## Тимчасово (test_env): чи тверді прикраси. Для рівня: скільки коробок
## під прикраси; герой іде прямо на кілька з них — чи зупиняється.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		if _player != null:
			_player.max_hp = 99999.0
			_player.current_hp = 99999.0
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _ready() -> void:
	PerfSettings.persist_settings = false
	var lvl := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="): lvl = a.get_slice("=", 1).to_int()
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, lvl)
	GameState.dungeon_level = lvl
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(3.0)
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		e.queue_free()
	var obstacles: Node = _dungeon.find_child("Obstacles", true, false)
	var decor: Array = []
	for child in obstacles.get_children():
		if String(child.name).begins_with("Decor"):
			decor.append(child)
	print("PROBE рівень %d: твердих прикрас %d" % [lvl, decor.size()])
	var blocked := 0
	var tried := 0
	for i in range(0, decor.size(), maxi(1, decor.size() / 6)):
		var shape: CollisionShape3D = decor[i]
		var size: Vector3 = (shape.shape as BoxShape3D).size
		var center := shape.global_position
		# Підходимо з того боку, де вільно.
		for dir: Vector3 in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]:
			var start := center + dir * (maxf(size.x, size.z) * 0.5 + 1.6)
			var cell := DungeonBuilder.cell_of(start)
			if not DungeonBuilder.is_walkable(DungeonLevels.get_level(lvl).map, cell.x, cell.y):
				continue
			_player.global_position = Vector3(start.x, 0.3, start.z)
			_player.velocity = Vector3.ZERO
			await _wait(0.2)
			var push := -dir
			_player.set_move_input(Vector2(push.x, -push.z))
			# Камера може бути повернута: рух задаємо прямо у світі.
			var best := 99.0
			for f in 90:
				await get_tree().physics_frame
				_player.velocity.x = push.x * 5.0
				_player.velocity.z = push.z * 5.0
				var d := Vector2(_player.global_position.x - center.x, _player.global_position.z - center.z).length()
				best = minf(best, d)
			_player.set_move_input(Vector2.ZERO)
			tried += 1
			var stopped := best > minf(size.x, size.z) * 0.5 - 0.05
			if stopped:
				blocked += 1
			print("   прикраса %s розмір %s: найближче %.2f м -> %s" % [shape.name, size, best, "зупинився" if stopped else "ПРОЙШОВ"])
			break
	print("PROBE зупинився перед %d з %d" % [blocked, tried])
	get_tree().quit(0)
