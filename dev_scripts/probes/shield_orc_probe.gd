extends Node
## Тимчасово (test_env): Орк-щитоносець. (1) удар спереду / ззаду; (2) таран
## збиває з ніг; (3) таран у стіну — оглушений 2 с, щит не захищає.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
var _orc: Enemy3D
var _def: Dictionary
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		_player.max_hp = 1000.0
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/shorc_%s.png" % name)
func _spawn(cell: Vector2i, face: Vector3) -> Enemy3D:
	if _orc != null and is_instance_valid(_orc):
		_orc.queue_free()
		await _wait(0.1)
	_orc = _dungeon.call("_spawn_enemy", DungeonBuilder.cell_center(cell) + Vector3(0, 0.2, 0), _def, false)
	_orc.get("_model").rotation.y = atan2(face.x, face.z)
	await _wait(0.1)
	return _orc
func _ready() -> void:
	PerfSettings.persist_settings = false
	GameState.dungeon_level = 0
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		e.queue_free()
	for d in DungeonLevels.get_level(0).enemies.m:
		if String(d.name) == "Орк-щитоносець":
			_def = d.duplicate(true)
	# 1. Спереду й ззаду (герой стоїть, бʼє скриптом).
	for side in ["спереду", "ззаду"]:
		await _spawn(Vector2i(19, 29), Vector3(0, 0, -1))
		var offset := Vector3(0, 0, -2.0) if side == "спереду" else Vector3(0, 0, 2.0)
		_player.global_position = _orc.global_position + offset
		_orc.set_physics_process(false)
		var hp := _orc.current_hp
		_player.deal_damage(_orc, 1.0, Vector3.ZERO, false)
		print("PROBE удар %s: шкода %.1f" % [side, hp - _orc.current_hp])
		_orc.set_physics_process(true)
	# 2. Таран у героя посеред зали.
	await _spawn(Vector2i(19, 31), Vector3(0, 0, -1))
	_player.global_position = DungeonBuilder.cell_center(Vector2i(19, 27)) + Vector3(0, 0.2, 0.5)
	_player.current_hp = 1000.0
	_orc.alert()
	var knocked := false
	var shots := 0
	for i in 240:
		await get_tree().physics_frame
		if _player.get("_knock_left") > 0.0 and not knocked:
			knocked = true
			print("PROBE таран: героя збито, здоров'я %.0f, відкидає %.1f м/с" % [_player.current_hp, Vector2(_player.velocity.x, _player.velocity.z).length()])
			await _shot("knock")
		if i % 20 == 10 and shots < 4:
			await _shot("charge_%d" % shots)
			shots += 1
		if knocked and i > 120:
			break
	print("PROBE таран влучив: ", knocked)
	# 3. Таран у стіну: герой перекочується вбік, орк — у стіну.
	await _spawn(Vector2i(17, 30), Vector3(0, 0, -1))
	_player.global_position = DungeonBuilder.cell_center(Vector2i(17, 27)) + Vector3(0, 0.2, -0.4)
	_player.current_hp = 1000.0
	_orc.set("_attack_left", 0.0)
	_orc.alert()
	var dodged := false
	var stunned_seen := 0.0
	for i in 300:
		await get_tree().physics_frame
		var state: int = _orc.get("_charge_state")
		if i % 15 == 0:
			print("   кадр %d стан %d позиція %s швидкість %.1f на стіні %s cd %.1f" % [i, state, _orc.global_position, Vector2(_orc.velocity.x, _orc.velocity.z).length(), _orc.is_on_wall(), _orc.get("_charge_cooldown_left")])
		if state == 1 and not dodged and _orc.get("_charge_left") < 0.25:
			_player.set_move_input(Vector2(1, 0))
			await get_tree().physics_frame
			_player.dodge()
			dodged = true
		if _orc.get("_wall_stunned"):
			if stunned_seen == 0.0:
				await _shot("stunned")
				# Оглушений — удар спереду повний.
				_player.set_move_input(Vector2.ZERO)
				_player.global_position = _orc.global_position + _orc.facing_vector() * 1.6
				var hp := _orc.current_hp
				_player.deal_damage(_orc, 1.0, Vector3.ZERO, false)
				print("PROBE оглушений, удар спереду: шкода %.1f" % (hp - _orc.current_hp))
			stunned_seen += 1.0 / 60.0
		elif stunned_seen > 0.0:
			break
	print("PROBE оглушення об стіну: %.2f с" % stunned_seen)
	get_tree().quit(0)
