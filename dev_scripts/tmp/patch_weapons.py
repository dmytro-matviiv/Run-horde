# -*- coding: utf-8 -*-
"""Разова правка scenes/ui/weapons.gd: Збройня в стилі Зали героїв."""
p = r"D:\Claude code\idle survivor_like\scenes\ui\weapons.gd"
s = open(p, encoding="utf-8").read()

start = s.index("func _ready() -> void:")
end = s.index("func _current() -> WeaponDef:")
NEW_READY = '''func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Тло — своє (armory.jpg), поки його немає — зала героїв зі статуями
	# лицарів. Суцільний фон зі сцени лягав би поверх картинки.
	($Background as CanvasItem).visible = false
	UiTheme.add_background(self, [ARMORY_BACKGROUND, HALL_BACKGROUND])

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
	top_row.add_theme_constant_override("separation", 10)
	column.add_child(top_row)
	var title_box := OrnateBanner.new("Збройня", 30)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_box)
	# Валюта — навпроти полотна банера, а не його герба: відступ згори.
	var wallet := MarginContainer.new()
	wallet.add_theme_constant_override("margin_top", int(OrnateBanner.CREST_RISE))
	top_row.add_child(wallet)
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 8)
	wallet.add_child(wallet_row)
	_gold_badge = CurrencyBadge.new(&"gold", 20)
	wallet_row.add_child(_gold_badge)
	_gems_badge = CurrencyBadge.new(&"gem", 20)
	wallet_row.add_child(_gems_badge)

	# Вітрина: зброя в руці героя на ЙОГО тлі (те саме, що в Залі героїв).
	# Мінімум невеликий: вітрина забирає все, що лишилось, — інакше на
	# висоті 648 низ екрана вилазив би.
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(0, 110)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", UiTheme.panel_box())
	stage.clip_contents = true
	column.add_child(stage)
	var sky: SkyStage = SKY_STAGE_SCRIPT.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(sky)
	sky.set_background(ArtSlots.hero_background(_hero_id))
	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_preview)
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(overlay)
	# Чий це арсенал — плашкою в кутку вітрини.
	var owner_tag := PanelContainer.new()
	owner_tag.add_theme_stylebox_override("panel", UiTheme.rune_frame_box())
	owner_tag.position = Vector2(10, 10)
	owner_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(owner_tag)
	var owner_label := Label.new()
	owner_label.text = "Арсенал: %s" % HeroPool.get_def(_hero_id).title
	owner_label.add_theme_font_override("font", UiTheme.font(800))
	owner_label.add_theme_font_size_override("font_size", 15)
	owner_label.add_theme_color_override("font_color", OrnateDialog.TITLE_COLOR)
	owner_tag.add_child(owner_label)
	_preview_note = Label.new()
	_preview_note.text = "Тимчасова модель зброї — справжню підключимо пізніше"
	_preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_preview_note.offset_top = -22.0
	_preview_note.add_theme_font_size_override("font_size", 13)
	_preview_note.add_theme_color_override("font_color", UiTheme.TEXT)
	_preview_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_preview_note.add_theme_constant_override("outline_size", 4)
	overlay.add_child(_preview_note)

	# Ряд слотів — зброю гортаєш і обираєш іконками, як інвентар.
	var picker := UiTheme.make_picker_row()
	_slot_scroll = picker.scroll
	_slot_row = picker.row
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

	# Опис і дії — в одному ряду, як у Залі героїв: ліворуч різьблена
	# панель опису, праворуч кнопки стовпчиком.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	column.add_child(bottom)
	var info_panel := OrnatePanel.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(info_panel)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	info_panel.add_child(info)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_override("font", UiTheme.font(900))
	_name_label.add_theme_font_size_override("font_size", 25)
	_name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.85))
	_name_label.add_theme_constant_override("outline_size", 6)
	info.add_child(_name_label)

	_kind_label = Label.new()
	_kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kind_label.add_theme_font_override("font", UiTheme.font(800))
	_kind_label.add_theme_font_size_override("font_size", 15)
	_kind_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	info.add_child(_kind_label)

	# Числа зброї — назва приглушена, значення своїм яскравим кольором.
	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.fit_content = true
	_stats_label.scroll_active = false
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.add_theme_font_override("normal_font", UiTheme.font(700))
	_stats_label.add_theme_font_override("bold_font", UiTheme.font(900))
	_stats_label.add_theme_font_size_override("normal_font_size", 15)
	_stats_label.add_theme_font_size_override("bold_font_size", 15)
	_stats_label.add_theme_color_override("default_color", Color(0.8, 0.78, 0.92))
	info.add_child(_stats_label)

	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_override("font", UiTheme.font(700))
	_description_label.add_theme_font_size_override("font_size", 16)
	_description_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	info.add_child(_description_label)

	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	bottom.add_child(actions)
	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(240, 56)
	_action_button.add_theme_font_size_override("font_size", 20)
	UiTheme.art_primary(_action_button)
	actions.add_child(_action_button)
	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(240, 48)
	back.add_theme_font_size_override("font_size", 18)
	UiTheme.art_secondary(back)
	back.pressed.connect(_on_back_pressed)
	actions.add_child(back)

	_refresh()
	UiTheme.scroll_to_center.call_deferred(_slot_scroll, _slot_buttons[_index])

'''
s = s[:start] + NEW_READY + s[end:]

reps = [
    ('''const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")
''', '''const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")
const SKY_STAGE_SCRIPT := preload("res://scenes/ui/sky_stage.gd")
## Тло Збройні: своє (поклади assets/ui/backgrounds/armory.jpg), інакше — зала.
const ARMORY_BACKGROUND := "res://assets/ui/backgrounds/armory.jpg"
const HALL_BACKGROUND := "res://assets/ui/backgrounds/hero_hall.jpg"
## Колір значень у рядку чисел зброї (bbcode, тому — hex).
const STAT_VALUE_COLOR := "#ffd36b"
'''),
    ('''var _stats_label: Label
''', '''var _stats_label: RichTextLabel
'''),
    ('''	_name_label.text = def.title
	_name_label.add_theme_color_override("font_color", def.color if owned else UiTheme.TEXT_DIM)
	_kind_label.text = SPELL_HINTS.get(def.spell, STYLE_HINTS.get(def.style_3d, ARCHETYPE_HINTS.get(def.archetype, "")))
	_stats_label.text = _build_stats_text(def)
''', '''	_name_label.text = def.title
	_name_label.add_theme_color_override("font_color", def.color.lerp(OrnateDialog.TITLE_COLOR, 0.6) if owned else Color(0.72, 0.72, 0.8))
	_kind_label.text = SPELL_HINTS.get(def.spell, STYLE_HINTS.get(def.style_3d, ARCHETYPE_HINTS.get(def.archetype, "")))
	_stats_label.text = "[center]%s[/center]" % _build_stats_text(def)
'''),
    ('''		UiTheme.make_primary(_action_button)
	elif owned:
		_action_button.text = "Спорядити"
		_action_button.disabled = false
		UiTheme.make_primary(_action_button)
		_action_button.pressed.connect(_on_equip_pressed)
	else:
		_action_button.disabled = GameState.gold < def.cost_gold
		_action_button.theme_type_variation = &""
		PriceTag.apply(_action_button, &"gold", def.cost_gold, "Купити")''', '''	elif owned:
		_action_button.text = "Спорядити"
		_action_button.disabled = false
		_action_button.pressed.connect(_on_equip_pressed)
	else:
		_action_button.disabled = GameState.gold < def.cost_gold
		PriceTag.apply(_action_button, &"gold", def.cost_gold, "Купити")'''),
]
for a, b in reps:
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)

# Числа зброї — з підсвіченими значеннями.
stat_start = s.index("## Головні числа зброї людською мовою")
stat_end = s.index("## Куплену зброю одразу вдягаємо")
NEW_STATS = '''## Головні числа зброї людською мовою: скільки б'є, як часто і що
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
	return "%s [b][color=%s]%s[/color][/b]" % [title, STAT_VALUE_COLOR, value]

'''
s = s[:stat_start] + NEW_STATS + s[stat_end:]
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
