extends Control

## Вікно "Воскреснути за рекламу?" після смерті героя (раз на ран,
## розділ 8 ТЗ). Показ реклами й саме воскресіння робить run.gd — тут
## лише вибір гравця.

signal revive_requested
signal gave_up

@onready var revive_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ReviveButton

func _on_revive_pressed() -> void:
	# Блокуємо повторне натискання, поки відкрита реклама.
	revive_button.disabled = true
	revive_requested.emit()

## Ролик не завантажився або його закрили достроково — вікно лишається,
## щоб гравець міг завершити ран.
func mark_revive_unavailable() -> void:
	revive_button.text = "Воскресіння недоступне"
	revive_button.disabled = true

func _on_give_up_pressed() -> void:
	gave_up.emit()
