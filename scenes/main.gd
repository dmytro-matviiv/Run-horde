extends Control

## Вхід у гру: одразу переходимо в головне меню.

func _ready() -> void:
	# call_deferred, бо дерево сцени ще "зайняте" додаванням нод одразу
	# після старту — прямий виклик тут падає з помилкою
	# "Parent node is busy adding/removing children".
	# Старт гри — через заставку з логотипом і смужкою завантаження.
	SceneLoader.first_boot = true
	SceneLoader.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", "Rune Horde")
