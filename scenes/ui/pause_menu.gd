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
	# Оформлення з арту гравця: панель — різьблена рамка (OrnatePanel, задана
	# у сцені), заголовок золотом, безпечні дії ("Продовжити", "Ні,
	# повернутись") — зелені кнопки, вихід — сині.
	($Panel/VBoxContainer as VBoxContainer).add_theme_constant_override("separation", 12)
	var title := $Panel/VBoxContainer/TitleLabel as Label
	title.add_theme_font_override("font", UiTheme.font(900))
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", OrnateDialog.TITLE_COLOR)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.1, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	_style_text($Panel/VBoxContainer/HintLabel as Label, Color(0.92, 0.9, 0.98))
	_style_text($Panel/VBoxContainer/ConfirmRow/WarnLabel as Label, Color(1.0, 0.55, 0.5))
	UiTheme.art_primary($Panel/VBoxContainer/ResumeButton as Button)
	UiTheme.art_secondary(quit_button)
	UiTheme.art_secondary($Panel/VBoxContainer/ConfirmRow/ConfirmQuitButton as Button)
	UiTheme.art_primary($Panel/VBoxContainer/ConfirmRow/CancelQuitButton as Button)
	($Panel/VBoxContainer/ConfirmRow/CancelQuitButton as Button).custom_minimum_size.y = 52
	# Панель — за розміром вмісту: у сцені вона задана вищою, і під
	# кнопками зяяла порожнеча. Прив'язка по центру з ростом в обидва боки
	# тримає її посередині й тоді, коли з'являється підтвердження.
	var panel := $Panel as Control
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0

func _style_text(label: Label, color: Color) -> void:
	label.add_theme_font_override("font", UiTheme.font(700))
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("outline_size", 3)

## Тексти під інший режим. У данжі золото зараховується одразу, тож
## вихід забирає лише здібності походу — і попередження інше.
func configure(hint: String, quit_text: String, warning: String, confirm_text: String) -> void:
	($Panel/VBoxContainer/HintLabel as Label).text = hint
	quit_button.text = quit_text
	($Panel/VBoxContainer/ConfirmRow/WarnLabel as Label).text = warning
	($Panel/VBoxContainer/ConfirmRow/ConfirmQuitButton as Button).text = confirm_text

## Esc або "назад" на телефоні — те саме, що "Продовжити".
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resumed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		resumed.emit()

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
