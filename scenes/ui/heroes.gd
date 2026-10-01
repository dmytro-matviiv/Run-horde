extends Control

## Зала героїв — та сама вітрина, що й зброя: гортаєш геройв іконками
## (ряд слотів), а не стрілками "вперед-назад". Обраний герой — велика
## 3D-модель посередині зі своєю зброєю в руці, нижче — опис, здібності
## й дія (обрати або купити).

const ABILITY_ICON_SCRIPT := preload("res://scenes/ui/ability_icon.gd")
const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")
const STAGE_GLOW_SCRIPT := preload("res://scenes/ui/stage_glow.gd")
const SKY_STAGE_SCRIPT := preload("res://scenes/ui/sky_stage.gd")
## Скільки карток здібностей лягає зліва від вітрини — решта праворуч.
const LEFT_SLOT_COUNT := 2

var _index := 0
var _preview: ModelPreview
var _placeholder_label: Label
var _glow: Control
var _sky: SkyStage

var _gold_label: Label
var _gem_label: Label
var _slot_row: HBoxContainer
var _slot_scroll: ScrollContainer
var _slot_buttons: Array[Button] = []
var _name_label: Label
var _description_label: Label
var _stats_label: Label
var _left_slots: VBoxContainer
var _right_slots: VBoxContainer
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
	top_row.add_theme_constant_override("separation", 10)
	column.add_child(top_row)
	var title_box := UiTheme.make_title("Зала героїв", 30)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_box)
	_gold_label = Label.new()
	top_row.add_child(_currency_badge(UiTheme.GOLD, _gold_label))
	_gem_label = Label.new()
	top_row.add_child(_currency_badge(UiTheme.GEM, _gem_label))

	# Вітрина: герой стоїть просто неба, а обабіч — картки його прийомів
	# (як спорядження в зразку мобільної гри), а не рядком під описом.
	var stage_row := HBoxContainer.new()
	stage_row.custom_minimum_size = Vector2(0, 150)
	stage_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_row.add_theme_constant_override("separation", 10)
	column.add_child(stage_row)

	_left_slots = VBoxContainer.new()
	_left_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_left_slots.add_theme_constant_override("separation", 4)
	_left_slots.custom_minimum_size = Vector2(96, 0)
	stage_row.add_child(_left_slots)

	var stage := PanelContainer.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", UiTheme.panel_box())
	stage.clip_contents = true
	stage_row.add_child(stage)
	_sky = SKY_STAGE_SCRIPT.new()
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_sky)
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
	_placeholder_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_placeholder_label.add_theme_constant_override("outline_size", 4)
	stage.add_child(_placeholder_label)

	_right_slots = VBoxContainer.new()
	_right_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_right_slots.add_theme_constant_override("separation", 4)
	_right_slots.custom_minimum_size = Vector2(96, 0)
	stage_row.add_child(_right_slots)

	# Ряд слотів — героя гортаєш і обираєш іконками.
	var picker := UiTheme.make_picker_row()
	_slot_scroll = picker.scroll
	_slot_row = picker.row
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_slot_scroll)
	for i in HeroPool.ALL_HEROES.size():
		var def := HeroPool.ALL_HEROES[i]
		# Портрет героя на всю картку, якщо гравець його поклав; інакше —
		# щит-емблема. Колір героя — у кільці картки (style_picker_slot).
		var texture := ArtSlots.hero_portrait(def.id)
		var portrait := texture != null
		if not portrait:
			texture = UiTheme.control_icon("shield")
		var slot := UiTheme.make_picker_slot(texture, Color.WHITE, 88.0, portrait)
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
	_gold_label.text = str(GameState.gold)
	_gem_label.text = str(GameState.gems)
	for i in _slot_buttons.size():
		var other := HeroPool.ALL_HEROES[i]
		var unlocked := GameState.is_hero_unlocked(other.id)
		UiTheme.style_picker_slot(_slot_buttons[i], i == _index, unlocked, other.color)
		_slot_buttons[i].button_pressed = i == _index

	_glow.set("glow_color", def.color)
	_sky.set_background(ArtSlots.hero_background(def.id))
	var weapon := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	_placeholder_label.visible = _preview.show_hero(def, weapon)

	_name_label.text = def.title
	_name_label.add_theme_color_override("font_color", def.color)
	_description_label.text = def.description
	var hp := int(Balance.HERO_MAX_HP + def.bonus_max_hp)
	var speed_percent := int(round(def.move_speed_percent * 100.0))
	_stats_label.text = "Здоров'я %d    Швидкість %+d%%    Зброя: %s" % [hp, speed_percent, weapon.title]

	for child in _left_slots.get_children():
		child.queue_free()
	for child in _right_slots.get_children():
		child.queue_free()
	var cards := _cards_for(def)
	for i in cards.size():
		var card: Dictionary = cards[i]
		var target := _left_slots if i < LEFT_SLOT_COUNT else _right_slots
		target.add_child(_build_ability_slot(card))

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

## Кругла кольорова плашка золота чи гемів угорі — як бейджик валюти в
## мобільній грі, а не простий рядок тексту.
func _currency_badge(color: Color, value_label: Label) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.make_box(Color(color, 0.16), 14, 2, Color(color, 0.55)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	badge.add_child(row)
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", color)
	row.add_child(value_label)
	return badge

## Картка прийому обабіч вітрини — кольоровий квадратний слот (як
## спорядження в зразку), а не рядок іконок під описом; назва — під ним,
## щоб зрозуміло без наведення, що саме це за прийом.
func _build_ability_slot(card: Dictionary) -> VBoxContainer:
	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 4)
	# Своя іконка здібності (згенерований арт) — якщо гравець її поклав, без
	# рамки-слота (вона лише забруднює готову картинку), лише трохи більша;
	# інакше — та сама фігура кодом, що й раніше, на кольоровій підкладці.
	var own_icon := ArtSlots.skill_icon(card.get("id", &""))
	var icon: Button
	if own_icon != null:
		icon = Button.new()
		icon.custom_minimum_size = Vector2(80, 80)
		icon.icon = own_icon
		icon.expand_icon = true
		icon.flat = true
		icon.tooltip_text = card.title
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			icon.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		icon.pressed.connect(_on_ability_pressed.bind(card))
		holder.add_child(icon)
	else:
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", UiTheme.slot_box(card.color))
		slot.custom_minimum_size = Vector2(72, 72)
		slot.tooltip_text = card.title
		icon = ABILITY_ICON_SCRIPT.new()
		icon.setup(card.kind, card.color, card.title)
		icon.pressed.connect(_on_ability_pressed.bind(card))
		slot.add_child(icon)
		holder.add_child(slot)
	var label := Label.new()
	label.text = card.title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(84, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", card.color)
	holder.add_child(label)
	return holder

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
			"id": entry.id,
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
