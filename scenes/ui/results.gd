extends Control

## Екран результатів — показується після смерті або перемоги
## (run.gd._end_run). Дані беруться з GameState.last_run_* — це
## тимчасові поля лише для передачі між сценами, у сейв не пишуться.

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var stats_label: Label = $CenterContainer/VBoxContainer/StatsLabel

func _ready() -> void:
	title_label.text = "Перемога!" if GameState.last_run_victory else "Ви загинули"
	var minutes := int(GameState.last_run_time) / 60
	var seconds := int(GameState.last_run_time) % 60
	stats_label.text = "Золото: %d\nВбито ворогів: %d\nЧас: %02d:%02d" % [
		GameState.last_run_gold,
		GameState.last_run_kills,
		minutes,
		seconds,
	]

func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/run/run.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
