extends Control

## Вибір рівня данжу — відкривається біля арки на півночі міста.
##
## Рівні гортаєш іконками (ряд слотів, як зброя чи герой) або стрілками
## обабіч, а посередині — різьблена панель з описом обраного: картинка
## рівня ліворуч, праворуч назва, складність, хто там водиться, хто бос і
## скільки золота дає. Унизу — "Назад у місто" і "Увійти". Наступний рівень
## закритий, доки не пройдено попередній, — і панель прямо про це пише.
##
## Оформлення — з арту гравця: банер з гербом, стрілки-плашки з рунами,
## OrnatePanel, зелена й синя кнопки.
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

## Стрілки гортання (арт гравця): плашка тягнеться лише вздовж, шеврон —
## окремою іконкою посередині, щоб не витягувався.
const ARROW_FRAME := "res://assets/ui/theme/arrow_frame.png"
const ARROW_LEFT := "res://assets/ui/theme/arrow_chevron_left.png"
const ARROW_RIGHT := "res://assets/ui/theme/arrow_chevron_right.png"
const ARROW_WIDTH := 60.0
const TITLE_COLOR := Color(1.0, 0.86, 0.5)
const TEXT_COLOR := Color(0.95, 0.93, 0.98)
const MUTED_COLOR := Color(0.8, 0.78, 0.9)

var _index := 0
var _slot_row: HBoxContainer
var _slot_scroll: ScrollContainer
var _slot_buttons: Array[Button] = []
var _name_label: Label
var _difficulty_tag: PanelContainer
var _difficulty_label: Label
var _subtitle_label: Label
var _enemies_label: Label
var _boss_label: Label
var _gold_badge: CurrencyBadge
var _lock_label: Label
var _enter_button: Button
var _prev_button: Button
var _next_button: Button
var _art_display: TextureRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Майже непрозоре тло: місто позаду (і його кнопка "Вхід у данж") не
	# просвічує крізь вибір.
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24
	column.offset_right = -24
	column.offset_top = 14
	column.offset_bottom = -16
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var title := OrnateBanner.new("Данж — обери рівень", 28)
	title.custom_minimum_size = Vector2(620, 0)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(title)

	# Рівнів більше, ніж влазить у ширину екрана, тож ряд гортається
	# вбік — палець чи колесо миші, прямо над самими іконками.
	var picker := UiTheme.make_picker_row()
	_slot_scroll = picker.scroll
	_slot_row = picker.row
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

	# Опис обраного рівня — різьблена панель зі стрілками обабіч: гортати
	# можна і ними, і рядом іконок вище, і колесом миші / пальцем по ряду.
	var paging_row := HBoxContainer.new()
	paging_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paging_row.add_theme_constant_override("separation", 12)
	column.add_child(paging_row)

	_prev_button = _make_arrow_button(ARROW_LEFT, "‹")
	_prev_button.pressed.connect(_on_step_pressed.bind(-1))
	paging_row.add_child(_prev_button)

	var info_panel := OrnatePanel.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paging_row.add_child(info_panel)
	# Картинка рівня ліворуч, опис праворуч — так панель низька й уміщається
	# між рядом іконок і кнопками навіть на 648 px заввишки.
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 24)
	info_panel.add_child(info_row)

	_art_display = TextureRect.new()
	_art_display.custom_minimum_size = Vector2(190, 170)
	_art_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art_display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_row.add_child(_art_display)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	info_row.add_child(info)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	info.add_child(name_row)
	_name_label = Label.new()
	_name_label.add_theme_font_override("font", UiTheme.font(900))
	_name_label.add_theme_font_size_override("font_size", 25)
	_name_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.1, 0.9))
	_name_label.add_theme_constant_override("outline_size", 6)
	name_row.add_child(_name_label)
	# Складність — пігулкою поруч з назвою: червоніша для мега-босів.
	_difficulty_tag = PanelContainer.new()
	_difficulty_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_difficulty_tag)
	_difficulty_label = Label.new()
	_difficulty_label.add_theme_font_override("font", UiTheme.font(800))
	_difficulty_label.add_theme_font_size_override("font_size", 14)
	_difficulty_tag.add_child(_difficulty_label)

	_subtitle_label = _make_text(17, TEXT_COLOR)
	info.add_child(_subtitle_label)
	_enemies_label = _make_text(14, MUTED_COLOR)
	info.add_child(_enemies_label)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 24)
	info.add_child(stat_row)
	_boss_label = Label.new()
	_boss_label.add_theme_font_override("font", UiTheme.font(800))
	_boss_label.add_theme_font_size_override("font_size", 16)
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	_boss_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_boss_label.add_theme_constant_override("outline_size", 4)
	stat_row.add_child(_boss_label)
	# Золото за похід — монетою, як скрізь у грі.
	_gold_badge = CurrencyBadge.new(&"gold", 16, false)
	stat_row.add_child(_gold_badge)

	_lock_label = _make_text(15, Color(1.0, 0.75, 0.45))
	info.add_child(_lock_label)

	_next_button = _make_arrow_button(ARROW_RIGHT, "›")
	_next_button.pressed.connect(_on_step_pressed.bind(1))
	paging_row.add_child(_next_button)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 18)
	column.add_child(bottom_row)

	var close := Button.new()
	close.text = "Назад у місто"
	close.custom_minimum_size = Vector2(230, 50)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 18)
	UiTheme.art_secondary(close)
	close.pressed.connect(_on_close_pressed)
	bottom_row.add_child(close)

	_enter_button = Button.new()
	_enter_button.custom_minimum_size = Vector2(280, 56)
	_enter_button.add_theme_font_size_override("font_size", 20)
	UiTheme.art_primary(_enter_button)
	_enter_button.pressed.connect(_on_enter_pressed)
	bottom_row.add_child(_enter_button)

	_index = mini(GameState.max_dungeon_level, DungeonLevels.get_level_count() - 1)
	_refresh()
	UiTheme.scroll_to_center.call_deferred(_slot_scroll, _slot_buttons[_index])

func _make_text(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UiTheme.font(700))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("outline_size", 3)
	return label

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

## Стрілка — плашка гравця (тягнеться лише вздовж) із шевроном по центру.
## Немає картинок — проста кнопка теми зі значком ‹ ›.
func _make_arrow_button(chevron_path: String, glyph: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(ARROW_WIDTH, 0)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	if not ResourceLoader.exists(ARROW_FRAME) or not ResourceLoader.exists(chevron_path):
		button.text = glyph
		button.add_theme_font_size_override("font_size", 34)
		return button
	# Плашка рівно ARROW_WIDTH завширшки — вшир не тягнеться (поля по
	# половині), вздовж тягнеться лише середина між кутами з рунами.
	UiTheme.art_button(button, ARROW_FRAME, int(ARROW_WIDTH * 0.5) - 1, 22)
	button.icon = load(chevron_path)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box := button.get_theme_stylebox(state) as StyleBoxTexture
		if box != null:
			box.content_margin_left = 0
			box.content_margin_right = 0
	return button

func _refresh() -> void:
	var level := DungeonLevels.get_level(_index)
	var accent: Color = level.theme.torch
	var unlocked_up_to := GameState.get_unlocked_dungeon_level()
	var unlocked := _index <= unlocked_up_to
	var cleared := _index < GameState.max_dungeon_level

	for index in _slot_buttons.size():
		var other := DungeonLevels.get_level(index)
		var other_accent: Color = other.theme.torch
		UiTheme.style_picker_slot(_slot_buttons[index], index == _index, index <= unlocked_up_to, other_accent)
		_slot_buttons[index].button_pressed = index == _index

	_prev_button.disabled = _index <= 0
	_next_button.disabled = _index >= DungeonLevels.get_level_count() - 1

	var art := ArtSlots.dungeon_icon(level.id)
	_art_display.visible = art != null
	_art_display.texture = art
	_art_display.modulate = Color.WHITE if unlocked else Color(0.45, 0.45, 0.5)

	_name_label.text = "Рівень %d. %s" % [_index + 1, level.title]
	_name_label.add_theme_color_override("font_color", accent.lerp(TITLE_COLOR, 0.55) if unlocked else Color(0.62, 0.62, 0.7))
	var difficulty: int = clampi(level.difficulty, 1, DIFFICULTY_TITLES.size() - 1)
	var title: String = DIFFICULTY_TITLES[difficulty]
	var tag_color := Color(1.0, 0.4, 0.35) if title.begins_with("Мега-бос") else UiTheme.GOLD
	_difficulty_label.text = title
	_difficulty_label.add_theme_color_override("font_color", tag_color.lerp(Color.WHITE, 0.35))
	var tag_box := UiTheme.make_box(Color(tag_color, 0.18), 9, 1, Color(tag_color, 0.75))
	tag_box.content_margin_left = 10
	tag_box.content_margin_right = 10
	tag_box.content_margin_top = 1
	tag_box.content_margin_bottom = 2
	_difficulty_tag.add_theme_stylebox_override("panel", tag_box)
	_subtitle_label.text = level.subtitle
	# На рівнях мега-босів звичайних ворогів немає — порожнє "Вороги:" ховаємо.
	var enemies := DungeonLevels.get_enemy_names(_index)
	_enemies_label.visible = not enemies.is_empty()
	_enemies_label.text = "Вороги: %s" % ", ".join(enemies)
	_boss_label.text = "Бос: %s" % level.boss.name
	_gold_badge.set_text("×%.1f золота" % float(level.stats.gold))

	if unlocked:
		_lock_label.visible = false
	else:
		_lock_label.visible = true
		var previous := DungeonLevels.get_level(_index - 1)
		_lock_label.text = "Закрито: спершу пройди «%s»" % previous.title

	if not unlocked:
		_enter_button.text = "Закрито"
		_enter_button.disabled = true
	elif cleared:
		_enter_button.text = "Пройдено — ще раз"
		_enter_button.disabled = false
	else:
		_enter_button.text = "Увійти"
		_enter_button.disabled = false

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
