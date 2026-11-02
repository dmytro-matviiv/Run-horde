extends Node

## Перевірка нових ворогів у справжньому данжі:
##   --level=1 — вибуховий слиз, рій, плювальник із залпом, Грибний Король
##   --level=2 — таран, голем, Крижаний Дракон
## Для кожного — чи робить він те, що має: вибухає, розганяється,
## не збивається легкими ударами, кличе підмогу.

const ProbeUtil := preload("res://tools/probe_util.gd")

var _dungeon: Node
var _player: CharacterBody3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	var level := 1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			level = argument.get_slice("=", 1).to_int()
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, level)
	GameState.dungeon_level = level
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	for i in 900:
		await get_tree().process_frame
		if _dismiss():
			break
	_player = _dungeon.get_node("Player")
	# Щоб героя не вбили посеред перевірок — багато здоров'я.
	_player.max_hp = 5000.0
	_player.current_hp = 5000.0
	print("KINDS: рівень %d — %s, ворогів %d" % [level, DungeonLevels.get_level(level).title,
		get_tree().get_nodes_in_group(&"enemies").size()])
	if level == 1:
		await _test_exploder()
		await _test_swarm()
		await _test_volley()
		await _test_boss(&"summoner")
	elif level == 2:
		await _test_charger()
		await _test_tank()
		await _test_boss(&"dragon")
	get_tree().quit(0)

func _process(_delta: float) -> void:
	if _dungeon != null and get_tree().paused:
		_dismiss()

func _dismiss() -> bool:
	for node in _dungeon.get_node("HUD").get_children():
		if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
			ProbeUtil.press_first_card(node)
			get_tree().paused = false
			return true
	return false

func _find(kind: int, tank: bool = false) -> Enemy3D:
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.kind == kind and enemy.tank == tank and enemy.is_alive():
			return enemy
	return null

## Ставить героя на відстані distance від ворога так, щоб той його бачив.
func _place_near(enemy: Enemy3D, distance: float) -> void:
	for step in 16:
		var angle := TAU * step / 16.0
		var spot := enemy.global_position + Vector3(sin(angle), 0.0, cos(angle)) * distance + Vector3(0, 0.1, 0)
		var query := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP, spot + Vector3.UP)
		query.collision_mask = 1
		if _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			_player.global_position = spot
			_player.velocity = Vector3.ZERO
			return
	_player.global_position = enemy.global_position + Vector3(0, 0.1, distance)

## Решту ворогів довкола присипляємо, щоб перевірка була чистою.
func _isolate(keep: Enemy3D) -> void:
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if enemy != keep and enemy.global_position.distance_to(keep.global_position) < 26.0:
			enemy.set_sleeping(true)
			enemy.set_physics_process(false)

func _wake(enemy: Enemy3D) -> void:
	enemy.set_sleeping(false)
	enemy.set_physics_process(true)

func _test_exploder() -> void:
	var enemy := _find(Enemy3D.Kind.EXPLODER)
	if enemy == null:
		print("KINDS: вибухового не знайдено")
		return
	_isolate(enemy)
	_place_near(enemy, 6.0)
	var hp_before: float = _player.current_hp
	var fuse_seen := false
	for frame in 180:
		await get_tree().physics_frame
		if enemy.is_alive() and enemy._fuse_left >= 0.0:
			fuse_seen = true
		if not is_instance_valid(enemy) or not enemy.is_alive():
			break
	print("KINDS: вибуховий — ґніт видно: %s, герой %.0f -> %.0f HP, сам загинув: %s" % [
		fuse_seen, hp_before, _player.current_hp, not is_instance_valid(enemy) or not enemy.is_alive()])

	# Другий вибуховий: вбиваємо, поки горить ґніт — вибуху не має бути.
	var second := _find(Enemy3D.Kind.EXPLODER)
	if second == null:
		return
	_isolate(second)
	_place_near(second, 5.0)
	for frame in 180:
		await get_tree().physics_frame
		if second._fuse_left >= 0.0:
			break
	hp_before = _player.current_hp
	second.take_damage(9999.0)
	await get_tree().create_timer(1.3).timeout
	print("KINDS: вбитий під час ґнота — герой %.0f -> %.0f HP (вибуху не було: %s)" % [
		hp_before, _player.current_hp, is_equal_approx(hp_before, _player.current_hp)])

func _test_swarm() -> void:
	var small := 0
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.display_name == "Грибочок":
			small += 1
	print("KINDS: рій — грибочків на рівні %d" % small)

func _test_volley() -> void:
	var enemy := _find(Enemy3D.Kind.RANGED)
	if enemy == null:
		return
	_isolate(enemy)
	_wake(enemy)
	_place_near(enemy, 7.0)
	var most := 0
	for frame in 150:
		await get_tree().physics_frame
		most = maxi(most, _dungeon.find_children("*", "EnemyProjectile", true, false).size())
	print("KINDS: плювальник (%s) — снарядів одночасно до %d, залп %d" % [enemy.display_name, most, enemy.volley])

func _test_charger() -> void:
	var enemy := _find(Enemy3D.Kind.CHARGER)
	if enemy == null:
		print("KINDS: тарана не знайдено")
		return
	_isolate(enemy)
	_place_near(enemy, 8.0)
	var start := enemy.global_position
	var hp_before: float = _player.current_hp
	var states := {}
	var fastest := 0.0
	var last := enemy.global_position
	for frame in 150:
		await get_tree().physics_frame
		states[enemy._charge_state] = true
		fastest = maxf(fastest, enemy.global_position.distance_to(last) / get_physics_process_delta_time())
		last = enemy.global_position
	print("KINDS: таран (%s) — стани %s, найбільша швидкість %.1f м/с, зрушив на %.1f м, герой %.0f -> %.0f HP" % [
		enemy.display_name, states.keys(), fastest, enemy.global_position.distance_to(start), hp_before, _player.current_hp])

func _test_tank() -> void:
	var enemy := _find(Enemy3D.Kind.MELEE, true)
	if enemy == null:
		print("KINDS: голема не знайдено")
		return
	_isolate(enemy)
	var start := enemy.global_position
	enemy.take_damage(5.0, Vector3(6, 0, 0), false, false)
	await get_tree().create_timer(0.4).timeout
	print("KINDS: голем (%s) — HP %.0f, від легкого удару з відкиданням 6 зсунувся на %.2f м, оглушення %.2f с" % [
		enemy.display_name, enemy.max_hp, enemy.global_position.distance_to(start), enemy._stagger_left])

func _test_boss(style: StringName) -> void:
	var boss := _find(Enemy3D.Kind.BOSS)
	if boss == null:
		print("KINDS: боса не знайдено")
		return
	_isolate(boss)
	_wake(boss)
	boss.max_hp = 99999.0
	boss.current_hp = 99999.0
	_place_near(boss, 8.0)
	var enemies_before := get_tree().get_nodes_in_group(&"enemies").size()
	var hp_before: float = _player.current_hp
	var projectiles := 0
	var charged := false
	for frame in 600:
		await get_tree().physics_frame
		# Як у справжньому бою: герой час від часу відходить від боса.
		if frame % 150 == 149:
			_place_near(boss, 8.0)
		projectiles = maxi(projectiles, _dungeon.find_children("*", "EnemyProjectile", true, false).size())
		if boss._charge_state == 2:
			charged = true
	var enemies_after := get_tree().get_nodes_in_group(&"enemies").size()
	print("KINDS: бос %s (%s) — ворогів %d -> %d, снарядів до %d, таран: %s, герой %.0f -> %.0f HP" % [
		boss.display_name, style, enemies_before, enemies_after, projectiles, charged, hp_before, _player.current_hp])
