extends Control

## Головне меню: точка повернення між ранами. "Грати" веде в ран,
## "Апгрейди" — на екран мета-прогресії (тут гравець витрачає золото
## між ранами — наша "база").

@onready var gold_label: Label = $CenterContainer/VBoxContainer/GoldLabel

func _ready() -> void:
	_update_gold_label()

func _update_gold_label() -> void:
	gold_label.text = "Золото: %d" % GameState.gold

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/run/run.tscn")

func _on_upgrades_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/meta_upgrades.tscn")
