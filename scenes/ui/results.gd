extends Control

## Екран результатів — показується після смерті або перемоги
## (run.gd._end_run). Дані беруться з GameState.last_run_* — це
## тимчасові поля лише для передачі між сценами, у сейв не пишуться.

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var stats_label: Label = $CenterContainer/VBoxContainer/StatsLabel
@onready var double_gold_button: Button = $CenterContainer/VBoxContainer/DoubleGoldButton

func _ready() -> void:
	title_label.text = "Перемога!" if GameState.last_run_victory else "Ви загинули"
	double_gold_button.visible = GameState.last_run_gold > 0 and not GameState.last_run_gold_doubled
	_refresh_stats()

func _refresh_stats() -> void:
	var minutes := int(GameState.last_run_time) / 60
	var seconds := int(GameState.last_run_time) % 60
	var gold := GameState.last_run_gold * (2 if GameState.last_run_gold_doubled else 1)
	stats_label.text = "Золото: %d\nВбито ворогів: %d\nЧас: %02d:%02d" % [
		gold,
		GameState.last_run_kills,
		minutes,
		seconds,
	]

## ×2 золота за ран через rewarded-рекламу (раз на ран, розділ 8 ТЗ).
func _on_double_gold_pressed() -> void:
	double_gold_button.disabled = true
	AdsManager.show_rewarded_ad(_on_double_gold_watched, _on_double_gold_skipped)

func _on_double_gold_watched() -> void:
	# Базове золото вже зараховане в кінці рану — додаємо ту ж суму ще раз.
	GameState.add_gold(GameState.last_run_gold)
	GameState.last_run_gold_doubled = true
	double_gold_button.visible = false
	_refresh_stats()

func _on_double_gold_skipped() -> void:
	double_gold_button.text = "Нагороду не отримано"

func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/run/run.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
