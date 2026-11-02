extends Node
## Тимчасово (лише в test_env): Ринок у кількох положеннях прокрутки.
func _ready() -> void:
	PerfSettings.persist_settings = false
	var screen: Node = load("res://scenes/ui/shop.tscn").instantiate()
	add_child(screen)
	var scroll := screen.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	for step in 4:
		scroll.scroll_vertical = step * 420
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/shop_%d.png" % step)
	print("SHOT ok")
	get_tree().quit(0)
