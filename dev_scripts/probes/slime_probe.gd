extends Node
## Тимчасово (test_env): склепний слиз — калюжі й сповільнення, поділ на 2
## малих, малі вже не діляться.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		_player.max_hp = 1000.0
		_player.current_hp = 1000.0
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _slimes() -> Array:
	var out := []
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		if e.is_alive() and String(e.definition.get("name", "")).contains("лиз"):
			out.append(e)
	return out
func _ready() -> void:
	PerfSettings.persist_settings = false
	GameState.dungeon_level = 0
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		e.queue_free()
	var def: Dictionary = {}
	for d in DungeonLevels.get_level(0).enemies.m:
		if String(d.name) == "Склепний слиз":
			def = d.duplicate(true)
	def["no_elite"] = true
	var slime: Enemy3D = _dungeon.call("_spawn_enemy", DungeonBuilder.cell_center(Vector2i(17, 31)) + Vector3(0, 0.2, 0), def, false)
	_player.global_position = DungeonBuilder.cell_center(Vector2i(21, 27)) + Vector3(0, 0.2, 0)
	slime.alert()
	await _wait(4.0)
	var puddles := _dungeon.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() == preload("res://scenes/dungeon/hazards/slime_puddle.gd"))
	print("PROBE калюж за 4 с: ", puddles.size())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/slime_trail.png")
	if puddles.size() > 0:
		var p: Node3D = puddles[0]
		slime.set_physics_process(false)
		_player.global_position = p.global_position + Vector3(0, 0.2, 0)
		await _wait(0.4)
		print("PROBE у калюжі: сповільнений %s, множник %.2f" % [_player.is_slowed(), _player.get("_slow_factor")])
		slime.set_physics_process(true)
	slime.take_damage(9999.0)
	await _wait(1.6)
	var kids := _slimes()
	print("PROBE після смерті: малих слизів ", kids.size(), " ", kids.map(func(k): return "%s h%.0f" % [k.definition.name, k.max_hp]))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/slime_split.png")
	for k in kids:
		k.take_damage(9999.0)
	await _wait(1.6)
	print("PROBE після смерті малих: слизів ", _slimes().size())
	get_tree().quit(0)
