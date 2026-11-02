import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:70])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


# --- іконки здібностей: кругла іконка без прямокутної рамки кнопки ---
edit('scenes/ui/ability_icon.gd', [
('''	text = ""
	tooltip_text = title
	custom_minimum_size = Vector2(SIZE, SIZE)
	queue_redraw()''', '''	text = ""
	tooltip_text = title
	custom_minimum_size = Vector2(SIZE, SIZE)
	# Іконка кругла — прямокутна рамка кнопки з теми тут зайва.
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	queue_redraw()'''),
])

# --- вибір здібності: картка з назвою, описом і рівнем окремими рядками ---
edit('scenes/ui/level_up_choice.gd', [
('''func setup_cards(new_level: int, cards: Array) -> void:
	level_label.text = "Рівень %d!" % new_level
	for card: Dictionary in cards:
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 190)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s

%s

Рівень %d/%d" % [card.title, card.text, card.level, card.max]
		button.pressed.connect(_on_card_pressed.bind(card.id))
		cards_container.add_child(button)

func setup(new_level: int, choices: Array[UpgradeDef], current_levels: Dictionary) -> void:
	level_label.text = "Рівень %d!" % new_level
	for upgrade in choices:
		var current_level: int = current_levels.get(upgrade.id, 0)
		var card := Button.new()
		# Ширина фіксована, а довгий опис переноситься на новий рядок.
		# Без цього картка розтягувалась під найдовший рядок і вилазила
		# за край екрана — опис здібності було не дочитати.
		card.custom_minimum_size = Vector2(250, 190)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.text = "%s\\n\\n%s\\n\\nРівень %d/%d" % [
			upgrade.title,
			upgrade.description,
			current_level + 1,
			upgrade.max_level,
		]
		card.pressed.connect(_on_card_pressed.bind(upgrade.id))
		cards_container.add_child(card)
''', '''func setup_cards(new_level: int, cards: Array) -> void:
	level_label.text = "Рівень %d!" % new_level
	for card: Dictionary in cards:
		cards_container.add_child(_make_card(card.id, card.title, card.text, card.level, card.max))

func setup(new_level: int, choices: Array[UpgradeDef], current_levels: Dictionary) -> void:
	level_label.text = "Рівень %d!" % new_level
	for upgrade in choices:
		var current_level: int = current_levels.get(upgrade.id, 0)
		cards_container.add_child(_make_card(upgrade.id, upgrade.title, upgrade.description,
			current_level + 1, upgrade.max_level))

## Картка — кнопка в рамці теми, а всередині три рядки: назва
## (блідо-зелена), опис і рівень. Ширина фіксована, довгий опис
## переноситься — інакше картка вилазила б за край екрана.
func _make_card(id: StringName, title: String, text: String, level: int, max_level: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(250, 200)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.pressed.connect(_on_card_pressed.bind(id))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 12
	box.offset_bottom = -12
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	box.add_child(_card_label(title, 20, UiTheme.HEADING))
	box.add_child(_card_label(text, 16, UiTheme.TEXT))
	box.add_child(_card_label("Рівень %d/%d" % [level, max_level], 14, UiTheme.TEXT_DIM))
	return card

func _card_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
'''),
])

# --- автори: текст гортається, кнопка "Закрити" завжди на екрані ---
edit('scenes/ui/credits.gd', [
('''[b]Більшість інших моделей[/b] (місто, данж, монстри, персонажі) —
Quaternius (quaternius.com), CC0.
"""''', '''[b]Більшість інших моделей[/b] (місто, данж, монстри, персонажі) —
Quaternius (quaternius.com), CC0.

[b]Інтерфейс[/b]

Рамки, кнопки, джойстик, іконки кнопок бою й курсор — Kenney (kenney.nl):
«Fantasy UI Borders», «Mobile Controls», «Cursor Pixel Pack». Ліцензія CC0.
"""'''),
('''	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.custom_minimum_size = Vector2(640, 0)''', '''	# Текст довший за екран — гортається всередині рамки, а кнопка
	# "Закрити" лишається видно.
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.scroll_active = true
	body.custom_minimum_size = Vector2(660, 420)'''),
])

# --- офлайн-нагорода ---
edit('scenes/ui/offline_reward.gd', [
('''func _ready() -> void:
	amount_label.text = "+%d золота" % GameState.pending_offline_gold
''', '''func _ready() -> void:
	amount_label.text = "+%d золота" % GameState.pending_offline_gold
	# Оформлення (UiTheme): заголовок блідо-зелений, подвоєння — світла
	# головна кнопка.
	var title := $CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel as Label
	title.add_theme_color_override("font_color", UiTheme.HEADING)
	amount_label.add_theme_color_override("font_color", UiTheme.GOLD)
	UiTheme.make_primary(claim_double_button)
'''),
])

# --- збройня: золото й геми золотим, як на інших екранах ---
edit('scenes/ui/weapons.gd', [
('''	hero_label.text = "Арсенал: %s" % HeroPool.get_def(_hero_id).title
	hero_label.add_theme_color_override("font_color", UiTheme.TEXT)
''', '''	hero_label.text = "Арсенал: %s" % HeroPool.get_def(_hero_id).title
	hero_label.add_theme_color_override("font_color", UiTheme.TEXT)
	gems_label.add_theme_color_override("font_color", UiTheme.GOLD)
'''),
])
print('ok')
