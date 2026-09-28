extends Control

## Екран вибору апгрейду при левел-апі. Гру ставить на паузу той,
## хто цю сцену створює (run.gd) — сама сцена лише показує картки
## й після кліку віддає id обраного апгрейду через сигнал.

signal upgrade_chosen(id: StringName)

@onready var level_label: Label = $CenterContainer/VBoxContainer/LevelLabel
@onready var cards_container: HBoxContainer = $CenterContainer/VBoxContainer/CardsContainer

## Картки нового зразка: кожна вже знає свій рівень і межу. Саме ними
## користується данж (RunUpgrades), бо його здібності залежать від
## героя та його зброї.
func _ready() -> void:
	# Заголовок — блідо-зелений між розділювачами, як у фентезійному
	# оформленні (UiTheme); картки — кнопки в рамці теми.
	level_label.add_theme_color_override("font_color", UiTheme.HEADING)
	UiTheme.add_dividers(level_label)

func setup_cards(new_level: int, cards: Array) -> void:
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

func _on_card_pressed(id: StringName) -> void:
	upgrade_chosen.emit(id)
