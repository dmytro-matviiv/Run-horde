extends Control

## ДЕРЕВО ТАЛАНТІВ (Храм талантів у Мудреця). Павутина, як в Enshrouded:
## посередині рунічне коло з вільними очками, від нього — п'ять гілок
## (Мечник, Танк, Друїд, Лучник, Маг). Вузли:
##   малі кружки — характеристики; медальйони — помітні пасивки;
##   медальйони прийомів — нові кнопки в бою; великі золоті — ключові.
## Вивчене світиться кольором гілки, доступне — пульсує, закрите —
## темне. Лінії між вивченими — золоті.
## Тягни пальцем — рух, колесо/кнопки ± — масштаб. Натиск на вузол —
## опис і "Вивчити".

const RING_STEP := 118.0
const RING_START := 190.0
const NODE_SIZES := {"stat": 58.0, "notable": 78.0, "active": 82.0, "keystone": 100.0}
const WEB_SIZE := Vector2(2000, 2000)
const STAT_ICONS := {"hp": "stat_hp", "armor": "stat_armor", "damage": "stat_damage", "attack_speed": "stat_attack_speed",
	"crit": "stat_crit", "move_speed": "stat_speed", "mana": "boon_potion", "mana_regen": "boon_potion",
	"cooldown": "skill_rune_charge", "regen": "res_herb", "damage_reduction": "stat_armor"}

var _web: Control
var _buttons := {}
var _points_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _reset_button: Button
var _zoom := 0.62
var _dragging := false
var _drag_moved := 0.0
var _time := 0.0
var _hub_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.add_background(self, [UiTheme.BG_TALENTS], 0.82)
	clip_contents = true
	# М'яке світло рун з-під центру — дерево "росте" з нього.
	var glow := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.25, 0.75, 0.62, 0.22))
	gradient.set_color(1, Color(0, 0, 0, 0))
	var ramp := GradientTexture2D.new()
	ramp.gradient = gradient
	ramp.fill = GradientTexture2D.FILL_RADIAL
	ramp.fill_from = Vector2(0.5, 0.5)
	ramp.fill_to = Vector2(1.0, 0.5)
	glow.texture = ramp
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	_web = Control.new()
	_web.size = WEB_SIZE
	_web.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_web.draw.connect(_draw_links)
	add_child(_web)
	_build_hub()
	for id: String in TalentTree.nodes():
		_build_node(TalentTree.nodes()[id])
	_build_branch_titles()

	# --- верх: назад, стрічка, рівень і очки ---
	var title := OrnateBanner.new("Храм талантів", 26)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -210.0
	title.offset_right = 210.0
	title.offset_top = 2.0
	title.offset_bottom = 86.0
	add_child(title)
	var back := TextureButton.new()
	back.texture_normal = load(UiTheme.KIT_DIR + "btn_back.png")
	back.ignore_texture_size = true
	back.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back.size = Vector2(58, 58)
	back.position = Vector2(18, 14)
	back.pressed.connect(func() -> void: GameState.return_from_ui())
	add_child(back)

	var panel := OrnatePanel.new()
	panel.position = Vector2(14, 84)
	panel.custom_minimum_size = Vector2(250, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	_level_label = Label.new()
	_level_label.add_theme_font_override("font", UiTheme.font(900))
	_level_label.add_theme_font_size_override("font_size", 22)
	_level_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	column.add_child(_level_label)
	_xp_bar = UiTheme.make_bar(UiTheme.RUNE, Vector2(200, 14))
	column.add_child(_xp_bar)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 17)
	_points_label.add_theme_color_override("font_color", UiTheme.RUNE)
	column.add_child(_points_label)
	_reset_button = Button.new()
	_reset_button.custom_minimum_size = Vector2(200, 44)
	_reset_button.add_theme_font_size_override("font_size", 15)
	UiTheme.jelly(_reset_button, "red")
	_reset_button.pressed.connect(_on_reset)
	column.add_child(_reset_button)

	# Масштаб.
	var zoom_box := VBoxContainer.new()
	zoom_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	zoom_box.offset_left = -76.0
	zoom_box.offset_top = -150.0
	zoom_box.offset_right = -16.0
	zoom_box.offset_bottom = -16.0
	add_child(zoom_box)
	for step: Array in [["+", 1.15], ["−", 1.0 / 1.15]]:
		var button := Button.new()
		button.text = step[0]
		button.custom_minimum_size = Vector2(60, 60)
		button.add_theme_font_size_override("font_size", 30)
		UiTheme.jelly(button, "blue")
		button.pressed.connect(_set_zoom.bind(step[1]))
		zoom_box.add_child(button)

	GameState.talents_changed.connect(_refresh)
	resized.connect(_center_web)
	_center_web()
	_refresh()

func _exit_tree() -> void:
	if GameState.talents_changed.is_connected(_refresh):
		GameState.talents_changed.disconnect(_refresh)

func _center_web() -> void:
	_web.scale = Vector2.ONE * _zoom
	_web.position = size * 0.5 - WEB_SIZE * 0.5 * _zoom + Vector2(60, 30)

func _set_zoom(factor: float) -> void:
	var center := size * 0.5
	var before := (center - _web.position) / _zoom
	_zoom = clampf(_zoom * factor, 0.45, 1.6)
	_web.scale = Vector2.ONE * _zoom
	_web.position = center - before * _zoom

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_set_zoom(1.1)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_set_zoom(1.0 / 1.1)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			_drag_moved = 0.0
	elif event is InputEventMouseMotion and _dragging:
		_web.position += (event as InputEventMouseMotion).relative
		_drag_moved += (event as InputEventMouseMotion).relative.length()
	elif event is InputEventScreenDrag:
		_web.position += (event as InputEventScreenDrag).relative
	elif event is InputEventMagnifyGesture:
		_set_zoom((event as InputEventMagnifyGesture).factor)

static func position_of(node: Dictionary) -> Vector2:
	var radius := RING_START + RING_STEP * (int(node.ring) - 1)
	var angle := deg_to_rad(float(node.angle))
	return WEB_SIZE * 0.5 + Vector2(cos(angle), sin(angle)) * radius

func _build_hub() -> void:
	var hub := TextureRect.new()
	hub.texture = load(UiTheme.KIT_DIR + "rune_circle.png")
	hub.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hub.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hub.size = Vector2(230, 120)
	hub.position = WEB_SIZE * 0.5 - hub.size * 0.5
	hub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_web.add_child(hub)
	# Посеред кола — скільки очок можна вкласти.
	_hub_label = Label.new()
	_hub_label.add_theme_font_override("font", UiTheme.font(900))
	_hub_label.add_theme_font_size_override("font_size", 52)
	_hub_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_hub_label.add_theme_constant_override("outline_size", 10)
	_hub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hub_label.size = Vector2(160, 80)
	_hub_label.position = WEB_SIZE * 0.5 - _hub_label.size * 0.5
	_hub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_web.add_child(_hub_label)

func _build_branch_titles() -> void:
	for branch: String in TalentTree.BRANCHES:
		var info: Dictionary = TalentTree.BRANCHES[branch]
		var angle := deg_to_rad(float(info.angle))
		var label := Label.new()
		label.text = info.title
		label.add_theme_font_override("font", UiTheme.font(900))
		label.add_theme_font_size_override("font_size", 30)
		label.add_theme_color_override("font_color", info.color)
		label.add_theme_constant_override("outline_size", 9)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(240, 44)
		var radius := RING_START + RING_STEP * 6.0 + 120.0
		label.position = WEB_SIZE * 0.5 + Vector2(cos(angle), sin(angle)) * radius - label.size * 0.5
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_web.add_child(label)

func _icon_for(node: Dictionary) -> Texture2D:
	var own := ArtSlots.kit_icon("tal_" + String(node.id))
	if own != null:
		return own
	var effects: Dictionary = node.effects
	if effects.has("skill"):
		return ArtSlots.skill_icon(StringName(effects.skill))
	for key: String in effects:
		if STAT_ICONS.has(key):
			return ArtSlots.kit_icon(STAT_ICONS[key])
	return ArtSlots.kit_icon("stat_crit")

func _build_node(node: Dictionary) -> void:
	var side: float = NODE_SIZES.get(node.kind, 46.0)
	var button := TextureButton.new()
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.size = Vector2(side, side)
	button.position = position_of(node) - button.size * 0.5
	button.pivot_offset = button.size * 0.5
	button.tooltip_text = String(node.title)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	# Підкладка: кругла рамка (крім прийомів — у них медальйон свій).
	if node.kind != "active":
		var frame := TextureRect.new()
		frame.name = "Frame"
		frame.texture = load(UiTheme.KIT_DIR + "btn_round.png")
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(frame)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = _icon_for(node)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := 0.0 if node.kind == "active" or ArtSlots.kit_icon("tal_" + String(node.id)) != null else side * 0.22
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	button.pressed.connect(func() -> void:
		if _drag_moved < 12.0:
			_show_node(String(node.id)))
	_web.add_child(button)
	_buttons[node.id] = button

func _refresh() -> void:
	_level_label.text = "%s • рівень %d" % [String(GameState.character.get("name", "Герой")), GameState.hero_level]
	_xp_bar.max_value = GameState.xp_for(GameState.hero_level)
	_xp_bar.value = GameState.hero_xp
	_points_label.text = "Вільних очок: %d" % TalentTree.points_free()
	_hub_label.text = str(TalentTree.points_free())
	var cost := TalentTree.reset_cost()
	_reset_button.text = "Скинути все (безкоштовно)" if cost == 0 else "Скинути за %s золота" % UiTheme.format_amount(cost)
	_reset_button.disabled = GameState.talents.is_empty()
	for id: String in _buttons:
		var node := TalentTree.get_node(id)
		var button: Control = _buttons[id]
		var color: Color = TalentTree.BRANCHES[node.branch].color
		if TalentTree.is_learned(id):
			button.modulate = Color.WHITE
			button.self_modulate = Color.WHITE
		elif TalentTree.is_reachable(id):
			button.modulate = Color(0.85, 0.85, 0.85)
		else:
			button.modulate = Color(0.2, 0.19, 0.23)
		var frame := button.get_node_or_null("Frame") as TextureRect
		if frame != null:
			frame.modulate = color.lerp(Color.WHITE, 0.35) if TalentTree.is_learned(id) else Color.WHITE
	_web.queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	# Доступні до вивчення — пульсують (якщо є вільні очки).
	if TalentTree.points_free() <= 0:
		return
	var pulse := 1.0 + 0.06 * sin(_time * 5.0)
	for id: String in _buttons:
		var button: Control = _buttons[id]
		button.scale = Vector2.ONE * (pulse if TalentTree.can_learn(id) else 1.0)

func _draw_links() -> void:
	var center := WEB_SIZE * 0.5
	for id: String in _buttons:
		var node := TalentTree.get_node(id)
		var from := position_of(node)
		var parents: Array = node.parents
		var learned := TalentTree.is_learned(id)
		var color: Color = TalentTree.BRANCHES[node.branch].color
		if parents.is_empty():
			var to := center + (from - center).normalized() * 70.0
			_web.draw_line(from, to, Color(1.0, 0.84, 0.35) if learned else Color(color, 0.35), 5.0 if learned else 3.0, true)
		for parent: String in parents:
			var both := learned and TalentTree.is_learned(parent)
			_web.draw_line(from, position_of(TalentTree.get_node(parent)),
				Color(1.0, 0.84, 0.35) if both else Color(color, 0.3), 5.0 if both else 3.0, true)

func _show_node(id: String) -> void:
	var node := TalentTree.get_node(id)
	var branch: Dictionary = TalentTree.BRANCHES[node.branch]
	var kinds := {"stat": "Характеристика", "notable": "Пасивна риса", "active": "Новий прийом", "keystone": "Ключовий талант"}
	var dialog := OrnateDialog.new(String(node.title), _icon_for(node), branch.color, 560.0,
		"%s • %s" % [branch.title, kinds.get(node.kind, "")])
	dialog.add_text(String(node.text), 19)
	if node.kind == "keystone":
		dialog.add_text("Ключовий талант сильно міняє стиль бою — зваж плюси й мінуси.", 14, UiTheme.TEXT_DIM)
	if node.kind == "active":
		dialog.add_text("Кнопка прийому з'явиться в бою з будь-якою зброєю (до %d прийомів із дерева)." % TalentTree.MAX_TALENT_SKILLS, 14, UiTheme.TEXT_DIM)
	if TalentTree.is_learned(id):
		dialog.add_text("✔ Вивчено", 17, Color(0.5, 1.0, 0.5))
		dialog.add_button("Гаразд")
	elif TalentTree.can_learn(id):
		dialog.add_button("Вивчити (1 очко)", true, func() -> void:
			TalentTree.learn(id)
			dialog.close()
			_celebrate(id), 260.0)
		dialog.add_button("Ні", false)
	else:
		var reason := "Немає вільних очок — здобудь новий рівень." if TalentTree.points_free() <= 0 else "Спершу вивчи сусідній талант ближче до центру."
		dialog.add_text(reason, 15, Color(1.0, 0.6, 0.5))
		dialog.add_button("Гаразд")
	add_child(dialog)

## Вивчено: вузол спалахує і "підстрибує".
func _celebrate(id: String) -> void:
	var button: Control = _buttons[id]
	button.scale = Vector2.ONE * 1.4
	button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play(&"purchase", 0.0)

func _on_reset() -> void:
	var cost := TalentTree.reset_cost()
	var dialog := OrnateDialog.new("Скинути таланти?", null, UiTheme.DANGER, 520.0)
	dialog.add_text("Усі очки повернуться, і ти зможеш розподілити їх заново." +
		(" Перше скидання — безкоштовне." if cost == 0 else " Ціна: %s золота. Кожне наступне скидання — удвічі дорожче." % UiTheme.format_amount(cost)))
	dialog.add_button("Скинути", true, func() -> void:
		if not TalentTree.reset():
			dialog.add_text("Не вистачає золота.", 15, Color(1.0, 0.5, 0.45))
			return
		dialog.close())
	dialog.add_button("Ні", false)
	add_child(dialog)
