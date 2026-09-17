extends Control

## Меню паузи під час рану. Дві чесні дії:
##  - "Продовжити" — повертає в бій;
##  - "Вийти без збереження" — ран скасовується цілком: зібране за цей
##    ран золото НЕ зараховується, рівні героя в цьому рані зникають.
##
## Саме тому кнопка виходу питає підтвердження: гравець має розуміти,
## що втрачає прогрес поточного рану, а не всієї гри (куплені апгрейди
## й герої лишаються).

signal resumed
signal quit_confirmed

@onready var confirm_row: Control = $Panel/VBoxContainer/ConfirmRow
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

func _ready() -> void:
	confirm_row.visible = false

func _on_resume_pressed() -> void:
	resumed.emit()

func _on_quit_pressed() -> void:
	# Перший натиск лише показує попередження.
	confirm_row.visible = true
	quit_button.visible = false

func _on_confirm_quit_pressed() -> void:
	quit_confirmed.emit()

func _on_cancel_quit_pressed() -> void:
	confirm_row.visible = false
	quit_button.visible = true
