extends Node
## Вир Безодні й герой: (1) стоїть — зносить у центр і там спокійно,
## без трясіння; (2) тікає — вибирається; (3) вир зник — героя нікуди не
## жбурляє; (4) два вири й перекат усередині — без накопичення швидкості.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
var _failed := false
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		_player.max_hp = 99999.0
		_player.current_hp = 99999.0
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
func _ready() -> void:
	PerfSettings.persist_settings = false
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, 9)
	GameState.dungeon_level = 9
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.0)
	var level: Dictionary = DungeonLevels.get_level(9)
	var center := DungeonBuilder.cell_center(level.boss_arena.get_center())
	var world := _dungeon
	# 1. Стоїть за 3 м від центру.
	_player.global_position = center + Vector3(3.0, 0.2, 0.0)
	await _wait(0.3)
	HazardRift.spawn(world, center, _player, 4.5, 3.4, 0.0, 6.0)
	var max_speed := 0.0
	var max_jump := 0.0
	var last := _player.global_position
	for i in 240:
		await get_tree().physics_frame
		max_speed = maxf(max_speed, _flat(_player.velocity))
		max_jump = maxf(max_jump, _flat(_player.global_position - last))
		last = _player.global_position
	var dist := _flat(_player.global_position - center)
	print("PROBE стоїть: найбільша швидкість %.2f м/с, найбільший стрибок за кадр %.3f м, до центру %.2f м" % [max_speed, max_jump, dist])
	if max_speed > 4.0 or max_jump > 0.1:
		_failed = true
	# 2. Тікає (вправо по екрану/камері — будь-куди від центру).
	await _wait(2.5)   # вир закінчиться
	var after_speed := _flat(_player.velocity)
	print("PROBE вир зник: швидкість героя %.2f м/с" % after_speed)
	if after_speed > 0.5:
		_failed = true
	_player.global_position = center + Vector3(0.5, 0.2, 0.0)
	await _wait(0.2)
	HazardRift.spawn(world, center, _player, 4.5, 3.4, 0.0, 6.0)
	HazardRift.spawn(world, center + Vector3(0.3, 0, 0.3), _player, 4.5, 3.4, 0.0, 6.0)
	var start := _flat(_player.global_position - center)
	var best := start
	for dir in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
		_player.global_position = center + Vector3(0.5, 0.2, 0.0)
		_player.set_move_input(dir)
		await _wait(2.5)
		best = maxf(best, _flat(_player.global_position - center))
	_player.set_move_input(Vector2.ZERO)
	print("PROBE тікає з двох вирів: найдалі від центру %.2f м (радіус 4.5)" % best)
	if best < 4.5:
		_failed = true
	# 3. Перекат усередині вирів, тоді стоїть: без жбурляння.
	_player.global_position = center + Vector3(1.0, 0.2, 0.0)
	await _wait(0.2)
	_player.dodge()
	var peak := 0.0
	for i in 90:
		await get_tree().physics_frame
		if i > 60:
			peak = maxf(peak, _flat(_player.velocity))
	print("PROBE після перекату у вирі: найбільша швидкість %.2f м/с" % peak)
	if peak > 3.3:
		_failed = true
	print("RESULT: ", "FAIL" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)
