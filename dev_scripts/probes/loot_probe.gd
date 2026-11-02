extends Node

## Перевірка здобичі з ворогів: убиті поруч із героєм вороги розкидають
## золото й кристали досвіду, ті долітають до героя й зараховуються; бос
## на смерті вмикає сповільнення, і воно потім знімається.
##   godot --path . res://tools/loot_probe.tscn -- [--level=N] [--shot=D:/кадр.png]
## Пише рядки "PROBE ..." і в кінці "RESULT: OK" або "RESULT: FAIL".

const ProbeUtil := preload("res://tools/probe_util.gd")
const SCENE := "res://scenes/dungeon/dungeon.tscn"

var _failed := false
var _dungeon: Node

func _ready() -> void:
	PerfSettings.persist_settings = false
	var shot_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, argument.get_slice("=", 1).to_int())
			GameState.dungeon_level = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--shot="):
			shot_path = argument.get_slice("=", 1)
	_dungeon = load(SCENE).instantiate()
	add_child(_dungeon)
	await _wait(3.0)
	var player: CharacterBody3D = _dungeon.get_node("Player")

	# Троє найближчих ворогів — поруч із героєм і одразу вбиті.
	var gold_before: int = _dungeon.get("_run_gold")
	var xp_before: int = _dungeon.get("_xp") + 1000 * int(_dungeon.get("_hero_level"))
	var victims := _nearest_enemies(player, 3)
	for i in victims.size():
		var enemy: Enemy3D = victims[i]
		enemy.global_position = player.global_position + Vector3(2.0 * (i - 1), 0.2, -2.5)
		enemy.take_damage(enemy.max_hp * 3.0)
	await _wait(0.3)
	var swarm: LootSwarm = _dungeon.get("_loot")
	var flying: int = (swarm.get("_pieces") as Array).size()
	print("PROBE вбито %d, у повітрі шматочків здобичі: %d" % [victims.size(), flying])
	if flying == 0:
		_failed = true
	if shot_path != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("PROBE кадр: ", shot_path)
	await _wait(2.5)
	var gold_after: int = _dungeon.get("_run_gold")
	var xp_after: int = _dungeon.get("_xp") + 1000 * int(_dungeon.get("_hero_level"))
	print("PROBE золото походу %d -> %d, досвід %d -> %d, у повітрі лишилось %d" % [
		gold_before, gold_after, xp_before, xp_after, (swarm.get("_pieces") as Array).size()])
	if gold_after <= gold_before or xp_after <= xp_before:
		_failed = true

	# Бос: вбивство вмикає сповільнення, а потім воно знімається.
	var boss: Enemy3D = null
	for node in _dungeon.get_node("Enemies").get_children():
		if node is Enemy3D and (node as Enemy3D).kind == Enemy3D.Kind.BOSS:
			boss = node
	if boss == null:
		print("PROBE боса не знайдено")
		_failed = true
	else:
		boss.global_position = player.global_position + Vector3(0, 0.2, -4.0)
		boss.take_damage(boss.max_hp * 3.0)
		await get_tree().process_frame
		var slowed := Engine.time_scale
		await _wait(2.0)
		print("PROBE бос: швидкість гри одразу %.2f, через 2 с %.2f, вихід відчинено: %s" % [
			slowed, Engine.time_scale, _dungeon.get("_exit_open")])
		if slowed >= 1.0 or not is_equal_approx(Engine.time_scale, 1.0) or not _dungeon.get("_exit_open"):
			_failed = true
	print("RESULT: ", "FAIL" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)

func _nearest_enemies(player: Node3D, count: int) -> Array:
	var list: Array = []
	for node in _dungeon.get_node("Enemies").get_children():
		if node is Enemy3D and (node as Enemy3D).is_alive() and (node as Enemy3D).kind != Enemy3D.Kind.BOSS:
			list.append(node)
	list.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	return list.slice(0, count)

## Чекати справжні секунди, закриваючи вікна вибору здібності, якщо
## з'являться (вони ставлять гру на паузу).
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
