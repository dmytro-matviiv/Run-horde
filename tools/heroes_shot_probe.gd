extends Node
## Знімок Зали героїв для конкретного героя (перевірка іконок прийомів).
##   godot --path . res://tools/heroes_shot_probe.tscn -- --hero=runewielder --out=D:/шлях.png

func _ready() -> void:
	PerfSettings.persist_settings = false
	var hero_id := "runewielder"
	var out := "D:/RuneHorde_work/screenshots/heroes_check.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hero="):
			hero_id = argument.get_slice("=", 1)
		elif argument.begins_with("--out="):
			out = argument.get_slice("=", 1)
	GameState.selected_hero_id = StringName(hero_id)
	var screen: Node = load("res://scenes/ui/heroes.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT: ", out)
	get_tree().quit(0)
