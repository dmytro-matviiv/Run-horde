extends Control

## Арсенал обраного героя — вітрина, як вибір героя: зброю гортаєш
## ІКОНКАМИ (ряд слотів, як інвентар у зразку Kenney), не читаючи
## список карток одну за одною. Вибір лише підсвічує слот і оновлює
## вітрину внизу; спорядити чи купити — окремою кнопкою, щоб дотик по
## слоту під час гортання нічого не спорядив випадково.

const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")

const ARCHETYPE_HINTS := {
	"projectile": "Постріл",
	"aoe_projectile": "Вибух по площі",
	"cone": "Конус полум'я",
	"melee_arc": "Ближній замах",
	"chain": "Ланцюг блискавки",
	"orbit_storm": "Вихор навколо себе",
	"ground_zone": "Зона на землі",
}

## Як б'є ближня зброя в 3D-бою — за її стилем. Для решти лишається
## назва архетипу вище.
const STYLE_HINTS := {
	"sword": "Меч — два замахи й удар ногою",
	"axe": "Сокира — круговий удар довкола себе",
	"glaive": "Тризуб — укол, що прошиває ряд ворогів",
	"twin_blades": "Парні клинки — кожен замах б'є двічі",
	"daggers": "Кинджали — швидкі уколи з вибухом довкола цілі",
	"cleaver": "Тесак — важкий удар, що оглушає",
}

## Чари посохів Чарівниці.
const SPELL_HINTS := {
	"arcane": "Посох — арканні стріли самі шукають ціль",
	"frost": "Посох — крига сповільнює, а третій уламок заморожує",
	"venom": "Посох — отруйна куля лишає хмару",
	"lightning": "Посох — блискавка перескакує між ворогами",
	"rune": "Книга — рунна печать під ворогом вибухає",
	"cards": "Карти — віяло карт прошиває ворогів",
}

const STATUS_HINTS := {
	&"poison": "отрута",
	&"burn": "підпал",
	&"slow": "сповільнення",
	&"mark": "мітка",
}

var _hero_id: StringName
var _weapons: Array[WeaponDef] = []
var _index := 0

var _preview: ModelPreview
var _preview_note: Label
var _currency_label: Label
var _slot_row: HBoxContainer
var _slot_scroll: ScrollContainer
var _slot_buttons: Array[Button] = []
var _name_label: Label
var _kind_label: Label
var _stats_label: Label
var _description_label: Label
var _action_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.078)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_hero_id = GameState.selected_hero_id
	_weapons = WeaponPool.get_for_hero(_hero_id)
	var equipped := GameState.get_equipped_weapon_id(_hero_id)
	_index = maxi(_weapons.map(func(w: WeaponDef) -> StringName: return w.id).find(equipped), 0)

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
	var title_box := UiTheme.make_title("Збройня", 30)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_box)
	_currency_label = Label.new()
	_currency_label.add_theme_font_size_override("font_size", 17)
	_currency_label.add_theme_color_override("font_color", UiTheme.GOLD)
	top_row.add_child(_currency_label)

	var hero_label := Label.new()
	hero_label.text = "Арсенал: %s" % HeroPool.get_def(_hero_id).title
	hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_label.add_theme_font_size_override("font_size", 16)
	hero_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	column.add_child(hero_label)

	# Вітрина: 3D-модель обраної зброї в руці героя — велика, посередині.
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(0, 200)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", UiTheme.panel_box())
	column.add_child(stage)
	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_preview)
	_preview_note = Label.new()
	_preview_note.text = "Тимчасова модель зброї — справжню підключимо пізніше"
	_preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_preview_note.offset_top = -22.0
	_preview_note.add_theme_font_size_override("font_size", 13)
	_preview_note.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	stage.add_child(_preview_note)

	# Ряд слотів — зброю гортаєш і обираєш іконками, як інвентар.
	var picker := UiTheme.make_picker_row()
	_slot_scroll = picker.scroll
	_slot_row = picker.row
	_slot_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_slot_scroll)
	for i in _weapons.size():
		var def := _weapons[i]
		var texture := ArtSlots.weapon_icon(def.id, def.icon)
		if texture == null:
			texture = ArtSlots.placeholder_icon(def.color, 96)
		var slot := UiTheme.make_picker_slot(texture, Color.WHITE, 88.0)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)

	# Опис обраної зброї — панель у рамці, як діалог квесту в зразку.
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UiTheme.panel_box())
	column.add_child(info_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info_panel.add_child(info)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 24)
	info.add_child(_name_label)

	_kind_label = Label.new()
	_kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kind_label.add_theme_font_size_override("font_size", 15)
	_kind_label.add_theme_color_override("font_color", UiTheme.GEM)
	info.add_child(_kind_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	info.add_child(_stats_label)

	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 15)
	_description_label.add_theme_color_override("font_color", UiTheme.TEXT)
	info.add_child(_description_label)

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
	bottom_row.add_child(_action_button)

	_refresh()
	UiTheme.scroll_to_center.call_deferred(_slot_scroll, _slot_buttons[_index])

func _current() -> WeaponDef:
	return _weapons[_index]

func _on_slot_pressed(index: int) -> void:
	_index = index
	_refresh()
	UiTheme.scroll_to_center(_slot_scroll, _slot_buttons[_index])

func _refresh() -> void:
	_currency_label.text = "Золото: %d    Геми: %d" % [GameState.gold, GameState.gems]
	var equipped := GameState.get_equipped_weapon_id(_hero_id)
	for i in _slot_buttons.size():
		var def := _weapons[i]
		UiTheme.style_picker_slot(_slot_buttons[i], i == _index, GameState.is_weapon_owned(def.id), def.color)
		_slot_buttons[i].button_pressed = i == _index

	var def := _current()
	var owned := GameState.is_weapon_owned(def.id)
	_preview_note.visible = _preview.show_weapon(def)
	_name_label.text = def.title
	_name_label.add_theme_color_override("font_color", def.color if owned else UiTheme.TEXT_DIM)
	_kind_label.text = SPELL_HINTS.get(def.spell, STYLE_HINTS.get(def.style_3d, ARCHETYPE_HINTS.get(def.archetype, "")))
	_stats_label.text = _build_stats_text(def)
	_description_label.text = def.description

	if _action_button.pressed.is_connected(_on_equip_pressed):
		_action_button.pressed.disconnect(_on_equip_pressed)
	if _action_button.pressed.is_connected(_on_buy_pressed):
		_action_button.pressed.disconnect(_on_buy_pressed)
	if equipped == def.id:
		_action_button.text = "У руках"
		_action_button.disabled = true
		UiTheme.make_primary(_action_button)
	elif owned:
		_action_button.text = "Спорядити"
		_action_button.disabled = false
		UiTheme.make_primary(_action_button)
		_action_button.pressed.connect(_on_equip_pressed)
	else:
		_action_button.text = "%d золота" % def.cost_gold
		_action_button.disabled = GameState.gold < def.cost_gold
		_action_button.theme_type_variation = &""
		_action_button.pressed.connect(_on_buy_pressed)

## Головні числа зброї людською мовою: скільки б'є, як часто і що
## лишає на ворогові. Для вогнепальної — ще магазин і перезарядка.
func _build_stats_text(def: WeaponDef) -> String:
	if def.ranged_3d:
		return "   •   ".join([
			"Шкода %d" % int(def.damage),
			"%.0f пострілів/с" % (1.0 / maxf(def.fire_interval, 0.01)),
			"магазин %d" % def.magazine,
			"перезарядка %.1f с" % def.reload_time,
		])
	if def.spell != "none":
		var parts: Array[String] = [
			"Шкода %d%%" % roundi(def.damage_mult_3d * 100.0),
			"чари раз на %.2f с" % def.cast_interval,
		]
		var staff_skill := Skills3D.create_skill(def.staff_skill)
		if staff_skill != null:
			parts.append("особливе: %s" % staff_skill.title)
		return "   •   ".join(parts)
	if STYLE_HINTS.has(def.style_3d):
		# Ближня зброя в 3D-бою відрізняється множниками до удару героя —
		# показуємо їх відносно стартового меча (100%).
		return "   •   ".join([
			"Шкода %d%%" % roundi(def.damage_mult_3d * 100.0),
			"швидкість %d%%" % roundi(def.speed_mult_3d * 100.0),
			"дальність %d%%" % roundi(def.reach_3d / 2.9 * 100.0),
			"дуга %d°" % roundi(def.arc_3d),
		])
	var parts: Array[String] = ["Шкода %d" % int(def.damage)]
	if def.cooldown > 0.0:
		parts.append("раз на %.1f с" % def.cooldown)
	if def.shots > 1:
		parts.append("%d снаряди" % def.shots)
	if def.pierce > 0:
		parts.append("пробиває %d" % def.pierce)
	if def.status != &"" and STATUS_HINTS.has(def.status):
		parts.append(STATUS_HINTS[def.status])
	return "   •   ".join(parts)

## Куплену зброю одразу вдягаємо — гравець хотів саме її, зайвий
## другий клік нічого не додає.
func _on_buy_pressed() -> void:
	var id := _current().id
	if GameState.buy_weapon(id):
		AudioManager.play(&"purchase", 0.0)
		GameState.equip_weapon(_hero_id, id)
	_refresh()

func _on_equip_pressed() -> void:
	GameState.equip_weapon(_hero_id, _current().id)
	_refresh()

func _on_back_pressed() -> void:
	# Назад — туди, звідки прийшли: у місто до дверей будівлі чи в меню.
	GameState.return_from_ui()
