extends Node

## Перевірка фаз боса й сфер здоров'я:
##  - смуга боса з'являється, щойно бій почався;
##  - на половині здоров'я — фаза 2 (напис), на чверті — фаза 3;
##  - дощ небезпек ранить героя, що стоїть на місці;
##  - сфера здоров'я лікує пораненого й чекає, коли здоров'я повне.
##   godot --path . res://tools/boss_probe.tscn -- [--level=N] [--shot=D:/кадр.png]
## Пише рядки "PROBE ..." і в кінці "RESULT: OK" або "RESULT: FAIL".

const ProbeUtil := preload("res://tools/probe_util.gd")
const SCENE := "res://scenes/dungeon/dungeon.tscn"

var _failed := false
var _dungeon: Node
var _player: CharacterBody3D

func _ready() -> void:
	PerfSettings.persist_settings = false
	var shot := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, argument.get_slice("=", 1).to_int())
			GameState.dungeon_level = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--shot="):
			shot = argument.get_slice("=", 1)
	_dungeon = load(SCENE).instantiate()
	add_child(_dungeon)
	await _wait(3.0)
	_player = _dungeon.get_node("Player")
	var start := _player.global_position
	_set_hp(50000.0, 50000.0)
	var boss: Enemy3D = _dungeon.get("_boss")
	_player.global_position = boss.global_position + Vector3(0, 0.3, 5.0)
	boss.alert()
	await _wait(0.5)
	var panel: Control = _dungeon.get("_boss_panel")
	print("PROBE бос %s, смуга видна: %s" % [boss.display_name, panel.visible])
	if not panel.visible:
		_failed = true

	# Фаза 2: бос оглушений (не б'є сам) — шкоду дають лише кола небезпек.
	boss.stun(40.0)
	boss.take_damage(boss.max_hp * 0.55)
	await _wait(0.3)
	var banner: Variant = _dungeon.get("_banner")
	print("PROBE фаза після 55%% шкоди: %d, напис: %s" % [boss.phases.phase, banner != null and is_instance_valid(banner)])
	if boss.phases.phase != 2:
		_failed = true
	var hp_before: float = _player.current_hp
	await _wait(3.0)
	if shot != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("PROBE кадр: ", shot)
	await _wait(6.0)
	print("PROBE дощ небезпек: здоров'я героя %.0f -> %.0f" % [hp_before, _player.current_hp])
	if _player.current_hp >= hp_before:
		_failed = true
	# Удар на 35%: з порогом фаз ("phase_lock") здоров'я зупиниться на наступному порозі.
	boss.take_damage(boss.max_hp * 0.35)
	await _wait(0.2)
	boss.take_damage(boss.max_hp * 0.05)
	await _wait(0.3)
	print("PROBE фаза після ще 25%%: %d" % boss.phases.phase)
	if boss.phases.phase != 3:
		_failed = true

	# Бос падає (інакше дощ небезпек ранить героя й заважає перевірці сфери).
	boss.take_damage(boss.max_hp * 10.0)
	await _wait(2.5)

	# Сфера здоров'я: при повному здоров'ї чекає, пораненого — лікує.
	# Ізольовано від бою: приспані вцілілі (скелети некроманта, дозорці
	# біля входу) присипляємо, щоб перевірка сфери не залежала від того,
	# хто саме ще бродить рівнем.
	for node in _dungeon.get_node("Enemies").get_children():
		if node is Enemy3D and (node as Enemy3D).is_alive():
			(node as Enemy3D).stun(10.0)
	_player.global_position = start
	await _wait(0.5)
	_set_hp(1000.0, 1000.0)
	var orb := HealthOrb.new()
	orb.setup(_player)
	_dungeon.add_child(orb)
	orb.global_position = _player.global_position + Vector3(1.5, 0, 0)
	await _wait(1.5)
	var waited := is_instance_valid(orb)
	_set_hp(500.0, 1000.0)
	await _wait(1.5)
	print("PROBE сфера: при повному здоров'ї чекала %s, пораненого вилікувала до %.0f" % [waited, _player.current_hp])
	if not waited or _player.current_hp <= 500.0:
		_failed = true
	print("RESULT: ", "FAIL" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)

## Змінити здоров'я героя так, як це зробила б гра (з сигналом).
func _set_hp(current: float, maximum: float) -> void:
	_player.max_hp = maximum
	_player.current_hp = current
	_player.health_changed.emit(current, maximum)

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
