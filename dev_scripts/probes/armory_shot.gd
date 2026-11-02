extends Node
## Тимчасово (лише в test_env): Збройня з кожною зброєю героя.
func _ready() -> void:
	PerfSettings.persist_settings = false
	var hero := "void_assassin"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hero="):
			hero = argument.get_slice("=", 1)
	GameState.selected_hero_id = StringName(hero)
	var screen: Node = load("res://scenes/ui/weapons.tscn").instantiate()
	add_child(screen)
	var count: int = (screen.get("_weapons") as Array).size()
	for i in count:
		screen.call("_on_slot_pressed", i)
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/arm_%s_%d.png" % [hero, i])
	print("SHOT ok ", count)
	get_tree().quit(0)
