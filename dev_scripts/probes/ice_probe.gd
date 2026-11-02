extends Node
## Тимчасово (test_env): вороги крижаної цитаделі — лише цифри.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
var _defs := {}
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		_player.max_hp = 99999.0
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _spawn(name: String, at: Vector3, extra := {}) -> Enemy3D:
	var def: Dictionary = _defs[name].duplicate(true)
	def["no_elite"] = true
	def.erase("group")
	def.merge(extra, true)
	return _dungeon.call("_spawn_enemy", at, def, false)
func _enemies(name: String) -> Array:
	return _dungeon.find_children("*", "Enemy3D", true, false).filter(func(e): return e.is_alive() and String(e.definition.get("name", "")) == name)
func _clear() -> void:
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		e.queue_free()
	await _wait(0.3)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, 2)
	GameState.dungeon_level = 2
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	for group in DungeonLevels.get_level(2).enemies.values():
		for d in group:
			_defs[String(d.name)] = d
	var sentinels := _enemies("Ожилий вартовий")
	var dormant := sentinels.filter(func(e): return e.is_dormant())
	print("PROBE вартових на рівні %d, сплять статуями %d, на місці статуй %d" % [sentinels.size(), dormant.size(), DungeonBuilder.sentinel_spots(DungeonLevels.get_level(2).map).size()])
	await _clear()
	var room := _player.global_position + Vector3(0, 0, -6.0)
	# 1. Вартовий.
	_player.current_hp = 99999.0
	var s := _spawn("Ожилий вартовий", room)
	await _wait(0.5)
	print("PROBE вартовий спить: %s" % s.is_dormant())
	_player.global_position = s.global_position + Vector3(0, 0.2, 2.5)
	var hp: float = _player.current_hp
	await _wait(1.2)
	print("PROBE вартовий прокинувся: %s, удар з розвороту зняв %.0f" % [not s.is_dormant(), hp - _player.current_hp])
	hp = _player.current_hp
	s.take_damage(1.0e9)
	await _wait(1.0)
	print("PROBE вартовий розпався: героя поруч поранило на %.0f" % (hp - _player.current_hp))
	await _clear()
	# 2. Голем.
	var g := _spawn("Крижаний голем", room)
	await _wait(0.4)
	var ghp: float = g.current_hp
	g.take_damage(30.0)
	print("PROBE голем: удар 30 по щиту — здоров'я %.0f -> %.0f, щит %.0f/%.0f" % [ghp, g.current_hp, g.get("_shield_hp"), g.get("_shield_max")])
	g.last_hit_source = &"fire_ring"
	g.take_damage(10.0)
	print("PROBE голем: вогонь — щит %.0f, вразливість x%.1f, здоров'я %.0f" % [g.get("_shield_hp"), g.get("_damage_taken"), g.current_hp])
	_player.global_position = g.global_position + Vector3(0, 0.2, 2.0)
	g.alert()
	await _wait(0.8)
	print("PROBE голем: аура сповільнює героя: %s (x%.2f)" % [_player.is_slowed(), _player.get("_slow_factor")])
	var rooted := false
	for i in 60 * 8:
		await get_tree().physics_frame
		if _player.is_rooted():
			rooted = true
			break
	print("PROBE голем: крижане кільце вморозило героя: %s" % rooted)
	await _clear()
	# 3. Таранник.
	var t := _spawn("Морозний таранник", room)
	_player.global_position = room + Vector3(0, 0.2, 6.0)
	t.alert()
	var stunned := false
	for i in 60 * 3:
		await get_tree().physics_frame
		if _player.get("_knock_left") > 1.0:
			stunned = true
			break
	print("PROBE таранник: підкат збив з ніг (на 2 с): %s" % stunned)
	await _wait(2.5)
	# Ставимо таранника й героя в лінію до стіни: герой перед стіною.
	var map: Array = DungeonLevels.get_level(2).map
	var cell := DungeonBuilder.cell_of(room)
	var dir := Vector2i(0, 1)
	while DungeonBuilder.is_walkable(map, cell.x + dir.x, cell.y + dir.y):
		cell += dir
	var wall_front := DungeonBuilder.cell_center(cell)
	_player.global_position = wall_front + Vector3(0, 0.2, -0.5) + Vector3(1.6, 0, 0)
	t.global_position = wall_front + Vector3(0, 0.2, -7.0)
	t.set("_charge_cooldown_left", 0.0)
	var wall_stun := false
	var double := 0.0
	for i in 60 * 10:
		await get_tree().physics_frame
		if t.get("_wall_stunned"):
			wall_stun = true
			var before: float = t.current_hp
			t.take_damage(10.0)
			double = before - t.current_hp
			break
	print("PROBE таранник: застряг об стіну %s, удар 10 зняв %.0f" % [wall_stun, double])
	await _clear()
	# 4. Чаклунка.
	var orc := _spawn("Морозний таранник", room + Vector3(1.5, 0, 0), {"abilities": []})
	orc.set_physics_process(false)
	var w := _spawn("Інейна чаклунка", room)
	_player.global_position = room + Vector3(0, 0.2, 7.0)
	w.alert()
	var armored := false
	var walls := 0
	var spears := 0
	for i in 60 * 9:
		await get_tree().physics_frame
		if orc.has_absorb():
			armored = true
		walls = maxi(walls, _enemies("Крижана стіна").size())
		for n in _dungeon.find_children("*", "Node3D", true, false):
			if n is EnemyProjectile and n.shape == "spear":
				spears += 1
	print("PROBE чаклунка: панцир на союзника %s, крижаних стін %d, кадрів зі списами %d" % [armored, walls, spears])
	await _clear()
	get_tree().quit(0)
