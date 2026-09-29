extends Control

## Зала героїв — та сама вітрина, що й зброя: гортаєш геройв іконками
## (ряд слотів), а не стрілками "вперед-назад". Обраний герой — велика
## 3D-модель посередині зі своєю зброєю в руці, нижче — опис, здібності
## й дія (обрати або купити).

const ABILITY_ICON_SCRIPT := preload("res://scenes/ui/ability_icon.gd")
const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")
const STAGE_GLOW_SCRIPT := preload("res://scenes/ui/stage_glow.gd")

var _index := 0
var _preview: ModelPreview
var _placeholder_label: Label
var _glow: Control

var _currency_label: Label
var _slot_row: HBoxContainer
var _slot_scroll: ScrollContainer
var _slot_buttons: Array[Button] = []
var _name_label: Label
var _description_label: Label
var _stats_label: Label
var _icons_row: HBoxContainer
var _action_button: Button

var _popup: Control
var _popup_title: Label
var _popup_text: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.078)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 28.0
	column.offset_top = 16.0
	column.offset_right = -28.0
	column.offset_bottom = -16.0
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var top_row := HBoxContainer.new()
	column.add_child(top_row)
	var title_box := UiTheme.make_title("Зала героїв", 30)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_box)
	_currency_label = Label.new()
	_currency_label.add_theme_font_size_override("font_size", 17)
	_currency_label.add_theme_color_override("font_color", UiTheme.GOLD)
	top_row.add_child(_currency_label)

	# Вітрина: 3D-модель героя зі спорядженою зброєю, з м'яким сяйвом під ногами.
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(0, 220)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", UiTheme.panel_box())
	column.add_child(stage)
	_glow = STAGE_GLOW_SCRIPT.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow)
	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_preview)
	_placeholder_label = Label.new()
	_placeholder_label.text = "Тимчасова модель — справжня буде пізніше"
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_placeholder_label.offset_top = -22.0
	_placeholder_label.add_theme_font_size_override("font_size", 13)
	_placeholder_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	stage.add_child(_placeholder_label)

	# Ряд слотів — героя гортаєш і обираєш іконками.
	var picker := UiTheme.make_picker_row()
	_slot_scroll = picker.scroll
	_slot_row = picker.row
	_slot_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_slot_scroll)
	for i in HeroPool.ALL_HEROES.size():
		var def := HeroPool.ALL_HEROES[i]
		# Портрета ще немає — щит-емблема; колір героя видно з рамки слота
		# (style_picker_slot фарбує її нижче, у _refresh).
		var texture := UiTheme.control_icon("shield")
		var slot := UiTheme.make_picker_slot(texture, Color.WHITE, 88.0)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)

	# Опис обраного героя — панель у рамці, як діалог квесту.
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UiTheme.panel_box())
	column.add_child(info_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info_panel.add_child(info)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 24)
	info.add_child(_name_label)

	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 15)
	_description_label.add_theme_color_override("font_color", UiTheme.TEXT)
	info.add_child(_description_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	info.add_child(_stats_label)

	_icons_row = HBoxContainer.new()
	_icons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_icons_row.add_theme_constant_override("separation", 22)
	info.add_child(_icons_row)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 16)
	column.add_child(bottom_row)

	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(170, 56)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back_pressed)
	bottom_row.add_child(back)

	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(260, 56)
	_action_button.add_theme_font_size_override("font_size", 20)
	_action_button.pressed.connect(_on_action_pressed)
	bottom_row.add_child(_action_button)

	_build_popup()

	_index = _find_index(GameState.selected_hero_id)
	_rebuild()
	UiTheme.scroll_to_center.call_deferred(_slot_scroll, _slot_buttons[_index])

func _build_popup() -> void:
	_popup = Control.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.visible = false
	add_child(_popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_popup_title = Label.new()
	_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_title.add_theme_font_size_override("font_size", 22)
	box.add_child(_popup_title)
	_popup_text = Label.new()
	_popup_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_text.add_theme_font_size_override("font_size", 16)
	_popup_text.add_theme_color_override("font_color", UiTheme.TEXT)
	box.add_child(_popup_text)
	var close := Button.new()
	close.text = "Зрозуміло"
	close.custom_minimum_size = Vector2(0, 46)
	UiTheme.make_primary(close)
	close.pressed.connect(func() -> void: _popup.visible = false)
	box.add_child(close)

func _find_index(hero_id: StringName) -> int:
	for i in HeroPool.ALL_HEROES.size():
		if HeroPool.ALL_HEROES[i].id == hero_id:
			return i
	return 0

func _current() -> HeroDef:
	return HeroPool.ALL_HEROES[_index]

func _on_slot_pressed(index: int) -> void:
	_index = index
	_rebuild()
	UiTheme.scroll_to_center(_slot_scroll, _slot_buttons[_index])

func _process(_delta: float) -> void:
	_glow.queue_redraw()

func _rebuild() -> void:
	var def := _current()
	_currency_label.text = "Золото: %d    Геми: %d" % [GameState.gold, GameState.gems]
	for i in _slot_buttons.size():
		var other := HeroPool.ALL_HEROES[i]
		var unlocked := GameState.is_hero_unlocked(other.id)
		UiTheme.style_picker_slot(_slot_buttons[i], i == _index, unlocked, other.color)
		_slot_buttons[i].button_pressed = i == _index

	_glow.set("glow_color", def.color)
	var weapon := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	_placeholder_label.visible = _preview.show_hero(def, weapon)

	_name_label.text = def.title
	_name_label.add_theme_color_override("font_color", def.color)
	_description_label.text = def.description
	var hp := int(Balance.HERO_MAX_HP + def.bonus_max_hp)
	var speed_percent := int(round(def.move_speed_percent * 100.0))
	_stats_label.text = "Здоров'я %d    Швидкість %+d%%    Зброя: %s" % [hp, speed_percent, weapon.title]

	for child in _icons_row.get_children():
		child.queue_free()
	for card: Dictionary in _cards_for(def):
		var holder := VBoxContainer.new()
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		holder.add_theme_constant_override("separation", 4)
		var icon: Button = ABILITY_ICON_SCRIPT.new()
		icon.setup(card.kind, card.color, card.title)
		icon.pressed.connect(_on_ability_pressed.bind(card))
		holder.add_child(icon)
		var label := Label.new()
		label.text = card.title
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", card.color)
		holder.add_child(label)
		_icons_row.add_child(holder)

	if GameState.selected_hero_id == def.id:
		_action_button.text = "Обрано"
		_action_button.disabled = true
		UiTheme.make_primary(_action_button)
	elif GameState.is_hero_unlocked(def.id):
		_action_button.text = "Обрати"
		_action_button.disabled = false
		UiTheme.make_primary(_action_button)
	elif def.gem_cost > 0:
		_action_button.text = "Купити за %d гемів" % def.gem_cost
		_action_button.disabled = GameState.gems < def.gem_cost
		_action_button.theme_type_variation = &""
	else:
		_action_button.text = "Купити за %d золота" % def.unlock_cost
		_action_button.disabled = GameState.gold < def.unlock_cost
		_action_button.theme_type_variation = &""

## Картки здібностей беремо з того, що герой СПРАВДІ вміє в бою
## (Skills3D), а не з окремого опису — тоді вітрина не бреше. Третьою
## йде картка про арсенал зброї.
func _cards_for(def: HeroDef) -> Array:
	var cards := []
	var equipped := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	for entry: Dictionary in Skills3D.describe(def, equipped):
		cards.append({
			"kind": &"talent" if entry.kind == &"passive" else &"blade",
			"color": entry.color,
			"title": entry.title,
			"text": entry.text,
		})
	var weapons := WeaponPool.get_for_hero(def.id)
	var lines := []
	for weapon: WeaponDef in weapons:
		lines.append("%s — %s" % [weapon.title, weapon.description])
	cards.append({
		"kind": &"weapon", "color": Color(1.0, 0.85, 0.4),
		"title": "Арсенал",
		"text": "\n".join(lines),
	})
	return cards

func _on_ability_pressed(card: Dictionary) -> void:
	_popup_title.text = card.title
	_popup_title.add_theme_color_override("font_color", card.color)
	_popup_text.text = card.text
	_popup.visible = true

func _on_action_pressed() -> void:
	var def := _current()
	if GameState.is_hero_unlocked(def.id):
		GameState.select_hero(def.id)
	elif def.gem_cost > 0:
		if GameState.unlock_hero_with_gems(def.id):
			AudioManager.play(&"purchase", 0.0)
			GameState.select_hero(def.id)
	elif GameState.unlock_hero(def.id):
		AudioManager.play(&"purchase", 0.0)
		GameState.select_hero(def.id)
	_rebuild()

func _on_back_pressed() -> void:
	# Назад — туди, звідки прийшли: у місто до дверей будівлі чи в меню.
	GameState.return_from_ui()
