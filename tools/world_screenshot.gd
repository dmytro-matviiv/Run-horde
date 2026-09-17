extends Node

## Інструмент розробника: запускає сцену світу, дає їй ожити кілька
## секунд і зберігає знімок екрана. Так я можу побачити результат сам,
## не смикаючи замовника проханням "запусти й покажи".

const SCENE := "res://scenes/world/base_island.tscn"
const OUT_PATH := "user://world_screenshot.png"
const WARMUP_SECONDS := 1.5

func _ready() -> void:
	var world: Node = load(SCENE).instantiate()
	add_child(world)
	await get_tree().create_timer(WARMUP_SECONDS).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(OUT_PATH)
	print("SHOT: ", ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit(0)
