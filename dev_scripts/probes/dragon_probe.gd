extends Node
## Тимчасово (test_env): Інейний Дракон — фази й прийоми (лише цифри).
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
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, 2)
	GameState.dungeon_level = 2
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	var boss: Enemy3D = _dungeon.get("_boss")
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		if e != boss:
			e.queue_free()
	print("PROBE бос %s, здоров'я %.0f" % [boss.display_name, boss.max_hp])
	_player.global_position = boss.global_position + Vector3(0, 0.2, 5.0)
	_player.current_hp = 99999.0
	boss.alert()
	var seen := {}
	var frozen := false
	for i in 60 * 14:
		await get_tree().physics_frame
		var special: String = boss.get("_special")
		if special != "" and not seen.has(special):
			seen[special] = true
		if _player.is_rooted():
			frozen = true
		if i > 60 * 6 and i % 20 == 0 and i < 60 * 9:
			var tail = boss.abilities[0]
			var to_p: Vector3 = _player.global_position - boss.global_position
			to_p.y = 0
			print("   dbg dist %.1f back-angle %.0f ready %s attack_left %.2f windup %.2f stagger %.2f special '%s' aggro %s" % [to_p.length(), rad_to_deg((-boss.facing_vector()).angle_to(to_p.normalized())), tail.ready_to_use(), boss.get("_attack_left"), boss.get("_windup_left"), boss.get("_stagger_left"), boss.get("_special"), boss.get("_aggro")])
		if i == 60 * 6:
			# Зайти за спину — для удару хвостом.
			_player.global_position = boss.global_position - boss.facing_vector() * 2.5 + Vector3(0, 0.2, 0)
	print("PROBE фаза 1: хвіст %s, прийоми %s, дихання вморозило %s" % [seen.has("tail_sweep"), seen.keys(), frozen])
	var y0 := boss.global_position.y
	boss.take_damage(1.0e6)
	print("PROBE удар 1e6: здоров'я %.0f (поріг 65%% = %.0f)" % [boss.current_hp, boss.max_hp * 0.65])
	_player.global_position = boss.global_position + Vector3(0, 0.2, 5.0)
	var flying := false
	var invulnerable_hit := -1.0
	for i in 60 * 3:
		await get_tree().physics_frame
		if boss.global_position.y > y0 + 3.0 and not flying:
			flying = true
			var hp: float = boss.current_hp
			boss.take_damage(50.0)
			invulnerable_hit = hp - boss.current_hp
	print("PROBE фаза %d: злетів %s, удар у небі зняв %.0f" % [boss.phases.phase, flying, invulnerable_hit])
	for k in 5:
		await _wait(2.0)
		for a in boss.abilities:
			if a.id == "sky_fall":
				print("PROBE   небо: крок %d, лишилось %.1f, висота %.1f, фізика %s, спить %s" % [a.get("_step"), a.get("_time_left"), boss.global_position.y - y0, boss.is_physics_processing(), boss.is_sleeping()])
	var pillars := get_tree().get_nodes_in_group(&"ice_pillars").size()
	print("PROBE приземлився: висота %.1f, колон %d, оглушений (стоїть) %.1f с" % [boss.global_position.y - y0, pillars, boss.get("_stagger_left")])
	boss.take_damage(1.0e6)
	await _wait(0.6)
	var runes := 0
	for n in _dungeon.find_children("*", "MeshInstance3D", true, false):
		pass
	for a in boss.abilities:
		if a.id == "eternal_winter":
			runes = a.get("_runes").size()
	print("PROBE фаза %d: рун %d" % [boss.phases.phase, runes])
	# Стоїть на місці далеко від руни — мерзне.
	var far_spot := boss.global_position + Vector3(0, 0.2, 3.0)
	var rooted_at := -1.0
	for i in 60 * 10:
		await get_tree().physics_frame
		_player.global_position.x = far_spot.x
		_player.global_position.z = far_spot.z
		if _player.is_rooted() and rooted_at < 0.0:
			rooted_at = i / 60.0
	print("PROBE вічна зима: стоячи вмерз через %.1f с" % rooted_at)
	var winter = null
	for a in boss.abilities:
		if a.id == "eternal_winter":
			winter = a
	boss.take_damage(1.0e9)
	await _wait(4.0)
	var left := 0
	for r in winter.get("_runes"):
		if is_instance_valid(r):
			left += 1
	print("PROBE після смерті: рун лишилось %d, колон %d" % [left, get_tree().get_nodes_in_group(&"ice_pillars").size()])
	get_tree().quit(0)
