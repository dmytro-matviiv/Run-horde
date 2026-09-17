extends Node

## Знімок данжу: запускає рівень, чекає, поки збереться геометрія й
## напечеться карта прохідності, і зберігає кадр.

const SCENE := "res://scenes/dungeon/dungeon.tscn"
const OUT_PATH := "user://dungeon_screenshot.png"

func _ready() -> void:
	var dungeon: Node = load(SCENE).instantiate()
	add_child(dungeon)
	await get_tree().create_timer(3.0).timeout
	# Автоматично беремо першу здібність, щоб вікно вибору не закривало
	# сам данж на знімку.
	for node in dungeon.get_node("HUD").get_children():
		if node.has_signal("upgrade_chosen"):
			node.upgrade_chosen.emit(&"weapon_damage")
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = false
	# PLAYER_SHOT: ведемо героя вперед, щоб на знімку був не порожній
	# вхід, а зала з ворогами й оздобленням.
	var player: CharacterBody3D = dungeon.get_node("Player")
	for i in 200:
		player.set_move_input(Vector2(0, 1))
		await get_tree().physics_frame
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_PATH)
	print("SHOT: ", ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit(0)
