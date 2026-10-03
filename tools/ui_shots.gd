extends Node

## Знімки всіх екранів інтерфейсу одним запуском — щоб перевірити
## оформлення (UiTheme), не клацаючи гру руками:
##   godot --path . res://tools/ui_shots.tscn -- --out=D:/папка [--prefix=phone_]
## Розмір вікна задає сам Godot (--resolution 1600x720 — як телефон).

const SCREENS := [
	["menu", "res://scenes/ui/main_menu.tscn"],
	["heroes", "res://scenes/ui/heroes.tscn"],
	["weapons", "res://scenes/ui/weapons.tscn"],
	["temple", "res://scenes/ui/meta_upgrades.tscn"],
	["shop", "res://scenes/ui/shop.tscn"],
]

var _out_dir := "D:/RuneHorde_work/screenshots"
var _prefix := "ui_"

func _ready() -> void:
	PerfSettings.persist_settings = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out_dir = argument.get_slice("=", 1)
		elif argument.begins_with("--prefix="):
			_prefix = argument.get_slice("=", 1)
	# Офлайн-золото показуємо окремим знімком — у меню воно б закрило екран.
	var offline_gold := GameState.pending_offline_gold
	GameState.pending_offline_gold = 0

	for entry: Array in SCREENS:
		var screen: Node = load(entry[1]).instantiate()
		add_child(screen)
		await _shot(entry[0])
		screen.queue_free()
		await get_tree().process_frame

	# Вікна, що відкриваються поверх гри, — на тлі меню.
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)

	var credits: Control = load("res://scenes/ui/credits.gd").new()
	add_child(credits)
	await _shot("credits")
	credits.queue_free()

	var select: Control = load("res://scenes/ui/dungeon_select.gd").new()
	add_child(select)
	await _shot("dungeon_select")
	select.queue_free()

	var level_up: Node = load("res://scenes/ui/level_up_choice.tscn").instantiate()
	add_child(level_up)
	level_up.setup_cards(3, [
		{"id": &"damage", "title": "Гострота", "text": "Удари завдають на 15% більше шкоди.", "level": 1, "max": 5},
		{"id": &"whirl_power", "title": "Вихор", "text": "Вихор крутиться довше й зачіпає далі.", "level": 2, "max": 3},
		{"id": &"lifesteal", "title": "Жага крові", "text": "Кожен удар повертає трохи здоров'я.", "level": 1, "max": 3},
	])
	await _shot("level_up")
	level_up.queue_free()

	var pause: Node = load("res://scenes/ui/pause_menu.tscn").instantiate()
	add_child(pause)
	pause.configure("Бій зупинено. Золото з цього походу вже твоє.", "Покинути данж",
		"Здібності цього походу зникнуть, золото лишиться. Вийти в місто?", "Так, у місто")
	await _shot("pause")
	pause.call("_on_quit_pressed")
	await _shot("pause_confirm")
	pause.queue_free()

	# Екран завантаження — як посеред переходу в данж.
	(SceneLoader.get("_title_label") as Label).text = "Забуті склепи"
	(SceneLoader.get("_hint_label") as Label).text = SceneLoader.HINTS[0]
	(SceneLoader.get("_root") as Control).modulate.a = 1.0
	SceneLoader.call("_set_progress", 0.6)
	SceneLoader.visible = true
	await _shot("loading")
	SceneLoader.visible = false

	GameState.pending_offline_gold = maxi(offline_gold, 1234)
	var offline: Node = load("res://scenes/ui/offline_reward.tscn").instantiate()
	add_child(offline)
	await _shot("offline")
	GameState.pending_offline_gold = offline_gold
	get_tree().quit(0)

func _shot(name: String) -> void:
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	var path := "%s/%s%s.png" % [_out_dir, _prefix, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT: ", path)
