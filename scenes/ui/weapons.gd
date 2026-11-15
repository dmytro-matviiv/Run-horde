extends Control

## Арсенал обраного героя — вітрина, як вибір героя: зброю гортаєш
## ІКОНКАМИ (ряд слотів, як інвентар у зразку Kenney), не читаючи
## список карток одну за одною. Вибір лише підсвічує слот і оновлює
## вітрину внизу; спорядити чи купити — окремою кнопкою, щоб дотик по
## слоту під час гортання нічого не спорядив випадково.

const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")
## Тло Збройні: своє (поклади assets/ui/backgrounds/armory.jpg), інакше — зала.
const ARMORY_BACKGROUND := "res://assets/ui/kit/backgrounds/bg_armory.jpg"
const HALL_BACKGROUND := "res://assets/ui/kit/backgrounds/bg_heroes.jpg"
## Колір значень у рядку чисел зброї (bbcode, тому — hex).
const STAT_VALUE_COLOR := "#ffd36b"

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
var _backdrop_gradient: Gradient
var _preview_note: Label
var _gold_badge: CurrencyBadge
var _gems_badge: CurrencyBadge
var _slot_row: HBoxContainer
var _slot_scroll: ScrollContainer
var _slot_buttons: Array[Button] = []
var _name_label: Label
var _kind_label: Label
var _stats_label: RichTextLabel
var _description_label: Label
var _action_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Тло — своє (armory.jpg), поки його немає — зала героїв зі статуями
	# лицарів. Суцільний фон зі сцени лягав би поверх картинки.
	($Background as CanvasItem).visible = false
	UiTheme.add_background(self, [ARMORY_BACKGROUND, HALL_BACKGROUND])

	_hero_id = GameState.selected_hero_id
	_weapons = WeaponPool.get_for_hero(_hero_id)
	var equipped := GameState.get_equipped_weapon_id(_hero_id)
	_index = maxi(_weapons.map(func(w: WeaponDef) -> StringName: return w.id).find(equipped), 0)

	# --- зброя над постаментом посеред збройні ---
	add_child(_make_backdrop())
	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.anchor_left = 0.5
	_preview.anchor_right = 0.5
	_preview.anchor_top = 0.47
	_preview.anchor_bottom = 0.47
	_preview.offset_left = -250.0
	_preview.offset_right = 250.0
	_preview.offset_top = -150.0
	_preview.offset_bottom = 150.0
	add_child(_preview)
	_preview_note = Label.new()
	_preview_note.text = "Тимчасова модель зброї — справжню підключимо пізніше"
	_preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_preview_note.offset_top = 120.0
	_preview_note.offset_left = -250.0
	_preview_note.offset_right = 250.0
	_preview_note.add_theme_font_size_override("font_size", 13)
	add_child(_preview_note)

	# --- верх: назад, стрічка, гаманець ---
	var back := Button.new()
	back.icon = load(UiTheme.KIT_DIR + "btn_back.png")
	back.expand_icon = true
	back.flat = true
	back.custom_minimum_size = Vector2(58, 58)
	back.size = Vector2(58, 58)
	back.position = Vector2(18, 14)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	back.pressed.connect(_on_back_pressed)
	add_child(back)
	var title_box := OrnateBanner.new("Збройня", 28)
	title_box.anchor_left = 0.5
	title_box.anchor_right = 0.5
	title_box.offset_left = -200.0
	title_box.offset_right = 200.0
	title_box.offset_top = 2.0
	title_box.offset_bottom = 86.0
	add_child(title_box)
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 8)
	wallet_row.alignment = BoxContainer.ALIGNMENT_END
	wallet_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	wallet_row.offset_left = -330.0
	wallet_row.offset_right = -18.0
	wallet_row.offset_top = 20.0
	add_child(wallet_row)
	_gold_badge = CurrencyBadge.new(&"gold", 19)
	wallet_row.add_child(_gold_badge)
	_gems_badge = CurrencyBadge.new(&"gem", 19)
	wallet_row.add_child(_gems_badge)

	# --- ліворуч: опис зброї ---
	var info_panel := OrnatePanel.new()
	info_panel.position = Vector2(18, 92)
	info_panel.custom_minimum_size = Vector2(320, 0)
	add_child(info_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info_panel.add_child(info)
	var owner_label := Label.new()
	owner_label.text = "Арсенал: %s" % HeroPool.get_def(_hero_id).title
	owner_label.add_theme_font_size_override("font_size", 14)
	owner_label.add_theme_color_override("font_color", UiTheme.RUNE)
	info.add_child(owner_label)
	_name_label = Label.new()
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.custom_minimum_size = Vector2(240, 0)
	_name_label.add_theme_font_override("font", UiTheme.font(900))
	_name_label.add_theme_font_size_override("font_size", 26)
	_name_label.add_theme_constant_override("outline_size", 7)
	info.add_child(_name_label)
	_kind_label = Label.new()
	_kind_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_kind_label.add_theme_font_size_override("font_size", 15)
	_kind_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	info.add_child(_kind_label)
	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.fit_content = true
	_stats_label.scroll_active = false
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.custom_minimum_size = Vector2(240, 0)
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.add_theme_font_override("normal_font", UiTheme.font(800))
	_stats_label.add_theme_font_override("bold_font", UiTheme.font(900))
	_stats_label.add_theme_font_size_override("normal_font_size", 16)
	_stats_label.add_theme_font_size_override("bold_font_size", 16)
	info.add_child(_stats_label)
	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(240, 0)
	_description_label.add_theme_font_size_override("font_size", 14)
	_description_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	info.add_child(_description_label)

	# --- унизу: ряд зброї й головна дія ---
	var picker := UiTheme.make_picker_row()
	_slot_scroll = picker.scroll
	_slot_row = picker.row
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_scroll.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_slot_scroll.offset_left = -300.0
	_slot_scroll.offset_right = 300.0
	_slot_scroll.offset_top = -124.0
	_slot_scroll.offset_bottom = -12.0
	add_child(_slot_scroll)
	for i in _weapons.size():
		var def := _weapons[i]
		var texture := ArtSlots.weapon_icon(def.id, def.icon)
		if texture == null:
			texture = ArtSlots.placeholder_icon(def.color, 96)
		var slot := UiTheme.make_picker_slot(texture, Color.WHITE, 84.0)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)

	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(230, 58)
	_action_button.add_theme_font_size_override("font_size", 22)
	_action_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_button.offset_left = -248.0
	_action_button.offset_top = -78.0
	_action_button.offset_right = -18.0
	_action_button.offset_bottom = -20.0
	add_child(_action_button)

	# В'їзд частинами, як у Залі героїв.
	for k in 3:
		var node: Control = [info_panel, _slot_scroll, _action_button][k]
		var shift: Vector2 = [Vector2(-360, 0), Vector2(0, 160), Vector2(280, 0)][k]
		var home := node.position
		node.position = home + shift
		node.modulate.a = 0.0
		var tween := node.create_tween().set_parallel()
		tween.tween_property(node, "position", home, 0.45).set_delay(0.06 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "modulate:a", 1.0, 0.3).set_delay(0.06 * k)

	_refresh()
	UiTheme.scroll_to_center.call_deferred(_slot_scroll, _slot_buttons[_index])

## Підкладка під зброю: темний овал, а посередині — м'яке світло в кольорі
## зброї. Без неї темний ствол губився на темній кімнаті Оперативника, а
## світлий клинок — на світлому небі. Малюється кодом з однієї текстури.
func _make_backdrop() -> Control:
	_backdrop_gradient = Gradient.new()
	_backdrop_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_backdrop_gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = _backdrop_gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	var backdrop := Control.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.anchor_left = 0.5
	backdrop.anchor_right = 0.5
	backdrop.anchor_top = 0.47
	backdrop.anchor_bottom = 0.47
	backdrop.offset_left = -250.0
	backdrop.offset_right = 250.0
	backdrop.offset_top = -130.0
	backdrop.offset_bottom = 130.0
	backdrop.draw.connect(func() -> void:
		# Овал удвічі ширший за висоту — під зброю, що лежить по діагоналі.
		var height := backdrop.size.y * 1.15
		var rect := Rect2(backdrop.size * 0.5 - Vector2(height, height * 0.5), Vector2(height * 2.0, height))
		backdrop.draw_texture_rect(texture, rect, false))
	backdrop.resized.connect(backdrop.queue_redraw)
	return backdrop

func _current() -> WeaponDef:
	return _weapons[_index]

func _on_slot_pressed(index: int) -> void:
	_index = index
	_refresh()
	UiTheme.scroll_to_center(_slot_scroll, _slot_buttons[_index])

func _refresh() -> void:
	_gold_badge.set_amount(GameState.gold)
	_gems_badge.set_amount(GameState.gems)
	var equipped := GameState.get_equipped_weapon_id(_hero_id)
	for i in _slot_buttons.size():
		var def := _weapons[i]
		UiTheme.style_picker_slot(_slot_buttons[i], i == _index, GameState.is_weapon_owned(def.id), def.color)
		_slot_buttons[i].button_pressed = i == _index

	var def := _current()
	var owned := GameState.is_weapon_owned(def.id)
	_preview_note.visible = _preview.show_weapon(def)
	_backdrop_gradient.set_color(0, Color(def.color.lerp(Color.WHITE, 0.45), 0.6))
	_name_label.text = def.title
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45) if owned else Color(0.8, 0.78, 0.74))
	_name_label.pivot_offset = _name_label.size * 0.5
	_name_label.scale = Vector2.ONE * 0.88
	_name_label.create_tween().tween_property(_name_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_kind_label.text = SPELL_HINTS.get(def.spell, STYLE_HINTS.get(def.style_3d, ARCHETYPE_HINTS.get(def.archetype, "")))
	_stats_label.text = _build_stats_text(def).replace("    •    ", "\n")
	_description_label.text = def.description

	if _action_button.pressed.is_connected(_on_equip_pressed):
		_action_button.pressed.disconnect(_on_equip_pressed)
	if _action_button.pressed.is_connected(_on_buy_pressed):
		_action_button.pressed.disconnect(_on_buy_pressed)
	PriceTag.clear(_action_button)
	UiTheme.jelly(_action_button, "green" if owned else "gold")
	if equipped == def.id:
		_action_button.text = "У руках"
		_action_button.disabled = true
	elif owned:
		_action_button.text = "Спорядити"
		_action_button.disabled = false
		_action_button.pressed.connect(_on_equip_pressed)
	else:
		_action_button.disabled = GameState.gold < def.cost_gold
		PriceTag.apply(_action_button, &"gold", def.cost_gold, "Купити")
		_action_button.pressed.connect(_on_buy_pressed)

## Головні числа зброї людською мовою: скільки б'є, як часто і що
## лишає на ворогові. Для вогнепальної — ще магазин і перезарядка.
## BBCode: назва приглушена, значення — жирним золотом (_stat).
func _build_stats_text(def: WeaponDef) -> String:
	if def.ranged_3d:
		return "    •    ".join([
			_stat("Шкода", "%d" % int(def.damage)),
			_stat("Пострілів/с", "%.0f" % (1.0 / maxf(def.fire_interval, 0.01))),
			_stat("Магазин", "%d" % def.magazine),
			_stat("Перезарядка", "%.1f с" % def.reload_time),
		])
	if def.spell != "none":
		var parts: Array[String] = [
			_stat("Шкода", "%d%%" % roundi(def.damage_mult_3d * 100.0)),
			_stat("Чари раз на", "%.2f с" % def.cast_interval),
		]
		var staff_skill := Skills3D.create_skill(def.staff_skill)
		if staff_skill != null:
			parts.append(_stat("Особливе:", staff_skill.title))
		return "    •    ".join(parts)
	if STYLE_HINTS.has(def.style_3d):
		# Ближня зброя в 3D-бою відрізняється множниками до удару героя —
		# показуємо їх відносно стартового меча (100%).
		return "    •    ".join([
			_stat("Шкода", "%d%%" % roundi(def.damage_mult_3d * 100.0)),
			_stat("Швидкість", "%d%%" % roundi(def.speed_mult_3d * 100.0)),
			_stat("Дальність", "%d%%" % roundi(def.reach_3d / 2.9 * 100.0)),
			_stat("Дуга", "%d°" % roundi(def.arc_3d)),
		])
	var parts: Array[String] = [_stat("Шкода", "%d" % int(def.damage))]
	if def.cooldown > 0.0:
		parts.append(_stat("Раз на", "%.1f с" % def.cooldown))
	if def.shots > 1:
		parts.append(_stat("Снаряди", "%d" % def.shots))
	if def.pierce > 0:
		parts.append(_stat("Пробиває", "%d" % def.pierce))
	if def.status != &"" and STATUS_HINTS.has(def.status):
		parts.append("[b][color=%s]%s[/color][/b]" % [STAT_VALUE_COLOR, STATUS_HINTS[def.status]])
	return "    •    ".join(parts)

func _stat(title: String, value: String) -> String:
	return "%s  [b][color=%s]%s[/color][/b]" % [title, STAT_VALUE_COLOR, value]

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
