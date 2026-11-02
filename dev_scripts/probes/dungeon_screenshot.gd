extends Node

## Знімок данжу: запускає рівень, чекає, поки збереться геометрія й
## напечеться карта прохідності, і зберігає кадр.

const ProbeUtil := preload("res://tools/probe_util.gd")

const SCENE := "res://scenes/dungeon/dungeon.tscn"
const OUT_PATH := "user://dungeon_screenshot.png"

func _ready() -> void:
	PerfSettings.persist_settings = false
	# --level=N — який рівень данжу перевіряти (0, 1, 2).
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, argument.get_slice("=", 1).to_int())
			GameState.dungeon_level = argument.get_slice("=", 1).to_int()
	# --hero=<id> і --weapon=<id> — ким і з чим іти (зброю купуємо й
	# вдягаємо, як це зробив би гравець).
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hero="):
			GameState.selected_hero_id = StringName(argument.get_slice("=", 1))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--weapon="):
			var weapon_id := StringName(argument.get_slice("=", 1))
			if not GameState.is_weapon_owned(weapon_id):
				GameState.buy_weapon(weapon_id)
			GameState.equip_weapon(GameState.selected_hero_id, weapon_id)
	var out_path := OUT_PATH
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="):
			PerfSettings.apply_quality(argument.get_slice("=", 1).to_int(), false)
		elif argument.begins_with("--out="):
			out_path = argument.get_slice("=", 1)
	var dungeon: Node = load(SCENE).instantiate()
	add_child(dungeon)
	await get_tree().create_timer(3.0).timeout
	# Автоматично беремо першу здібність, щоб вікно вибору не закривало
	# сам данж на знімку.
	# Натискаємо першу картку — які саме здібності випадуть, залежить
	# від героя, тож id наперед не відомий. Карток може бути кілька
	# поспіль (талант "Стартовий рівень").
	for attempt in 8:
		var pressed := false
		for node in dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				if ProbeUtil.press_first_card(node):
					pressed = true
		if not pressed:
			break
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = false
	# PLAYER_SHOT: ведемо героя вперед, щоб на знімку був не порожній
	# вхід, а зала з ворогами й оздобленням.
	var player: CharacterBody3D = dungeon.get_node("Player")
	for i in 200:
		player.set_move_input(Vector2(0, 1))
		await get_tree().physics_frame
	# HIT_DEMO: б'ємо найближчих ворогів, щоб на знімку було видно
	# червоні смужки здоров'я.
	for enemy in dungeon.get_node("Enemies").get_children():
		if enemy.global_position.distance_to(player.global_position) < 18.0:
			enemy.take_damage(enemy.max_hp * 0.45)
	# --pitch=N — нахил камери (у межах, які дозволяє данж), --yaw=N — поворот.
	var rig: Node = dungeon.get_node("CameraRig")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pitch="):
			rig.set_pitch_limits(rig.min_pitch_degrees, rig.max_pitch_degrees, argument.get_slice("=", 1).to_float())
		elif argument.begins_with("--yaw="):
			rig.rotate_by(deg_to_rad(argument.get_slice("=", 1).to_float()))
	await get_tree().create_timer(0.5).timeout
	# --pause — знімок із відкритим меню паузи.
	if "--pause" in OS.get_cmdline_user_args():
		dungeon.call("_open_pause")
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	print("SHOT: ", ProjectSettings.globalize_path(out_path))
	get_tree().quit(0)
