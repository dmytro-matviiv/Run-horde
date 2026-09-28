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
		elif argument.begins_with("--hero="):
			GameState.selected_hero_id = StringName(argument.get_slice("=", 1))
		elif argument.begins_with("--weapon="):
			var weapon_id := StringName(argument.get_slice("=", 1))
			GameState.equipped_weapon_ids[GameState.selected_hero_id] = weapon_id
			if not GameState.owned_weapon_ids.has(weapon_id):
				GameState.owned_weapon_ids.append(weapon_id)
	_dungeon = load(SCENE).instantiate()
	add_child(_dungeon)
	await _dismiss_ability_choice()
	_player = _dungeon.get_node("Player")

	_report_loadout()
	await _test_health_bar()
	await _test_kill_then_pause()
	await _test_combo()
	print("COMBAT: швидкість часу після комбо ", Engine.time_scale)
	await _test_smoothness()
	await _test_backpedal()
	await _test_dodge()
	await _test_skill()
	await _test_passive_charge()
	await _test_shooting()
	_test_upgrade_choices()
	await _test_pierce_and_explosive()
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

## Хто в грі: модель, зброя, здібності, пасивка — усе з вибраного героя.
func _report_loadout() -> void:
	var hero: HeroDef = _player.hero_def
	var weapon: WeaponDef = _player.weapon_def
	var skills: Array = _player.get_skills()
	var names := []
	for skill: HeroSkill3D in skills:
		names.append(skill.title)
	var model: Node3D = _player.model
	var has_model: bool = model.get_child_count() > 0
	var weapon_in_hand: bool = _player._weapon_node != null
	print("COMBAT: герой %s, зброя %s (%s), модель %s, зброя в руці %s" % [
		hero.title, weapon.title, weapon.style_3d, has_model, weapon_in_hand])
	print("COMBAT: здібності %s, пасивка %s, шкода %.1f, HP %.0f" % [
		names, _player.passive.title if _player.passive != null else "немає",
		_player._damage, _player.max_hp])

## Пасивка Клинкової Вартової: лють накопичується від ударів і вмикає
## другу кнопку.
func _test_passive_charge() -> void:
	if _player.passive == null or _player.passive.get_charge() < 0.0:
		print("COMBAT: у цього героя пасивка без шкали")
		return
	var enemy := _nearest_alive_enemy()
	if enemy == null:
		return
	enemy.current_hp = 900.0
	enemy.max_hp = 900.0
	# З запасом місця позаду: ривок має куди розігнатись.
	_place_player_near(enemy, 2.2, 8.0)
	var before: float = _player.passive.get_charge()
	for i in 8:
		_player.attack()
		for frame in 14:
			await get_tree().physics_frame
	var after: float = _player.passive.get_charge()
	print("COMBAT: шкала пасивки \"%s\": %.2f -> %.2f" % [_player.passive.title, before, after])
	# Друга кнопка (Ривок Люті) світиться лише на повній шкалі.
	var skills: Array = _player.get_skills()
	if skills.size() > 1:
		var dash: HeroSkill3D = skills[1]
		var ready_before: bool = dash.is_ready(_player)
		_player.passive._charge = 1.0
		var ready_full: bool = dash.is_ready(_player)
		var position_before: Vector3 = _player.global_position
		_player.use_skill(1)
		await get_tree().create_timer(0.45).timeout
		print("COMBAT: \"%s\" — готова на %.0f%% люті: %s, на повній: %s, ривок %.1f м" % [
			dash.title, before * 100.0, ready_before, ready_full,
			position_before.distance_to(_player.global_position)])

## Стрільба: темп вогню, витрата набоїв, шкода по ворогові, перезарядка.
func _test_shooting() -> void:
	if not _player.is_ranged():
		print("COMBAT: у цього героя зброя ближнього бою")
		return
	var enemy := _nearest_alive_enemy()
	if enemy == null:
		return
	enemy.current_hp = 2000.0
	enemy.max_hp = 2000.0
	# Решту прибираємо: інакше автонаведення вибере ближчого, і замір
	# шкоди піде не по тому ворогові.
	_isolate(enemy)
	_place_player_near(enemy, 7.0)
	await get_tree().create_timer(0.4).timeout
	var ammo_before: Vector2i = _player.get_ammo()
	var hp_before: float = enemy.current_hp
	var max_bullets := 0
	_player.set_attack_held(true)
	for i in 60:
		await get_tree().physics_frame
		max_bullets = maxi(max_bullets, _dungeon.find_children("*", "PlayerProjectile", true, false).size())
	_player.set_attack_held(false)
	await get_tree().create_timer(0.6).timeout
	var ammo_after: Vector2i = _player.get_ammo()
	print("COMBAT: стрільба — набої %d/%d -> %d, ворог %.0f -> %.0f HP, куль у повітрі до %d" % [
		ammo_before.x, ammo_before.y, ammo_after.x, hp_before, enemy.current_hp, max_bullets])

	# Порожній магазин має сам піти в перезарядку.
	_player._ammo = 0
	_player.attack()
	await get_tree().physics_frame
	var reload: Vector2 = _player.get_reload()
	await get_tree().create_timer(reload.y + 0.3).timeout
	for node in _dungeon.get_node("HUD").get_children():
		if node.has_method("setup") and node.get("_attack") != null:
			var attack_button = node.get("_attack")
			print("COMBAT: кнопка вогню — напис \"%s\", видима %s, розмір %s" % [
				attack_button.inner_text, attack_button.visible, attack_button.size])
	print("COMBAT: перезарядка %.1f с, набоїв після неї %d/%d" % [
		reload.y, _player.get_ammo().x, _player.get_ammo().y])

## Які здібності пропонують цьому героєві. Мечниці не має випадати
## нічого про кулі, стрільцю — нічого про замахи.
func _test_upgrade_choices() -> void:
	var offered := {}
	for i in 40:
		for card: Dictionary in RunUpgrades.pick(_player, {}, 0.0, 3):
			offered[card.id] = card.title
	var melee_only := [&"arc", &"knockback", &"combo_speed", &"rage_gain", &"dash_power", &"whirl_power"]
	var ranged_only := [&"pierce", &"magazine", &"reload", &"extra_bullet", &"accuracy", &"fire_rate",
		&"explosive", &"mark_power", &"smoke_power"]
	var wrong := []
	for id: StringName in offered:
		var is_melee_card: bool = melee_only.has(id)
		var is_ranged_card: bool = ranged_only.has(id)
		if _player.is_ranged() and is_melee_card:
			wrong.append(offered[id])
		if not _player.is_ranged() and is_ranged_card:
			wrong.append(offered[id])
	print("COMBAT: здібності походу (%d видів): %s" % [offered.size(), offered.values()])
	print("COMBAT: невідповідних героєві: %s (має бути порожньо)" % [wrong])

## "Пробивний набій" має прошивати другого ворога, а "Розривні кулі" —
## зачіпати тих, хто поруч.
func _test_pierce_and_explosive() -> void:
	if not _player.is_ranged():
		print("COMBAT: перевірка куль — герой не стрілець")
		return
	var enemies: Array = []
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.is_alive() and enemy.kind != Enemy3D.Kind.BOSS:
			enemies.append(enemy)
		if enemies.size() == 2:
			break
	if enemies.size() < 2:
		print("COMBAT: для перевірки куль забракло ворогів")
		return
	var first: Enemy3D = enemies[0]
	var second: Enemy3D = enemies[1]
	for enemy: Enemy3D in enemies:
		enemy.max_hp = 4000.0
		enemy.current_hp = 4000.0
		enemy.set_sleeping(true)   # хай стоять на місці під час заміру

	# Ставимо їх у лінію перед героєм.
	_place_player_near(first, 6.0, 4.0)
	var forward: Vector3 = (first.global_position - _player.global_position)
	forward.y = 0.0
	forward = forward.normalized()
	first.global_position = _player.global_position + forward * 4.0 + Vector3(0, 0.1, 0)
	second.global_position = _player.global_position + forward * 6.0 + Vector3(0, 0.1, 0)
	_player._bullet_pierce = 1
	_player._explosive_bullets = 0
	_player._ammo = _player.magazine_size()
	var before_second: float = second.current_hp
	for i in 6:
		_player.attack()
		for frame in 12:
			await get_tree().physics_frame
	print("COMBAT: пробивний набій — другий ворог за спиною першого: %.0f -> %.0f HP" % [
		before_second, second.current_hp])

	# Тепер розрив: другий стоїть збоку, куля в нього не летить.
	_player._bullet_pierce = 0
	_player._explosive_bullets = 1
	second.global_position = first.global_position + Vector3(forward.z, 0.0, -forward.x) * 1.4
	second.current_hp = 4000.0
	before_second = second.current_hp
	_player._ammo = _player.magazine_size()
	for i in 6:
		_player.attack()
		for frame in 12:
			await get_tree().physics_frame
	print("COMBAT: розривні кулі — сусід збоку: %.0f -> %.0f HP" % [before_second, second.current_hp])

func _test_health_bar() -> void:
	var bar: HealthBar3D = _player._health_bar
	_player.take_damage(30.0)
	await get_tree().create_timer(1.2).timeout
	var ratio: float = bar._bar.get_instance_shader_parameter(&"ratio")
	var trail: float = bar._bar.get_instance_shader_parameter(&"trail")
	var expected: float = (_player.max_hp - 30.0) / _player.max_hp
	print("COMBAT: смужка героя після -30 HP: частка %.2f, слід %.2f (має бути %.2f)" % [ratio, trail, expected])
	_player.current_hp = _player.max_hp
	_player._update_health_bar()

## Колишній виліт: ворога вдарили (він спалахнув білим), він помер, і
## тут гра стала на паузу (вибір здібності). Ворог зникав під час паузи,
## а після неї код знімав спалах із уже видаленої моделі.
func _test_kill_then_pause() -> void:
	var enemy := _nearest_alive_enemy()
	if enemy == null:
		return
	_player.global_position = enemy.global_position + Vector3(0, 0.1, 2.0)
	await get_tree().physics_frame
	enemy.take_damage(enemy.current_hp + 1.0)
	get_tree().paused = true
	await get_tree().create_timer(2.0, true).timeout
	var freed := not is_instance_valid(enemy)
	get_tree().paused = false
	await get_tree().create_timer(0.3).timeout
	print("COMBAT: смерть ворога + пауза 2 с: ворог прибраний під час паузи — %s, гра живе далі" % freed)

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

## Плавність бою: герой не має "перелітати" до ворога, розвертатись за
## один кадр, а ворога не має відносити на метри.
func _test_smoothness() -> void:
	var enemy := _nearest_alive_enemy(Enemy3D.Kind.MELEE)
	if enemy == null:
		return
	enemy.current_hp = 900.0
	enemy.max_hp = 900.0
	_place_player_near(enemy, 3.4, 3.0)
	_player._facing_angle = atan2(enemy.global_position.x - _player.global_position.x,
		enemy.global_position.z - _player.global_position.z) + PI
	await get_tree().create_timer(0.2).timeout
	var max_player_speed := 0.0
	var max_turn_deg := 0.0
	var max_enemy_speed := 0.0
	var last_angle: float = _player._facing_angle
	var last_player := _player.global_position
	var last_enemy := enemy.global_position
	var enemy_start := enemy.global_position
	var frames := 0
	for i in 9:
		_player.attack()
		for frame in 14:
			await get_tree().physics_frame
			var dt := get_physics_process_delta_time()
			frames += 1
			var p := _player.global_position
			var e := enemy.global_position
			max_player_speed = maxf(max_player_speed, Vector2(p.x - last_player.x, p.z - last_player.z).length() / dt)
			max_enemy_speed = maxf(max_enemy_speed, Vector2(e.x - last_enemy.x, e.z - last_enemy.z).length() / dt)
			max_turn_deg = maxf(max_turn_deg, rad_to_deg(absf(angle_difference(last_angle, _player._facing_angle))))
			last_player = p
			last_enemy = e
			last_angle = _player._facing_angle
	print("COMBAT: плавність — герой макс %.1f м/с (біг 5.4), розворот макс %.0f° за кадр, ворог макс %.1f м/с, ворог зсунувся на %.1f м" % [
		max_player_speed, max_turn_deg, max_enemy_speed, enemy.global_position.distance_to(enemy_start)])

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
	var skills: Array = _player.get_skills()
	var cooldown: Vector2 = skills[0].get_cooldown() if not skills.is_empty() else Vector2.ZERO
	print("COMBAT: здібність \"%s\" — ворог %.0f -> %.0f HP, перезарядка %.1f / %.0f с" % [
		skills[0].title if not skills.is_empty() else "?",
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
