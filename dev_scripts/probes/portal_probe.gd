extends Node
## Тимчасово (test_env): (1) де стане портал у кожному данжі; (2) рівень
## --level=N: убити боса, кадри порталу й стрілки з різних місць.
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
		if _dungeon != null:
			for node in _dungeon.get_node("HUD").get_children():
				if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
					ProbeUtil.press_first_card(node)
func _ready() -> void:
	PerfSettings.persist_settings = false
	for i in DungeonLevels.get_level_count():
		var level: Dictionary = DungeonLevels.get_level(i)
		var boss := Vector2i(-1, -1)
		for z in level.map.size():
			var x: int = String(level.map[z]).find("B")
			if x >= 0:
				boss = Vector2i(x, z)
		var wall := DungeonBuilder.portal_wall(level.map, boss)
		print("LEVEL %d boss %s -> %s" % [i, boss, wall])
	var lvl := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="): lvl = a.get_slice("=", 1).to_int()
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, lvl)
	GameState.dungeon_level = lvl
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	var boss_spot: Vector3 = _dungeon.get("_boss_spot")
	# Мега-бос виходить, лише коли герой у його залі.
	_player.global_position = boss_spot + Vector3(0, 0.2, 3.0)
	await _wait(5.0)
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		if e.kind == Enemy3D.Kind.BOSS:
			e.take_damage(10000000.0)
	await _wait(0.2)
	# Бос буває схований (під землею, у тумані) — б'ємо, доки не впаде.
	for attempt in 40:
		if _dungeon.get("_exit_open"):
			break
		for e in _dungeon.find_children("*", "Enemy3D", true, false):
			if e.is_alive():   # і стовпи-обереги, що захищають боса
				e.take_damage(10000000.0)
		await _wait(0.25)
	await _wait(2.5)
	var exit: Vector3 = _dungeon.get("_exit_position")
	print("EXIT at ", exit, " open ", _dungeon.get("_exit_open"))
	# Кадри: біля боса, біля входу (стрілка), перед порталом.
	var spots := [boss_spot + Vector3(0, 0.2, 2.0), _player.global_position, exit + Vector3(0, 0.2, 0)]
	_player.global_position = boss_spot + Vector3(0, 0.2, 2.0)
	await _wait(1.2)
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/portal_%d_a.png" % lvl)
	_player.global_position = DungeonBuilder.cell_center(Vector2i(20, 15)) + Vector3(0, 0.2, 0) if lvl == 0 else _player.global_position
	await _wait(1.2)
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/portal_%d_b.png" % lvl)
	_player.global_position = exit + Vector3(0, 0.2, 0)
	await _wait(1.0)
	print("EXIT button ", _dungeon.exit_button.visible)
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/portal_%d_c.png" % lvl)
	get_tree().quit(0)
