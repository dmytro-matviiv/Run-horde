extends Node
## Тимчасово (test_env): 4-й данж (Кістяний Погост) — вороги й Кістяний
## Володар: чи спрацьовують усі прийоми (цифри, без картинок).
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
var _hits := 0

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	var first := true
	while first or Time.get_ticks_msec() < until:
		first = false
		await get_tree().physics_frame
		_player.max_hp = 99999.0
		_player.current_hp = 99999.0
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)

func _enemies() -> Array:
	return _dungeon.find_children("*", "Enemy3D", true, false).filter(func(e: Enemy3D) -> bool: return e.is_alive())

var _base := Vector3.ZERO

## Свіжий ворог цього типу біля старту (решту прибрано).
func _only(name: String) -> Enemy3D:
	for e: Enemy3D in _enemies():
		if e.kind != Enemy3D.Kind.BOSS and e.display_name != "":
			e.queue_free()
	for group: Array in DungeonLevels.LEVELS[3].enemies.values():
		for definition: Dictionary in group:
			if definition.name == name:
				return _dungeon._spawn_enemy(_base, definition, false)
	return null

func _ability(enemy: Enemy3D, id: String) -> EnemyAbility:
	for a in enemy.abilities:
		if a.id == id:
			return a
	return null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, 3)
	GameState.dungeon_level = 3
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	_player.health_changed.connect(func(current: float, _max: float) -> void:
		if current < 99999.0:
			_hits += 1)
	await _wait(2.5)
	var counts := {}
	for e: Enemy3D in _enemies():
		counts[e.display_name] = int(counts.get(e.display_name, 0)) + 1
		var anim := e.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if not counts.has("anim " + e.display_name):
			counts["anim " + e.display_name] = anim.get_animation_list() if anim != null else []
	print("PROBE вороги: %s" % counts)
	var boss: Enemy3D = null
	for e: Enemy3D in _enemies():
		if e.kind == Enemy3D.Kind.BOSS:
			boss = e
	var boss_home := boss.global_position
	_base = _player.global_position + Vector3(0, 0, -5.0)
	# Привид: зникнення, холодний дотик, крізь стіни.
	var ghost := _only("Кладовищенський привид")
	await _wait(0.1)
	print("PROBE привид: крізь стіни %s (маска %d)" % [ghost.phasing, ghost.collision_mask])
	_player.global_position = ghost.global_position + Vector3(0, 0.2, 6.0)
	ghost.alert()
	var vanished := false
	var chain_seen := false
	var chilled := false
	for i in 60 * 12:
		await _wait(0.0)
		if not is_instance_valid(ghost):
			break
		if ghost.is_hidden():
			vanished = true
			for m in ghost.find_children("*", "MeshInstance3D", true, false):
				if "Chain" in String(m.name) and m.visible and m.is_visible_in_tree():
					chain_seen = true
		if float(_player.get("_chill_left")) > 0.0:
			chilled = true
	print("PROBE привид: зник %s, видно ланцюг %s, холодний дотик %s, швидкість ударів %.2f" % [vanished, chain_seen, chilled, _player.attack_speed()])
	# Чаклун: скелети, стріли, втеча в могилу.
	var warlock := _only("Кістяний чаклун")
	await _wait(0.1)
	_player.global_position = warlock.global_position + Vector3(0, 0.2, 7.0)
	warlock.alert()
	var shots := 0
	for i in 60 * 6:
		await _wait(0.0)
		shots = maxi(shots, _dungeon.find_children("*", "EnemyProjectile", true, false).size())
	print("PROBE чаклун: скелетів %d, стріл у повітрі %d, анімація %s" % [warlock.summons_alive, shots, warlock.find_child("AnimationPlayer", true, false).current_animation])
	var before := warlock.global_position
	_player.global_position = warlock.global_position + Vector3(0, 0.2, 2.0)
	var escaped_hidden := false
	for i in 60 * 3:
		await _wait(0.0)
		if warlock.is_hidden():
			escaped_hidden = true
	print("PROBE чаклун: в могилу %s, перемістився на %.1f м, від героя %.1f м" % [escaped_hidden, before.distance_to(warlock.global_position), warlock.global_position.distance_to(_player.global_position)])
	# Хробак: під землею, тріщини, виринання, підкидання, поверхня.
	var worm := _only("Кістяний хробак")
	await _wait(0.1)
	_player.global_position = worm.global_position + Vector3(0, 0.2, 5.0)
	var tunnel := _ability(worm, "tunnel")
	var states := {}
	var tossed := false
	var hidden_hit_blocked := true
	var surfaced_hit := false
	_hits = 0
	for i in 60 * 9:
		await _wait(0.0)
		states[int(tunnel.get("_step"))] = true
		if float(_player.get("_knock_left")) > 0.0:
			tossed = true
		if i % 30 == 0:
			var hp := worm.current_hp
			_player.deal_damage(worm, 0.01, Vector3.ZERO, false)
			if worm.is_hidden() and worm.current_hp < hp:
				hidden_hit_blocked = false
			if not worm.is_hidden() and worm.current_hp < hp:
				surfaced_hit = true
	print("PROBE хробак: стани %s, підкинув %s, під землею не вдарити %s, на поверхні вдарити %s, укусів %d" % [states.keys(), tossed, hidden_hit_blocked, surfaced_hit, _hits])
	# Плоть: хмара, вибух по ворогах, калюжа.
	var flesh := _only("Розкладена плоть")
	await _wait(0.1)
	_player.global_position = flesh.global_position + Vector3(0, 0.2, 1.5)
	flesh.alert()
	_hits = 0
	await _wait(2.0)
	var cloud_hits := _hits
	var victim: Enemy3D = _dungeon._spawn_enemy(flesh.global_position + Vector3(1.5, 0, 0), DungeonLevels.BONE_WARD_TOTEM, false)
	await _wait(0.1)
	var victim_hp := victim.current_hp
	_player.global_position = flesh.global_position + Vector3(0, 0.2, 8.0)
	flesh.take_damage(1.0e9)
	await _wait(1.0)
	var pools := _dungeon.find_children("*", "HazardPool", true, false).size()
	print("PROBE плоть: укусів хмари за 2 с %d, вибух по ворогу %.0f -> %.0f, калюж %d" % [cloud_hits, victim_hp, victim.current_hp if is_instance_valid(victim) else -1.0, pools])
	# Тотем: посилення й кістяний щит.
	var totem := _only("Кістяний тотем")
	await _wait(0.1)
	var mob: Enemy3D = _dungeon._spawn_enemy(totem.global_position + Vector3(2.0, 0, 0), DungeonLevels.BONE_SKELETON, false)
	var base_damage := mob.damage
	_player.global_position = totem.global_position + Vector3(0, 0.2, 6.0)
	await _wait(1.2)
	print("PROBE тотем: шкода скелета %.1f -> %.1f, посилений %s" % [base_damage, mob.damage, mob.is_empowered()])
	var hp0 := totem.current_hp
	_player.deal_damage(totem, 0.05, Vector3.ZERO, false)
	var hp1 := totem.current_hp
	await _wait(0.3)
	_player.deal_damage(totem, 0.05, Vector3.ZERO, false)
	var hp2 := totem.current_hp
	await _wait(0.3)
	_player.deal_damage(totem, 0.05, Vector3.ZERO, false)
	var hp3 := totem.current_hp
	print("PROBE тотем щит: %.1f -> %.1f (1-й удар проходить) -> %.1f (2-й ковтає щит) -> %.1f (3-й проходить)" % [hp0, hp1, hp2, hp3])
	mob.take_damage(1.0e9)
	# Бос.
	for e: Enemy3D in _enemies():
		if e.kind != Enemy3D.Kind.BOSS:
			e.queue_free()
	_player.global_position = boss_home + Vector3(0, 0.2, 5.0)
	boss.alert()
	var seen := {}
	var thrown := false
	_hits = 0
	for i in 60 * 16:
		await _wait(0.0)
		var special: String = boss.get("_special")
		if special != "":
			seen[special] = true
		if _ability(boss, "scythe_throw").is_busy():
			thrown = true
			seen["кидок летить"] = true
		if i % 120 == 0:
			_player.global_position = boss.global_position + Vector3(0, 0.2, 2.5 if (i / 120) % 2 == 0 else 7.0)
	print("PROBE бос фаза 1: прийоми %s, коса в польоті %s, влучань %d, анімація %s" % [seen.keys(), thrown, _hits, boss.find_child("AnimationPlayer", true, false).current_animation])
	boss.current_hp = boss.max_hp * 0.6
	await _wait(4.0)
	var totems := 0
	var skeletons := 0
	for e: Enemy3D in _enemies():
		if e.display_name == "Кістяний тотем":
			totems += 1
		elif e.display_name == "Кістяк":
			skeletons += 1
	var hp := boss.current_hp
	_player.deal_damage(boss, 1.0, Vector3.ZERO, false)
	var warded_loss := hp - boss.current_hp
	for e: Enemy3D in _enemies():
		if e.display_name == "Кістяний тотем" or e.display_name == "Кістяк":
			e.take_damage(1.0e9)
	await _wait(0.6)
	hp = boss.current_hp
	_player.deal_damage(boss, 1.0, Vector3.ZERO, false)
	print("PROBE бос фаза %d: тотемів %d, скелетів %d, удар під тотемами %.1f, без тотемів %.1f" % [boss.phases.phase, totems, skeletons, warded_loss, hp - boss.current_hp])
	boss.current_hp = boss.max_hp * 0.25
	await _wait(2.5)
	_player.global_position = boss.global_position + Vector3(0, 0.2, 2.5)
	_hits = 0
	await _wait(3.0)
	print("PROBE бос фаза 3: влучань (удари й шипи) за 3 с %d" % _hits)
	boss.take_damage(1.0e9)
	await _wait(0.5)
	var lord := _ability(boss, "eternal_lord")
	var skull: Enemy3D = null
	for e: Enemy3D in _enemies():
		if e.display_name == "Череп Володаря":
			skull = e
	print("PROBE бос фаза %d: розсипався %s, невразливий %s, череп %s, живий %s" % [boss.phases.phase, lord.is_busy(), boss.invulnerable, skull != null, boss.is_alive()])
	await _wait(5.5)
	print("PROBE бос встав: здоров'я %.0f%%, зайнятий %s, анімація %s" % [boss.current_hp / boss.max_hp * 100.0, lord.is_busy(), boss.find_child("AnimationPlayer", true, false).current_animation])
	# Удруге — розбити череп: бос падає по-справжньому.
	await _wait(1.5)
	lord.set("_step", 0)
	boss.take_damage(1.0e9)
	await _wait(0.3)
	for e: Enemy3D in _enemies():
		if e.display_name == "Череп Володаря":
			e.take_damage(1.0e9)
	await _wait(0.5)
	print("PROBE бос після черепа: живий %s, вихід %s" % [boss.is_alive(), _dungeon.get("_exit_open")])
	get_tree().quit(0)
