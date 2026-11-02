extends Node
## Тимчасово (test_env): розштовхування, втеча не в стіну, таран цілиться.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
var _defs := {}
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		_player.max_hp = 99999.0
		_player.current_hp = 99999.0
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _spawn(name: String, at: Vector3) -> Enemy3D:
	var def: Dictionary = _defs[name].duplicate(true)
	def["no_elite"] = true
	def.erase("group")
	return _dungeon.call("_spawn_enemy", at, def, false)
func _clear() -> void:
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		e.queue_free()
	await _wait(0.2)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	GameState.dungeon_level = 0
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	for group in DungeonLevels.get_level(0).enemies.values():
		for d in group:
			_defs[String(d.name)] = d
	await _clear()
	var room := DungeonBuilder.cell_center(Vector2i(19, 29))
	# 1. Двоє в одній точці.
	_player.global_position = room + Vector3(0, 0.2, -6.0)
	var a := _spawn("Склепний слиз", room)
	var b := _spawn("Склепний слиз", room)
	b.global_position = a.global_position
	await _wait(1.0)
	print("PROBE двоє в одній точці -> через 1 с між ними %.2f м" % a.global_position.distance_to(b.global_position))
	await _clear()
	# 2. Палій біля стіни (південна стіна зали), герой з півночі.
	var wall_spot := DungeonBuilder.cell_center(Vector2i(19, 32))
	var pyro := _spawn("Орк-палій", wall_spot)
	_player.global_position = wall_spot + Vector3(0, 0.2, -2.5)
	await _wait(1.2)
	print("PROBE палій біля стіни: від героя %.1f м (був 2.5), зсунувся вбік на %.1f м" % [pyro.global_position.distance_to(_player.global_position), absf(pyro.global_position.x - wall_spot.x)])
	await _clear()
	# 3. Таран: герой зміщується вбік під час замаху.
	var orc := _spawn("Орк-щитоносець", room + Vector3(0, 0, 3.0))
	_player.global_position = room + Vector3(0, 0.2, -3.0)
	orc.alert()
	var dir0 := Vector3.ZERO
	for i in 180:
		await get_tree().physics_frame
		if orc.get("_charge_state") == 1:
			if dir0 == Vector3.ZERO:
				dir0 = orc.get("_charge_dir")
				_player.global_position += Vector3(3.0, 0, 0)
		elif dir0 != Vector3.ZERO:
			break
	var dir1: Vector3 = orc.get("_charge_dir")
	print("PROBE таран: напрямок на початку %s, після зміщення героя %s (довернувся на %.0f°)" % [dir0, dir1, rad_to_deg(dir0.angle_to(dir1))])
	get_tree().quit(0)
