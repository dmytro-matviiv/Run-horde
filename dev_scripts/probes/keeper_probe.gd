extends Node
## Тимчасово (test_env): Хранитель Склепів — прийоми й фази (лише цифри).
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		_player.max_hp = 99999.0
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _ready() -> void:
	PerfSettings.persist_settings = false
	GameState.dungeon_level = 0
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	var boss: Enemy3D = _dungeon.get("_boss")
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		if e != boss:
			e.queue_free()
	print("PROBE бос: %s, здоров'я %.0f" % [boss.display_name, boss.max_hp])
	_player.global_position = boss.global_position + Vector3(0, 0.2, 5.0)
	_player.current_hp = 99999.0
	boss.alert()
	var seen := {}
	var hp: float = _player.current_hp
	for i in 60 * 14:
		await get_tree().physics_frame
		var special: String = boss.get("_special")
		if special != "" and not seen.has(special):
			seen[special] = true
			print("PROBE прийом: %s (відстань %.1f)" % [special, boss.global_position.distance_to(_player.global_position)])
		for a in boss.abilities:
			if a.id == "chain_spin" and a.is_busy() and not seen.has("spin_busy"):
				seen["spin_busy"] = true
				print("PROBE ланцюг крутиться")
		# Ближче під кінець — щоб спрацював ланцюг.
		if i == 60 * 7:
			_player.global_position = boss.global_position + Vector3(0, 0.2, 2.0)
	print("PROBE фаза 1: героя вдарили на %.0f" % (hp - _player.current_hp))
	boss.take_damage(1.0e6)
	print("PROBE удар 1e6 у фазі 1: здоров'я %.0f з %.0f (поріг 60%% = %.0f)" % [boss.current_hp, boss.max_hp, boss.max_hp * 0.6])
	await _wait(0.6)
	print("PROBE фаза %d, герой оглушений %s" % [boss.phases.phase, _player.get("_knock_left") > 0.0])
	var counted := 0
	for i in 60 * 9:
		await get_tree().physics_frame
		var alive := 0
		for e in _dungeon.find_children("*", "Enemy3D", true, false):
			if e != boss and e.is_alive():
				alive += 1
		counted = maxi(counted, alive)
	print("PROBE саркофаги: ворогів вилізло %d, герой оглушений %s" % [counted, _player.get("_knock_left") > 0.0])
	for a in boss.abilities:
		if a.id == "sarcophagi":
			var cells := []
			for c in a.get("_coffins"):
				cells.append(DungeonBuilder.cell_of(c))
			var portal := DungeonBuilder.portal_wall(DungeonLevels.get_level(0).map, DungeonBuilder.cell_of(_dungeon.get("_boss_spot")))
			print("PROBE саркофаги в клітинках %s, лицем %s; портал лицем %s; бос у %s" % [cells, a.get("_inward"), portal.inward, DungeonBuilder.cell_of(boss.global_position)])
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		if e != boss:
			e.take_damage(1.0e9)
	boss.take_damage(1.0e6)
	print("PROBE удар 1e6 у фазі 2: здоров'я %.0f (поріг 30%% = %.0f)" % [boss.current_hp, boss.max_hp * 0.3])
	await _wait(1.5)
	var hp3: float = boss.current_hp
	boss.take_damage(10.0)
	print("PROBE удар 10 у фазі 3: %.0f -> %.0f" % [hp3, boss.current_hp])
	var env: Environment = _dungeon.get_node("WorldEnvironment").environment
	print("PROBE фаза %d, темрява %s, загальне світло %.2f, свічки %s" % [boss.phases.phase, _dungeon.get("_darkness"), env.ambient_light_energy, boss.get("_model").has_node("Candles")])
	_player.global_position = boss.global_position + Vector3(0, 0.2, 3.0)
	var pools := 0
	for i in 60 * 6:
		await get_tree().physics_frame
		for n in _dungeon.find_children("*", "Node3D", true, false):
			if n is LobShell:
				pools += 1
	print("PROBE свічки кинуто (кадрів польоту): ", pools)
	boss.take_damage(1.0e9)
	await _wait(2.5)
	print("PROBE після смерті: темрява %s, загальне світло %.2f" % [_dungeon.get("_darkness"), env.ambient_light_energy])
	get_tree().quit(0)
