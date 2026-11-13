extends Node
## Тимчасово (лише в test_env): HUD міста з кнопкою входу в будівлю.
func _ready() -> void:
	PerfSettings.persist_settings = false
	var world: Node = load("res://scenes/world/haven/haven.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(2.5).timeout
	var action: Button = world.get("action_button")
	action.text = "Храм талантів"
	action.visible = true
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/town_hud.png")
	print("SHOT ok")
	get_tree().quit(0)
