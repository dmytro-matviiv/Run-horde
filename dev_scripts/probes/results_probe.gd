extends Node
## Тимчасово (test_env): (1) смерть -> вікно воскресіння -> "відео" ->
## 80% здоров'я, щит, перезарядка перекату скинута; (2) друга смерть ->
## табличка поразки; (3) --victory: перемога біля порталу.
## Кадри: D:/RuneHorde_work/screenshots/results_*.png
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/results_%s.png" % name)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	var hero := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hero="): hero = a.get_slice("=", 1)
	if hero != "":
		GameState.selected_hero_id = StringName(hero)
	GameState.dungeon_level = 0
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	# Трохи "бою": шкода по джерелах.
	var skills: Array = _player.get_skills()
	_player.damage_by_source[&"weapon"] = 1840.0
	if skills.size() > 0:
		_player.damage_by_source[skills[0].id] = 960.0
	if skills.size() > 1:
		_player.damage_by_source[skills[1].id] = 410.0
	_player.damage_by_source[&"passive"] = 120.0
	_dungeon.set("_run_gold", 245)
	_dungeon.set("_run_time", 197.0)
	if OS.get_cmdline_user_args().has("--victory"):
		_dungeon.call("_show_results", true)
		await _wait(0.35)
		await _shot("victory_fly")
		await _wait(2.6)
		await _shot("victory")
		get_tree().quit(0)
		return
	# Перекат на перезарядці, перша здібність теж.
	_player.set("_dodge_cooldown_left", 2.0)
	if skills.size() > 0:
		skills[0].set("_cooldown_left", 4.0)
	_player.take_damage(99999.0)
	await _wait(1.6)
	print("PROBE пауза: ", get_tree().paused)
	await _shot("revive_offer")
	_dungeon.call("_on_revive_watched")
	await _wait(0.4)
	await _shot("revive_shield")
	var cd: float = skills[0].get("_cooldown_left") if skills.size() > 0 else -1.0
	print("PROBE воскрес: hp %.0f / %.0f, невразливий %.2f, перекат %.2f, здібність %.2f, пауза %s" % [_player.current_hp, _player.max_hp, _player.get("_invulnerable_left"), _player.get("_dodge_cooldown_left"), cd, get_tree().paused])
	var hp: float = _player.current_hp
	_player.take_damage(50.0)
	print("PROBE під щитом удар 50: hp %.0f -> %.0f" % [hp, _player.current_hp])
	await _wait(3.2)
	print("PROBE щит спав: невразливий %.2f" % _player.get("_invulnerable_left"))
	_player.take_damage(99999.0)
	await _wait(1.5)
	print("PROBE друга смерть -> підсумки: ", _dungeon.get("_results") != null)
	await _wait(0.4)
	await _shot("defeat_fly")
	await _wait(2.8)
	await _shot("defeat")
	get_tree().quit(0)
