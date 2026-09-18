extends Node

## Перевірка бойової системи в справжньому данжі:
## автонаведення, комбо, бій на відході, перекат, вихор, замахи ворогів,
## снаряди стрільців і смужка здоров'я героя.
##
##   godot --path . res://tools/combat_probe.tscn -- --shot=D:/x.png

const SCENE := "res://scenes/dungeon/dungeon.tscn"

var _dungeon: Node
var _player: CharacterBody3D
var _shot_path := ""

func _ready() -> void:
	# Тест має працювати й під час паузи — щоб закривати вікно вибору.
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			_shot_path = argument.get_slice("=", 1)
	_dungeon = load(SCENE).instantiate()
	add_child(_dungeon)
	await _dismiss_ability_choice()
	_player = _dungeon.get_node("Player")

	await _test_health_bar()
	await _test_combo()
	print("COMBAT: швидкість часу після комбо ", Engine.time_scale)
	await _test_backpedal()
	await _test_dodge()
	await _test_skill()
	await _test_ranged()
	await _test_enemy_windup()
	if _shot_path != "":
		await _take_shot()
	get_tree().quit(0)

## Вибір здібності на новому рівні ставить гру на паузу — у тесті
## одразу обираємо першу, щоб бій ішов далі.
func _process(_delta: float) -> void:
	if _dungeon == null or not get_tree().paused:
		return
	for node in _dungeon.get_node("HUD").get_children():
		if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
			node.upgrade_chosen.emit(&"max_hp")

func _test_health_bar() -> void:
	var bar: HealthBar3D = _player._health_bar
	_player.take_damage(30.0)
	await get_tree().create_timer(1.2).timeout
	var ratio: float = bar._bar.get_instance_shader_parameter(&"ratio")
	var trail: float = bar._bar.get_instance_shader_parameter(&"trail")
	print("COMBAT: смужка героя після -30 HP: частка %.2f, слід %.2f (має бути 0.70 і 0.70)" % [ratio, trail])
	_player.current_hp = _player.max_hp
	_player._update_health_bar()

## Ставимо героя біля ворога й тиснемо удар: ціль має знайтись сама,
## комбо — пройти всі три ланки, здоров'я ворога — падати.
func _test_combo() -> void:
	var enemy := _nearest_enemy_to(Vector3(38, 0, 30))
	_place_player_near(enemy, 2.4)
	await get_tree().create_timer(0.4).timeout
	var hp_before: float = enemy.current_hp
	var steps := []
	for i in 6:
		_player.attack()
		for frame in 12:
			await get_tree().physics_frame
			if _player._attack_step >= 0 and (steps.is_empty() or steps[-1] != _player._attack_step):
				steps.append(_player._attack_step)
	await get_tree().create_timer(0.5).timeout
	var labels := _dungeon.find_children("*", "Label3D", true, false).size()
	print("COMBAT: ціль знайдена: %s, ланки комбо: %s" % [_player._target != null or not is_instance_valid(enemy), steps])
	print("COMBAT: ворог %.0f -> %.0f HP (живий: %s), цифр шкоди на екрані: %d" % [
		hp_before, enemy.current_hp if is_instance_valid(enemy) else 0.0,
		is_instance_valid(enemy) and enemy.is_alive(), labels])

## Відходимо від ворога, тримаючи удар: герой має дивитись на ворога й
## бігти задки. Відбігли далі — розвертається.
func _test_backpedal() -> void:
	var enemy := _nearest_alive_enemy()
	if enemy == null:
		print("COMBAT: для перевірки відходу не лишилось ворогів")
		return
	# Ворог міцний, щоб не впав від першого ж удару й було від кого відходити.
	enemy.current_hp = 500.0
	enemy.max_hp = 500.0
	_place_player_near(enemy, 2.5, 9.0)
	await get_tree().create_timer(0.3).timeout
	_player.attack()
	var away := (_player.global_position - enemy.global_position)
	away.y = 0.0
	var screen_away := _to_screen_input(away.normalized())
	_player.set_move_input(screen_away)
	await get_tree().create_timer(0.45).timeout
	var facing_error := _facing_error_to(enemy)
	var blend: Vector2 = _player._blend_position
	print("COMBAT: відхід у бою — кут до ворога %.0f°, анімація руху %s (y<0 = біг задки)" % [facing_error, blend])
	# Перестаємо бити й тікаємо: герой має розвернутись і бігти.
	await get_tree().create_timer(1.6).timeout
	if not is_instance_valid(enemy):
		return
	var distance := _player.global_position.distance_to(enemy.global_position)
	var move_error := rad_to_deg(absf(angle_difference(_player._facing_angle, atan2(away.x, away.z))))
	print("COMBAT: відбіг на %.1f м — кут до напрямку бігу %.0f° (має бути близько 0)" % [distance, move_error])
	_player.set_move_input(Vector2.ZERO)

func _test_dodge() -> void:
	print("COMBAT: перед перекатом — пауза %s, загинув %s, HP %.0f" % [get_tree().paused, _player._dead, _player.current_hp])
	var start := _player.global_position
	_player.dodge()
	await get_tree().physics_frame
	var damaged: bool = _player.take_damage(10.0)
	await get_tree().create_timer(0.5).timeout
	print("COMBAT: перекат на %.1f м, шкода під час перекату пройшла: %s (має бути false)" % [
		start.distance_to(_player.global_position), damaged])

func _test_skill() -> void:
	var enemy := _nearest_alive_enemy()
	if enemy == null:
		return
	_place_player_near(enemy, 2.0)
	await get_tree().create_timer(0.3).timeout
	var before: float = enemy.current_hp
	_player.use_skill()
	await get_tree().create_timer(0.5).timeout
	var cooldown: Vector2 = _player.get_skill_cooldown()
	print("COMBAT: вихор — ворог %.0f -> %.0f HP, перезарядка %.1f / %.0f с" % [
		before, enemy.current_hp if is_instance_valid(enemy) else 0.0, cooldown.x, cooldown.y])

## Стоїмо біля ворога й не б'ємо: він має замахнутись (червона зона) і
## вдарити. Потім те саме, але з перекатом у мить замаху — шкоди нема.
func _test_enemy_windup() -> void:
	var enemy := _nearest_alive_enemy(Enemy3D.Kind.MELEE)
	if enemy == null:
		print("COMBAT: немає ворога ближнього бою")
		return
	_player._invulnerable_left = 0.0
	_place_player_near(enemy, 1.6)
	var hp_before: float = _player.current_hp
	var saw_telegraph := false
	for frame in 150:
		await get_tree().physics_frame
		if enemy._telegraph != null and not saw_telegraph:
			saw_telegraph = true
			print("COMBAT:   замах почався на кадрі %d, відстань %.1f" % [frame, enemy.global_position.distance_to(_player.global_position)])
		if saw_telegraph and enemy._telegraph == null:
			print("COMBAT:   замах закінчився на кадрі %d, відстань %.1f, невразливість героя %.2f, ворог бачить: %s" % [
				frame, enemy.global_position.distance_to(_player.global_position), _player._invulnerable_left, enemy._has_line_of_sight()])
			await get_tree().physics_frame
			break
	print("COMBAT: замах ворога видно: %s, герой %.0f -> %.0f HP" % [saw_telegraph, hp_before, _player.current_hp])

	# Друга спроба — ухиляємось, щойно з'явилась зона. Інших ворогів
	# поруч прибираємо, щоб шкода не прилетіла від сусіднього стрільця.
	_isolate(enemy)
	_player.current_hp = _player.max_hp
	_player._dodge_cooldown_left = 0.0
	await get_tree().create_timer(1.5).timeout
	_place_player_near(enemy, 1.6, 5.0)
	hp_before = _player.current_hp
	var dodged := false
	for frame in 120:
		await get_tree().physics_frame
		if not dodged and enemy._telegraph != null:
			dodged = true
			var away := (_player.global_position - enemy.global_position)
			away.y = 0.0
			_player.set_move_input(_to_screen_input(away.normalized()))
			_player.dodge()
		if dodged and enemy._telegraph == null:
			break
	_player.set_move_input(Vector2.ZERO)
	print("COMBAT: з перекатом у мить замаху: герой %.0f -> %.0f HP (має не змінитись)" % [hp_before, _player.current_hp])

func _test_ranged() -> void:
	var enemy := _nearest_alive_enemy(Enemy3D.Kind.RANGED)
	if enemy == null:
		print("COMBAT: немає стрільця")
		return
	_player.current_hp = _player.max_hp
	_place_player_near(enemy, 7.0)
	var saw_projectile := false
	var hp_before: float = _player.current_hp
	for frame in 150:
		await get_tree().physics_frame
		if not _dungeon.find_children("*", "EnemyProjectile", true, false).is_empty():
			saw_projectile = true
	print("COMBAT: стрілець пустив видимий снаряд: %s, герой %.0f -> %.0f HP" % [saw_projectile, hp_before, _player.current_hp])

func _take_shot() -> void:
	var enemy := _nearest_alive_enemy(Enemy3D.Kind.MELEE)
	if enemy == null:
		enemy = _nearest_alive_enemy()
	if enemy != null:
		enemy.current_hp = 300.0
		enemy.max_hp = 300.0
		_place_player_near(enemy, 2.3, 4.0)
	_player.current_hp = _player.max_hp
	# Чекаємо, поки ворог почне замах, — щоб на знімку була червона зона.
	for frame in 90:
		await get_tree().physics_frame
		if enemy != null and enemy._telegraph != null:
			break
	_player.attack()
	await get_tree().create_timer(0.36).timeout
	_player.attack()
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_path)
	print("COMBAT: знімок ", _shot_path)

# --- допоміжне ---

func _nearest_enemy_to(point: Vector3) -> Enemy3D:
	var best: Enemy3D = null
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.kind == Enemy3D.Kind.BOSS:
			continue
		if best == null or enemy.global_position.distance_to(point) < best.global_position.distance_to(point):
			best = enemy
	return best

func _nearest_alive_enemy(kind: int = -1) -> Enemy3D:
	var best: Enemy3D = null
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if not enemy.is_alive() or enemy.kind == Enemy3D.Kind.BOSS:
			continue
		if kind >= 0 and enemy.kind != kind:
			continue
		if best == null or enemy.global_position.distance_to(_player.global_position) \
				< best.global_position.distance_to(_player.global_position):
			best = enemy
	return best

## Ставить героя поруч із ворогом з боку, звідки видно й де за спиною
## героя є вільне місце (room метрів) — щоб було куди відступати.
func _place_player_near(enemy: Enemy3D, distance: float, room: float = 0.0) -> void:
	for step in 16:
		var angle := TAU * step / 16.0
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var spot := enemy.global_position + direction * distance + Vector3(0, 0.1, 0)
		if not _ray_clear(enemy.global_position + Vector3.UP, spot + Vector3.UP):
			continue
		if room > 0.0 and not _ray_clear(spot + Vector3.UP, spot + Vector3.UP + direction * room):
			continue
		_player.global_position = spot
		_player.velocity = Vector3.ZERO
		return
	_player.global_position = enemy.global_position + Vector3(0, 0.1, distance)

func _isolate(keep: Enemy3D) -> void:
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if enemy != keep and enemy.is_alive() and enemy.kind != Enemy3D.Kind.BOSS 				and enemy.global_position.distance_to(keep.global_position) < 30.0:
			enemy.take_damage(99999.0)

func _ray_clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	return _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Світовий напрямок -> вхід джойстика з урахуванням кута камери.
func _to_screen_input(world: Vector3) -> Vector2:
	var yaw: float = _player._get_camera_yaw()
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(-forward.z, 0.0, forward.x)
	return Vector2(world.dot(right), world.dot(forward)).normalized()

func _facing_error_to(node: Node3D) -> float:
	var offset := node.global_position - _player.global_position
	return rad_to_deg(absf(angle_difference(_player._facing_angle, atan2(offset.x, offset.z))))

func _dismiss_ability_choice() -> void:
	for i in 600:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen"):
				node.upgrade_chosen.emit(&"weapon_damage")
				get_tree().paused = false
				return
