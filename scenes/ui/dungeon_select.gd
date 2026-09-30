extends Control

## Вибір рівня данжу — відкривається біля арки на півночі міста.
##
## Рівні гортаєш іконками (ряд слотів, як зброя чи герой), а внизу одна
## велика панель з описом обраного: хто там водиться, хто бос, скільки
## золота дає, і кнопка "Увійти". Наступний рівень закритий, доки не
## пройдено попередній, — і панель прямо про це пише.
##
## Картинка рівня — слот під арт: assets/ui/icons/dungeons/<id рівня>.png
## (crypts, fungal, citadel...). Поки її немає, стоїть черепок кольору
## смолоскипів рівня.

signal level_chosen(index: int)
signal closed

const DIFFICULTY_TITLES := [
	"", "Легка", "Середня", "Висока", "Дуже висока",
	"Мега-бос", "Смертельна", "Жахлива", "Немислима", "Позамежна",
	"Мега-бос II", "Кошмарна", "Апокаліптична", "Забута", "Остання перед троном",
	"Мега-бос III",
]

var _index := 0
var _slot_row: HBoxContainer
var _slot_scroll: ScrollContainer
var _slot_buttons: Array[Button] = []
var _name_label: Label
var _difficulty_label: Label
var _subtitle_label: Label
var _enemies_label: Label
var _boss_label: Label
var _gold_label: Label
var _lock_label: Label
var _enter_button: Button
var _prev_button: Button
var _next_button: Button
var _art_display: TextureRect

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

	# Рівнів більше, ніж влазить у ширину екрана, тож ряд гортається
	# вбік — палець чи колесо миші, прямо над самими іконками.
	var picker := UiTheme.make_picker_row()
	_slot_scroll = picker.scroll
	_slot_row = picker.row
	_slot_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_slot_scroll)
	for index in DungeonLevels.get_level_count():
		var level := DungeonLevels.get_level(index)
		var accent: Color = level.theme.torch
		var texture := ArtSlots.dungeon_icon(level.id)
		var tint := Color.WHITE
		if texture == null:
			texture = UiTheme.control_icon("skull")
			tint = accent
		var slot := UiTheme.make_picker_slot(texture, tint, 88.0)
		slot.pressed.connect(_on_slot_pressed.bind(index))
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)

	# Опис обраного рівня — одна велика панель, як діалог квесту, зі
	# стрілками обабіч: гортати можна і ними, і рядом іконок вище, і
	# колесом миші / пальцем по самому ряду.
	var paging_row := HBoxContainer.new()
	paging_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paging_row.add_theme_constant_override("separation", 10)
	column.add_child(paging_row)

	_prev_button = _make_arrow_button("‹")
	_prev_button.pressed.connect(_on_step_pressed.bind(-1))
	paging_row.add_child(_prev_button)

	var info_panel := PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_panel.add_theme_stylebox_override("panel", UiTheme.panel_box())
	paging_row.add_child(info_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info_panel.add_child(info)

	_art_display = TextureRect.new()
	_art_display.custom_minimum_size = Vector2(0, 150)
	_art_display.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_art_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	info.add_child(_art_display)

	_next_button = _make_arrow_button("›")
	_next_button.pressed.connect(_on_step_pressed.bind(1))
	paging_row.add_child(_next_button)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 24)
	info.add_child(_name_label)

	_difficulty_label = Label.new()
	_difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_difficulty_label.add_theme_font_size_override("font_size", 16)
	_difficulty_label.add_theme_color_override("font_color", UiTheme.GOLD)
	info.add_child(_difficulty_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 15)
	_subtitle_label.add_theme_color_override("font_color", UiTheme.TEXT)
	info.add_child(_subtitle_label)

	_enemies_label = Label.new()
	_enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemies_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enemies_label.add_theme_font_size_override("font_size", 13)
	_enemies_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	info.add_child(_enemies_label)

	var stat_row := HBoxContainer.new()
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_row.add_theme_constant_override("separation", 24)
	info.add_child(stat_row)
	_boss_label = Label.new()
	_boss_label.add_theme_font_size_override("font_size", 15)
	_boss_label.add_theme_color_override("font_color", UiTheme.DANGER)
	stat_row.add_child(_boss_label)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 15)
	_gold_label.add_theme_color_override("font_color", UiTheme.GOLD)
	stat_row.add_child(_gold_label)

	_lock_label = Label.new()
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_label.add_theme_font_size_override("font_size", 14)
	_lock_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	info.add_child(_lock_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 16)
	column.add_child(bottom_row)

	var close := Button.new()
	close.text = "Назад у місто"
	close.custom_minimum_size = Vector2(220, 52)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(_on_close_pressed)
	bottom_row.add_child(close)

	_enter_button = Button.new()
	_enter_button.custom_minimum_size = Vector2(240, 52)
	_enter_button.add_theme_font_size_override("font_size", 18)
	bottom_row.add_child(_enter_button)

	_index = mini(GameState.max_dungeon_level, DungeonLevels.get_level_count() - 1)
	_refresh()
	UiTheme.scroll_to_center.call_deferred(_slot_scroll, _slot_buttons[_index])

func _on_slot_pressed(index: int) -> void:
	_index = index
	_refresh()
	UiTheme.scroll_to_center(_slot_scroll, _slot_buttons[_index])

## Стрілки обабіч картки — на сусідній рівень; за межею просто нічого не
## робить (кнопка й так вимкнена на першому/останньому рівні).
func _on_step_pressed(step: int) -> void:
	var next := _index + step
	if next < 0 or next >= DungeonLevels.get_level_count():
		return
	_on_slot_pressed(next)

func _make_arrow_button(glyph: String) -> Button:
	var button := Button.new()
	button.text = glyph
	button.custom_minimum_size = Vector2(60, 0)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 34)
	return button

func _refresh() -> void:
	var level := DungeonLevels.get_level(_index)
	var accent: Color = level.theme.torch
	var unlocked := _index <= GameState.max_dungeon_level
	var cleared := _index < GameState.max_dungeon_level

	for index in _slot_buttons.size():
		var other := DungeonLevels.get_level(index)
		var other_accent: Color = other.theme.torch
		UiTheme.style_picker_slot(_slot_buttons[index], index == _index, index <= GameState.max_dungeon_level, other_accent)
		_slot_buttons[index].button_pressed = index == _index

	_prev_button.disabled = _index <= 0
	_next_button.disabled = _index >= DungeonLevels.get_level_count() - 1

	var art := ArtSlots.dungeon_icon(level.id)
	_art_display.visible = art != null
	_art_display.texture = art

	_name_label.text = "Рівень %d. %s" % [_index + 1, level.title]
	_name_label.add_theme_color_override("font_color", accent if unlocked else UiTheme.TEXT_DIM)
	_difficulty_label.text = "Складність: %s" % DIFFICULTY_TITLES[clampi(level.difficulty, 1, DIFFICULTY_TITLES.size() - 1)]
	_subtitle_label.text = level.subtitle
	_subtitle_label.add_theme_color_override("font_color", UiTheme.TEXT if unlocked else UiTheme.TEXT_DIM)
	_enemies_label.text = "Вороги: %s" % ", ".join(DungeonLevels.get_enemy_names(_index))
	_boss_label.text = "Бос: %s" % level.boss.name
	_gold_label.text = "Золото: ×%.1f" % float(level.stats.gold)

	if unlocked:
		_lock_label.visible = false
	else:
		_lock_label.visible = true
		var previous := DungeonLevels.get_level(_index - 1)
		_lock_label.text = "Спершу пройди «%s»" % previous.title

	if not unlocked:
		_enter_button.text = "Закрито"
		_enter_button.disabled = true
		_enter_button.theme_type_variation = &""
	elif cleared:
		_enter_button.text = "Пройдено — увійти знову"
		_enter_button.disabled = false
		_enter_button.theme_type_variation = &""
	else:
		_enter_button.text = "Увійти"
		_enter_button.disabled = false
		UiTheme.make_primary(_enter_button)
	if _enter_button.pressed.is_connected(_on_enter_pressed):
		_enter_button.pressed.disconnect(_on_enter_pressed)
	_enter_button.pressed.connect(_on_enter_pressed)

func _on_enter_pressed() -> void:
	level_chosen.emit(_index)
	queue_free()

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

## Кнопка "назад" на телефоні закриває вибір, а не виходить у меню.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()
