extends Node

## Перевірка елітних ворогів (EliteAffixes): щит спереду тримає, ззаду й
## після сильного удару — ні; цілитель лікує сусіда; вибуховий ранить
## героя після смерті; швидкий швидший; еліта дає втричі більше золота.
##   godot --path . res://tools/elite_probe.tscn -- [--shot=D:/кадр.png]
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
		if argument.begins_with("--shot="):
			shot = argument.get_slice("=", 1)
	GameState.dungeon_level = 0
	_dungeon = load(SCENE).instantiate()
	add_child(_dungeon)
	await _wait(3.0)
	_player = _dungeon.get_node("Player")
	_player.max_hp = 50000.0
	_player.current_hp = 50000.0
	var base: Dictionary = DungeonLevels.get_level(0).enemies.m[0]
	var center := _player.global_position
	var swift := _spawn(base, EliteAffixes.Affix.SWIFT, center + Vector3(-3.0, 0, -3.0))
	var volatile := _spawn(base, EliteAffixes.Affix.VOLATILE, center + Vector3(3.0, 0, -3.0))
	var shielded := _spawn(base, EliteAffixes.Affix.SHIELDED, center + Vector3(0, 0, -4.0))
	var mender := _spawn(base, EliteAffixes.Affix.MENDER, center + Vector3(-4.0, 0, 1.0))
	var ally: Enemy3D = _dungeon.call("_spawn_enemy", center + Vector3(-5.5, 0, 1.0), base, false)
	await _wait(0.8)
	for enemy: Enemy3D in [swift, volatile, shielded, mender, ally]:
		enemy.stun(30.0)
	if shot != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("PROBE кадр: ", shot)

	var labels := 0
	for enemy: Enemy3D in [swift, volatile, shielded, mender]:
		if enemy.elite != null and not enemy.elite.find_children("*", "Label3D", false, false).is_empty():
			labels += 1
	print("PROBE еліт із підписом: %d з 4" % labels)
	if labels != 4:
		_failed = true
	print("PROBE швидкість: швидкий %.1f, звичайний %.1f" % [swift.move_speed, ally.move_speed])
	if swift.move_speed <= ally.move_speed:
		_failed = true

	# Щит: спереду 30%, ззаду 100%, сильний удар ламає. Здоров'я із
	# запасом — щоб щитоносець не впав посеред перевірки.
	shielded.max_hp = 10000.0
	shielded.current_hp = 10000.0
	_face(shielded, _player.global_position)
	var front := _hit(shielded, 100.0, false)
	_face(shielded, shielded.global_position * 2.0 - _player.global_position)
	var back := _hit(shielded, 100.0, false)
	_face(shielded, _player.global_position)
	_hit(shielded, 10.0, true)
	var broken := _hit(shielded, 100.0, false)
	print("PROBE щит: спереду %.0f, ззаду %.0f, після сильного удару %.0f" % [front, back, broken])
	if not is_equal_approx(front, 30.0) or not is_equal_approx(back, 100.0) or not is_equal_approx(broken, 100.0):
		_failed = true

	# Цілитель: пораненого сусіда лікує за кілька секунд.
	ally.take_damage(ally.max_hp * 0.6)
	var hurt := ally.current_hp
	await _wait(4.2)
	print("PROBE цілитель: сусід %.1f -> %.1f з %.1f" % [hurt, ally.current_hp, ally.max_hp])
	if ally.current_hp <= hurt:
		_failed = true

	# Вибуховий: упав поруч із героєм — за мить вибух ранить.
	_player.global_position = volatile.global_position + Vector3(1.2, 0.1, 0)
	await _wait(0.3)
	var hp_before: float = _player.current_hp
	var gold_before: int = _dungeon.get("_run_gold")
	volatile.take_damage(volatile.max_hp * 5.0)
	await _wait(2.2)
	var gold_gain: int = int(_dungeon.get("_run_gold")) - gold_before
	print("PROBE вибуховий: здоров'я героя %.0f -> %.0f, золота за еліту +%d" % [hp_before, _player.current_hp, gold_gain])
	if _player.current_hp >= hp_before or gold_gain < 12:
		_failed = true
	print("RESULT: ", "FAIL" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)

func _spawn(base: Dictionary, affix: int, position: Vector3) -> Enemy3D:
	var definition := base.duplicate()
	definition.affixes = [affix]
	return _dungeon.call("_spawn_enemy", position, definition, false)

## Повернути модель ворога обличчям до точки.
func _face(enemy: Enemy3D, target: Vector3) -> void:
	var offset := target - enemy.global_position
	(enemy.get("_model") as Node3D).rotation.y = atan2(offset.x, offset.z)

## Скільки здоров'я зняв удар.
func _hit(enemy: Enemy3D, amount: float, heavy: bool) -> float:
	var before := enemy.current_hp
	enemy.take_damage(amount, Vector3.ZERO, false, heavy)
	return before - enemy.current_hp

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
