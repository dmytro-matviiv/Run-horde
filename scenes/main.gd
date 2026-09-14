extends Control

## Вхід у гру: одразу переходимо в головне меню.

func _ready() -> void:
	# call_deferred, бо дерево сцени ще "зайняте" додаванням нод одразу
	# після старту — прямий виклик тут падає з помилкою
	# "Parent node is busy adding/removing children".
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
