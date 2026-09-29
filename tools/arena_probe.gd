extends Node

## Перевірка засідок: герой заходить у залу — виходи зачиняються (і крізь
## ґратку не пройти), вороги вилазять хвилями, після останньої ґратки
## ховаються, з'являється скриня; відкрита скриня дає золото й вибір
## здібності.
##   godot --path . res://tools/arena_probe.tscn -- [--level=N] [--arena=I] [--shots=D:/папка]
## Пише рядки "PROBE ..." і в кінці "RESULT: OK" або "RESULT: FAIL".

const ProbeUtil := preload("res://tools/probe_util.gd")
const SCENE := "res://scenes/dungeon/dungeon.tscn"

var _failed := false
var _dungeon: Node
var _player: CharacterBody3D
var _shots := ""
var _waves_seen := 0
var _choices_seen := 0

func _ready() -> void:
	PerfSettings.persist_settings = false
	var arena_index := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, argument.get_slice("=", 1).to_int())
			GameState.dungeon_level = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--arena="):
			arena_index = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--shots="):
			_shots = argument.get_slice("=", 1)
	_dungeon = load(SCENE).instantiate()
	add_child(_dungeon)
	await _wait(3.0)
	_player = _dungeon.get_node("Player")
	_player.max_hp = 50000.0
	_player.current_hp = 50000.0
	var arenas := _dungeon.get_children().filter(func(n: Node) -> bool: return n is ArenaAmbush)
	print("PROBE рівень %d: засідок %d" % [GameState.dungeon_level, arenas.size()])
	if arenas.size() <= arena_index:
		print("RESULT: FAIL")
		get_tree().quit(1)
		return
	var arena: ArenaAmbush = arenas[arena_index]
	arena.wave_started.connect(func(index: int, total: int) -> void:
		_waves_seen = index
		print("PROBE хвиля %d з %d" % [index, total]))
	var rect: Rect2i = arena.get("_rect")
	var center := DungeonBuilder.cell_center(rect.get_center()) + Vector3(0, 0.3, 0)
	_player.global_position = center
	await _wait(0.5)
	print("PROBE засідка почалась: %s, ґраток: %d" % [arena.is_active(), (arena.get("_edges") as Array).size()])
	if not arena.is_active():
		_failed = true
	await _wait(0.4)
	await _shot("arena_start")
	await _test_barrier(arena, rect)

	# Б'ємо всіх, хто вилазить, поки засідку не відбито (або минуть 90 с).
	var killed := 0
	var until := Time.get_ticks_msec() + 90000
	var mid_shot := false
	while arena.is_active() and Time.get_ticks_msec() < until:
		await _wait(0.35)
		if not mid_shot and _waves_seen >= 2:
			mid_shot = true
			await _wait(0.9)
			await _shot("arena_wave2")
		for node in _dungeon.get_node("Enemies").get_children():
			var enemy := node as Enemy3D
			if enemy != null and enemy.is_alive() and rect.has_point(DungeonBuilder.cell_of(enemy.global_position)):
				enemy.take_damage(enemy.max_hp * 5.0)
				killed += 1
	print("PROBE вбито в засідці %d, хвиль %d, відбито: %s" % [killed, _waves_seen, not arena.is_active()])
	if arena.is_active() or _waves_seen < 2:
		_failed = true
	await _wait(1.0)
	var body: Variant = arena.get("_barrier_body")
	print("PROBE ґратки після бою прибрано: %s" % (body == null))
	if body != null:
		_failed = true

	var chests := _dungeon.get_children().filter(func(n: Node) -> bool: return n is RewardChest)
	print("PROBE скринь: %d" % chests.size())
	if chests.is_empty():
		_failed = true
	else:
		var chest: RewardChest = chests[0]
		_player.global_position = chest.global_position + Vector3(0, 0.3, 3.0)
		await _wait(0.8)
		await _shot("arena_chest")
		var gold_before: int = _dungeon.get("_run_gold")
		_player.global_position = chest.global_position + Vector3(0, 0.3, 1.0)
		await _wait(2.5)
		var gold_after: int = _dungeon.get("_run_gold")
		print("PROBE скриня: золото %d -> %d, вікон вибору здібності %d" % [gold_before, gold_after, _choices_seen])
		if gold_after <= gold_before or _choices_seen == 0:
			_failed = true
	print("RESULT: ", "FAIL" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)

## Під час бою герой не може вийти з зали крізь ґратку.
func _test_barrier(arena: ArenaAmbush, rect: Rect2i) -> void:
	var edges: Array = arena.get("_edges")
	var edge: Dictionary = edges[0]
	var inward: Vector3 = DungeonBuilder.cell_center(rect.get_center()) - edge.center
	inward.y = 0.0
	inward = inward.normalized()
	_player.global_position = edge.center + inward * 1.2 + Vector3(0, 0.3, 0)
	await get_tree().physics_frame
	for i in 45:
		_player.set_move_input(Vector2(-inward.x, inward.z))
		await get_tree().physics_frame
	_player.set_move_input(Vector2.ZERO)
	var inside := rect.has_point(DungeonBuilder.cell_of(_player.global_position))
	print("PROBE герой біля ґратки лишився в залі: %s" % inside)
	if not inside:
		_failed = true

func _shot(name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_shots, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("PROBE кадр: ", path)

## Чекати справжні секунди, обираючи першу здібність, якщо спитають.
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				if ProbeUtil.press_first_card(node):
					_choices_seen += 1
