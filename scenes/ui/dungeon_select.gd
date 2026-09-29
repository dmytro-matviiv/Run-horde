extends Control

## Вибір рівня данжу — відкривається біля арки на півночі міста.
##
## Картка на кожен рівень: назва, складність, хто там водиться і хто бос,
## скільки золота дають. Наступний рівень закритий, доки не пройдено
## попередній, — і картка прямо про це пише.
##
## Картинка рівня — слот під арт: assets/ui/icons/dungeons/<id рівня>.png
## (crypts, fungal, citadel). Поки її немає, стоїть рамка в кольорі теми.

signal level_chosen(index: int)
signal closed

const DIFFICULTY_TITLES := [
	"", "Легка", "Середня", "Висока", "Дуже висока", "Смертельна", "Жахлива", "Немислима", "Позамежна",
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24
	column.offset_right = -24
	column.offset_top = 18
	column.offset_bottom = -18
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	column.add_child(UiTheme.make_title("Данж — обери рівень", 28))

	# Рівнів більше, ніж влазить у ширину екрана (8 карток), тож ряд
	# гортається вбік — палець чи колесо миші. Прокрутку одразу ставимо
	# на розблокований/незавершений рівень, щоб гравець не гортав вручну
	# крізь пройдені.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 14)
	scroll.add_child(cards)
	var focus_index := mini(GameState.max_dungeon_level, DungeonLevels.get_level_count() - 1)
	var focus_card: Control = null
	for index in DungeonLevels.get_level_count():
		var card := _build_card(index)
		cards.add_child(card)
		if index == focus_index:
			focus_card = card
	if focus_card != null:
		# Розмір картки й контейнера відомий лише після розкладки —
		# гортаємо на наступному кадрі, не раніше.
		_scroll_to_card.call_deferred(scroll, focus_card)

	var close := Button.new()
	close.text = "Назад у місто"
	close.custom_minimum_size = Vector2(240, 52)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_on_close_pressed)
	column.add_child(close)

func _scroll_to_card(scroll: ScrollContainer, card: Control) -> void:
	scroll.scroll_horizontal = int(card.position.x - scroll.size.x * 0.5 + card.size.x * 0.5)

func _build_card(index: int) -> Control:
	var level := DungeonLevels.get_level(index)
	var theme: Dictionary = level.theme
	var unlocked := index <= GameState.max_dungeon_level
	var cleared := index < GameState.max_dungeon_level
	var accent: Color = theme.torch

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(250, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Рамка — кольору світла цього рівня; закритий рівень — сірий.
	card.add_theme_stylebox_override("panel", UiTheme.panel_box(
		accent.lerp(Color.WHITE, 0.35) if unlocked else Color(0.45, 0.45, 0.48)))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(0, 92)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var own_picture := ArtSlots.dungeon_icon(level.id)
	if own_picture != null:
		picture.texture = own_picture
		picture.modulate = Color.WHITE if unlocked else Color(0.4, 0.4, 0.45)
		box.add_child(picture)
	else:
		# Своєї картинки рівня ще немає — черепок у слоті кольору рівня.
		var slot := UiTheme.make_slot(UiTheme.control_icon("skull"), 56.0,
			accent if unlocked else Color(0.4, 0.4, 0.45))
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(slot)

	box.add_child(_label("Рівень %d. %s" % [index + 1, level.title], 20,
		accent if unlocked else UiTheme.TEXT_DIM))
	box.add_child(_label("Складність: %s" % DIFFICULTY_TITLES[clampi(level.difficulty, 1, DIFFICULTY_TITLES.size() - 1)], 15, UiTheme.GOLD))
	box.add_child(_label(level.subtitle, 14, UiTheme.TEXT if unlocked else UiTheme.TEXT_DIM))
	box.add_child(_label("Вороги: %s" % ", ".join(DungeonLevels.get_enemy_names(index)), 13, UiTheme.TEXT_DIM))
	box.add_child(_label("Бос: %s" % level.boss.name, 13, UiTheme.DANGER))
	box.add_child(_label("Золото: ×%.1f" % float(level.stats.gold), 13, UiTheme.GOLD))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_size_override("font_size", 18)
	if not unlocked:
		var previous := DungeonLevels.get_level(index - 1)
		button.text = "Закрито"
		button.disabled = true
		box.add_child(_label("Спершу пройди «%s»" % previous.title, 13, UiTheme.TEXT_DIM))
	elif cleared:
		button.text = "Пройдено — увійти знову"
	else:
		button.text = "Увійти"
		UiTheme.make_primary(button)
	button.pressed.connect(_on_level_pressed.bind(index))
	box.add_child(button)
	return card

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _on_level_pressed(index: int) -> void:
	level_chosen.emit(index)
	queue_free()

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

## Кнопка "назад" на телефоні закриває вибір, а не виходить у меню.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()
