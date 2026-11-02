extends Node
## Тимчасово (лише в test_env): вибір данжу на звичайному рівні.
func _ready() -> void:
	PerfSettings.persist_settings = false
	var select: Control = load("res://scenes/ui/dungeon_select.gd").new()
	add_child(select)
	select.call("_on_slot_pressed", 3)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/dsel_level4.png")
	print("SHOT ok")
	get_tree().quit(0)
