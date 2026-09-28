extends Control

## Автори арту. Для моделей під ліцензією CC BY автора ОБОВ'ЯЗКОВО
## треба вказати в самій грі — саме тут. Додаєш у гру модель з такою
## ліцензією — допиши її сюди (назва, автор, посилання, ліцензія).
##
## Текст живе в коді, а не в .txt: текстові файли не потрапляють у
## зібрану для телефона гру.

signal closed

const TEXT := """[b]3D-моделі[/b]

[b]Зброя Клинкової Вартової[/b] — автор MiniPoly (poly.pizza/u/MiniPoly)
• «Talwar» (Талвар) — poly.pizza/m/JOjAJdTeZw
• «Devils Axe» (Диявольська сокира) — poly.pizza/m/JosYNHa2hh
   Обидві — ліцензія CC BY 3.0 (creativecommons.org/licenses/by/3.0).
   Моделі лише масштабовано й вкладено в руку героїні.
• «Axe», «Cleaver», «Dagger», «Devil's Sword», «Trident» — CC0.

[b]Чарівниця[/b] — «Witch», автор Quaternius — poly.pizza/m/QBEOV9ZUT8
[b]Посохи Чарівниці[/b] — «Staff», автор Zsky — poly.pizza/m/PE1OrCnscj,
   poly.pizza/m/DZpBi0DSgZ, poly.pizza/m/bKCpO8LRCM, poly.pizza/m/8RpWxgO3ND
   Ліцензія CC BY 3.0. Моделі лише масштабовано й вкладено в руку героїні.

[b]Книга рун Руновода[/b] — «Spellbook», автор Georg Bossenz — poly.pizza/m/bOlaFwTEGfX
   Ліцензія CC BY 3.0. Частини моделі злито в одну (для телефона) й масштабовано.

[b]Більшість інших моделей[/b] (місто, данж, монстри, персонажі) —
Quaternius (quaternius.com), CC0.

[b]Інтерфейс[/b]

Рамки, кнопки, джойстик, іконки кнопок бою й курсор — Kenney (kenney.nl):
«Fantasy UI Borders», «Mobile Controls», «Cursor Pixel Pack». Ліцензія CC0.
"""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	column.add_child(UiTheme.make_title("Автори", 26))

	# Текст довший за екран — гортається всередині рамки, а кнопка
	# "Закрити" лишається видно.
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.scroll_active = true
	body.custom_minimum_size = Vector2(660, 420)
	body.add_theme_font_size_override("normal_font_size", 17)
	body.add_theme_font_size_override("bold_font_size", 18)
	body.add_theme_color_override("default_color", UiTheme.TEXT)
	body.text = TEXT
	column.add_child(body)

	var close := Button.new()
	close.text = "Закрити"
	close.custom_minimum_size = Vector2(220, 52)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_on_close_pressed)
	column.add_child(close)

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()
