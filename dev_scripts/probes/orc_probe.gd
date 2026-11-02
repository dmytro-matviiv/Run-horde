extends Node
## Тимчасово (test_env): Орк-рубака на 1-му рівні. (1) стоїть за 3 м —
## ривок влучає; (2) перекат у мить стрибка — промах; (3) зграя з трьох —
## швидші удари й червоне коло; кадри замаху й стрибка.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
var _orc: Enemy3D
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _orcs() -> Array:
	var out := []
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		if e.is_alive() and String(e.definition.get("name", "")) == "Орк-рубака":
			out.append(e)
	return out
func _ready() -> void:
	PerfSettings.persist_settings = false
	GameState.dungeon_level = 0
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	print("PROBE рубак на рівні: ", _orcs().size())
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		e.queue_free()
	await _wait(0.2)
	var spot := DungeonBuilder.cell_center(Vector2i(19, 28)) + Vector3(0, 0.2, 0)
	var orc_def: Dictionary = {}
	for d in DungeonLevels.get_level(0).enemies.m:
		if String(d.name) == "Орк-рубака":
			orc_def = d.duplicate(true)
	orc_def.erase("group")
	orc_def["no_elite"] = true
	var orc: Enemy3D = _dungeon.call("_spawn_enemy", spot, orc_def, false)
	_orc = orc
	await _wait(0.5)
	_player.health_changed.connect(func(c: float, _m: float) -> void:
		print("PROBE   удар по герою: hp %.1f, прийом '%s', у стрибку %s, відстань %.2f, перекат %.2f" % [c, _orc.get("_special"), _orc.abilities[0].get("_busy"), _orc.global_position.distance_to(_player.global_position), _player.get("_roll_left")]))
	for run in ["стоїть", "перекат"]:
		if run != "стоїть":
			orc.queue_free()
			await _wait(0.2)
			orc = _dungeon.call("_spawn_enemy", spot, orc_def, false)
			await _wait(0.3)
		_orc = orc
		orc.global_position = spot
		_player.global_position = spot + Vector3(0, 0, 3.0)
		_player.max_hp = 1000.0
		_player.current_hp = 1000.0
		var lunge = orc.abilities[0]
		lunge.set("_left", 0.0)
		orc.alert()
		var hp: float = _player.current_hp
		var t := 0.0
		var rolled := false
		var shot := 0
		while t < 2.2:
			await get_tree().physics_frame
			t += 1.0 / 60.0
			var windup: float = orc.get("_windup_left")
			if run == "перекат" and not rolled and lunge.get("_busy"):
				# Стрибок почався — перекат убік від рубаки.
				var away: Vector3 = (_player.global_position - orc.global_position).normalized()
				var side := Vector3(-away.z, 0, away.x)
				_player.set_move_input(Vector2(side.x, -side.z))
				await get_tree().physics_frame
				_player.dodge()
				rolled = true
			if run == "стоїть" and shot < 8 and int(t * 60) % 9 == 0 and t > 0.1:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/orc_fight_%d.png" % shot)
				shot += 1
		print("PROBE %s: здоров'я %.0f -> %.0f, ривок на перезарядці: %s" % [run, hp, _player.current_hp, lunge.get("_left") > 0.0])
		await _wait(1.5)
	# Зграя: троє поруч.
	var scene_orcs := []
	for i in 2:
		var def: Dictionary = orc_def
		var other: Enemy3D = _dungeon.call("_spawn_enemy", spot + Vector3(1.5 * (i + 1), 0, 0), def, false)
		scene_orcs.append(other)
	await _wait(1.2)
	print("PROBE зграя: швидкість ударів x%.2f, червоне коло: %s" % [orc.get("_pack_factor"), orc.get("_pack_marker") != null and orc.get("_pack_marker").visible])
	for o in _orcs():
		if o != orc:
			o.take_damage(9999.0)
	await _wait(1.0)
	for o in scene_orcs:
		print("PROBE   рубака живий: ", is_instance_valid(o) and o.is_alive(), " hp ", o.current_hp if is_instance_valid(o) else -1.0)
	print("PROBE зграю розбито: x%.2f (pack_left %.2f, фізика %s, живий %s, спить %s)" % [orc.get("_pack_factor"), orc.get("_pack_left"), orc.is_physics_processing(), orc.is_alive(), orc.is_sleeping()])
	get_tree().quit(0)
