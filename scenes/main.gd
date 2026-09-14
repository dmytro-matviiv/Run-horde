extends Control

## Тимчасовий вхід у гру: поки немає головного меню (буде у Фазі 3),
## одразу переходимо в ран.

func _ready() -> void:
	get_tree().change_scene_to_file("res://scenes/run/run.tscn")
