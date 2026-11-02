extends Node
func _ready() -> void:
	PerfSettings.persist_settings = false
	var screen: Node = load("res://scenes/ui/heroes.tscn").instantiate()
	add_child(screen)
	screen.call("_on_slot_pressed", 3)
	var shown: HeroDef = screen.call("_current")
	var cards: Array = screen.call("_cards_for", shown)
	print("cards: ", cards.size(), " last keys: ", cards[-1].keys())
	screen.call("_on_ability_pressed", cards[-1])
	await get_tree().create_timer(0.5).timeout
	var dialog: Control = screen.get_child(screen.get_child_count() - 1)
	print("dialog rect ", dialog.get_global_rect())
	for node in dialog.find_children("*", "Control", true, false):
		if node is OrnatePanel or node is ScrollContainer or node is CenterContainer:
			print("  ", node.get_class(), " ", node.get_global_rect(), " min ", node.get_combined_minimum_size())
	for child in screen.get_children():
		print("child: ", child.name, " ", child.get_class(), " visible=", child.visible if child is CanvasItem else "-")
	get_tree().quit(0)
