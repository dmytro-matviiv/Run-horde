extends Control
class_name RunResults

## ПІДСУМКИ ПОХОДУ — табличка гравця після перемоги (зелена) чи поразки
## (червона). Табличка вилітає згори, далі цифри "набігають" від нуля, а
## шкали здібностей і зброї заповнюються по черзі.
##
## Що на ній (координати — у пікселях вихідного арту, ART_CROP):
##   стрічка згори        — "ПЕРЕМОГА!" / "ПОРАЗКА";
##   рамка зліва          — портрет героя, під ним уся шкода й золото;
##   довга плашка справа  — данж і скільки часу в ньому минуло;
##   три рядки справа     — дві здібності героя й зброя: іконка, назва,
##                          шкала й цифра шкоди;
##   кнопки внизу         — синя "додому" (головне меню), жовта з
##                          відео "×2 золота", зелена "далі": після перемоги —
##                          наступний данж, після поразки — цей самий ще раз
##                          (на ній тоді кругова стрілка замість "далі").
##
## Дані — словник (див. Dungeon._show_results):
##   victory, level_title, seconds, gold, total_damage, hero_id,
##   rows: [{title, icon, damage, color}] (дві здібності, потім зброя),
##   can_double.

signal home_pressed
signal next_pressed
signal double_pressed

const VICTORY_ART := preload("res://assets/ui/results/results_victory.png")
const DEFEAT_ART := preload("res://assets/ui/results/results_defeat.png")
## Яку частину вихідного арту (2000x1493) займає оброблена табличка.
const ART_CROP := Rect2(40, 70, 1925, 1345)
## Наскільки велика табличка на екрані: частка висоти й ширини.
const HEIGHT_SHARE := 0.92
const WIDTH_SHARE := 0.94

const RIBBON := Rect2(560, 112, 880, 120)
const PORTRAIT := Rect2(388, 388, 300, 304)
const TOTAL_BAR := Rect2(420, 800, 385, 104)
const GOLD_BAR := Rect2(420, 948, 385, 104)
const INFO_BOX := Rect2(910, 332, 852, 84)
const ROW_CENTERS := [555.0, 762.0, 969.0]
const SLOT_X := 958.0
const SLOT_SIZE := 124.0
const TRACK_X := 1150.0
const TRACK_WIDTH := 578.0
const TRACK_HEIGHT := 78.0
const HOME_BUTTON := Rect2(368, 1133, 244, 129)
const DOUBLE_BUTTON := Rect2(718, 1122, 564, 146)
const DOUBLE_TEXT := Rect2(868, 1140, 400, 110)
const TOWN_BUTTON := Rect2(1388, 1133, 244, 129)

const INK := Color(0.32, 0.12, 0.04)
const LIGHT := Color(1.0, 0.97, 0.9)
const NUMBER_GOLD := Color(1.0, 0.86, 0.4)
## Кругова стрілка "ще раз" на зеленій кнопці поразки.
const RETRY_GREEN := Color(0.4, 0.74, 0.13)
const RETRY_OUTLINE := Color(0.1, 0.28, 0.04)
const RETRY_ARROW := Color(1.0, 1.0, 0.94)
const COUNT_TIME := 1.0
const BAR_TIME := 0.4

var _data: Dictionary
var _panel: Control
var _scale := 1.0
var _gold_label: Label
var _double_label: Label
var _double_button: Button
var _buttons: Array[Button] = []
var _shown_gold := 0
var _double_done := false

func setup(data: Dictionary) -> void:
	_data = data

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var victory: bool = _data.get("victory", false)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.62 if victory else 0.72, 0.35)

	var view := get_viewport_rect().size
	var art_size := Vector2(VICTORY_ART.get_size())
	var height := minf(view.y * HEIGHT_SHARE, view.x * WIDTH_SHARE * art_size.y / art_size.x)
	var size := Vector2(height * art_size.x / art_size.y, height)
	_scale = size.x / ART_CROP.size.x
	_panel = Control.new()
	_panel.size = size
	_panel.pivot_offset = size * 0.5
	_panel.position = (view - size) * 0.5
	add_child(_panel)
	var art := TextureRect.new()
	art.texture = VICTORY_ART if victory else DEFEAT_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(art)

	_build_title(victory)
	_build_portrait()
	_build_info()
	var total_label := _build_side_number(TOTAL_BAR, "шкода")
	_gold_label = _build_side_number(GOLD_BAR, "золото")
	var rows: Array = _data.get("rows", [])
	var best := 1.0
	for row: Dictionary in rows:
		best = maxf(best, float(row.damage))
	var fills: Array = []
	var numbers: Array = []
	for i in mini(rows.size(), ROW_CENTERS.size()):
		var parts := _build_row(rows[i], ROW_CENTERS[i])
		fills.append(parts[0])
		numbers.append(parts[1])
	_build_buttons()
	_animate_in(victory, total_label, rows, best, fills, numbers)

# --- складові ---

## Прямокутник з координат арту — у координати таблички на екрані.
func _rect(source: Rect2) -> Rect2:
	return Rect2((source.position - ART_CROP.position) * _scale, source.size * _scale)

func _place(node: Control, source: Rect2) -> void:
	var rect := _rect(source)
	node.position = rect.position
	node.size = rect.size
	_panel.add_child(node)

func _label(text: String, size: float, color: Color, weight: int = 800, outline: int = 0,
		outline_color: Color = Color(0, 0, 0, 0.6)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiTheme.font(weight))
	label.add_theme_font_size_override("font_size", maxi(int(round(size * _scale)), 10))
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", outline_color)
		label.add_theme_constant_override("outline_size", outline)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	return label

func _build_title(victory: bool) -> void:
	var title := _label("ПЕРЕМОГА!" if victory else "ПОРАЗКА", 92.0, INK, 900, 4, Color(1.0, 0.93, 0.6, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = false
	_place(title, RIBBON)
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2.ZERO
	title.name = "Title"

func _build_portrait() -> void:
	var hero_id: StringName = _data.get("hero_id", &"")
	var texture := ArtSlots.hero_portrait(hero_id)
	if texture == null:
		return
	var holder := Control.new()
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(holder, PORTRAIT)
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.size = holder.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(picture)

func _build_info() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(row, INFO_BOX)
	var level := _label(String(_data.get("level_title", "")), 40.0, LIGHT, 800, 3)
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(level)
	var seconds := int(_data.get("seconds", 0))
	var time := _label("Час: %d:%02d" % [seconds / 60, seconds % 60], 40.0, NUMBER_GOLD, 900, 3)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time.clip_text = false
	row.add_child(time)
	var pad := Control.new()
	pad.custom_minimum_size.x = 18.0 * _scale
	row.add_child(pad)
	row.add_theme_constant_override("separation", 0)

## Плашка під портретом: підпис дрібно, число — велике, справа.
func _build_side_number(source: Rect2, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(row, source)
	var small := _label(caption, 30.0, Color(1, 1, 1, 0.7), 700, 2)
	row.add_child(small)
	var number := _label("0", 50.0, NUMBER_GOLD, 900, 4)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.clip_text = false
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(number)
	var pad := Control.new()
	pad.custom_minimum_size.x = 26.0 * _scale
	row.add_child(pad)
	return number

## Рядок справа: іконка в слоті, шкала з назвою й числом.
func _build_row(row: Dictionary, center_y: float) -> Array:
	var icon := TextureRect.new()
	icon.texture = row.get("icon")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(icon, Rect2(SLOT_X, center_y - SLOT_SIZE * 0.5, SLOT_SIZE, SLOT_SIZE))

	var track := Rect2(TRACK_X, center_y - TRACK_HEIGHT * 0.5, TRACK_WIDTH, TRACK_HEIGHT)
	var fill := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.76, 0.18)
	style.border_color = Color(1.0, 0.92, 0.55)
	style.set_border_width_all(0)
	style.border_width_top = maxi(int(6.0 * _scale), 2)
	style.set_corner_radius_all(int(TRACK_HEIGHT * 0.5 * _scale))
	style.shadow_color = Color(0.45, 0.2, 0.0, 0.45)
	style.shadow_size = 0
	style.anti_aliasing = true
	fill.add_theme_stylebox_override("panel", style)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(fill, track)
	fill.set_meta("full", fill.size.x)
	fill.size.x = 0.0
	fill.visible = false

	var labels := HBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(labels, track)
	var pad := Control.new()
	pad.custom_minimum_size.x = 26.0 * _scale
	labels.add_child(pad)
	var title := _label(String(row.get("title", "")), 34.0, LIGHT, 800, 4, Color(0.18, 0.06, 0.1, 0.9))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(title)
	var number := _label("0", 38.0, LIGHT, 900, 4, Color(0.18, 0.06, 0.1, 0.9))
	number.clip_text = false
	labels.add_child(number)
	var pad_right := Control.new()
	pad_right.custom_minimum_size.x = 26.0 * _scale
	labels.add_child(pad_right)
	return [fill, number]

func _build_buttons() -> void:
	var home := _invisible_button(HOME_BUTTON)
	home.pressed.connect(func() -> void: home_pressed.emit())
	if not _data.get("victory", false):
		_build_retry_icon()
	var next := _invisible_button(TOWN_BUTTON)
	next.pressed.connect(func() -> void: next_pressed.emit())
	_double_button = _invisible_button(DOUBLE_BUTTON)
	_double_button.pressed.connect(func() -> void:
		_double_button.disabled = true
		double_pressed.emit())
	_double_label = _label("×2 золота за відео", 40.0, INK, 900, 3, Color(1.0, 0.95, 0.7, 0.8))
	_double_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_double_label, DOUBLE_TEXT)
	if not _data.get("can_double", true):
		set_double_done(false)

## Поразка: на зеленій кнопці замість стрілки "далі" — кругова стрілка
## "ще раз" (намальована поверх арту, на латці кольору кнопки).
func _build_retry_icon() -> void:
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(icon, Rect2(TOWN_BUTTON.position + TOWN_BUTTON.size * Vector2(0.22, 0.17), TOWN_BUTTON.size * Vector2(0.56, 0.62)))
	icon.draw.connect(func() -> void:
		var area := icon.size
		var patch := StyleBoxFlat.new()
		patch.bg_color = RETRY_GREEN
		patch.set_corner_radius_all(int(area.y * 0.3))
		icon.draw_style_box(patch, Rect2(Vector2.ZERO, area))
		var center := area * 0.5
		var radius := area.y * 0.3
		var width := area.y * 0.12
		var start := deg_to_rad(-50.0)
		var end := deg_to_rad(220.0)
		var head := _retry_head(center, radius, end, width)
		icon.draw_arc(center, radius, start, end, 24, RETRY_OUTLINE, width + area.y * 0.08, true)
		icon.draw_colored_polygon(_grow(head, area.y * 0.05), RETRY_OUTLINE)
		icon.draw_arc(center, radius, start, end, 24, RETRY_ARROW, width, true)
		icon.draw_colored_polygon(head, RETRY_ARROW))

## Вістря стрілки в кінці дуги (кут angle), дивиться вздовж руху.
static func _retry_head(center: Vector2, radius: float, angle: float, width: float) -> PackedVector2Array:
	var out := Vector2(cos(angle), sin(angle))
	var along := Vector2(-sin(angle), cos(angle))
	var base := center + out * radius
	return PackedVector2Array([base + out * width * 1.6, base + along * width * 2.0, base - out * width * 1.6])

## Трикутник трохи більший (обведення довкола вістря).
static func _grow(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var middle := (points[0] + points[1] + points[2]) / 3.0
	var out := PackedVector2Array()
	for point in points:
		out.append(point + (point - middle).normalized() * amount)
	return out

## Кнопка без власного вигляду поверх намальованої на арті: натиск —
## коротке "проваллення" всієї ділянки.
func _invisible_button(source: Rect2) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, empty)
	_place(button, source)
	button.pivot_offset = button.size * 0.5
	button.button_down.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE * 0.94, 0.06))
	button.button_up.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.1))
	button.disabled = true   # до кінця анімації — щоб не натиснути наосліп
	_buttons.append(button)
	return button

# --- живе оновлення ---

## Золото подвоєно (або подвоювати не можна): жовта кнопка гасне.
func set_double_done(granted: bool, new_gold: int = -1) -> void:
	_double_done = true
	_double_button.disabled = true
	_double_label.text = "Золото ×2 отримано" if granted else "×2 золота вже взято"
	_double_label.modulate = Color(1, 1, 1, 0.75)
	if new_gold >= 0:
		var from := _shown_gold
		var tween := create_tween()
		tween.tween_method(func(value: float) -> void:
			_shown_gold = int(value)
			_gold_label.text = UiTheme.format_amount(_shown_gold), float(from), float(new_gold), 0.8)
		var pulse := _gold_label.create_tween()
		_gold_label.pivot_offset = _gold_label.size * 0.5
		pulse.tween_property(_gold_label, "scale", Vector2.ONE * 1.25, 0.15)
		pulse.tween_property(_gold_label, "scale", Vector2.ONE, 0.25)

## Відео не додивились — кнопку можна натиснути знову.
func allow_double_again() -> void:
	if not _double_done:
		_double_button.disabled = false

# --- анімація ---

func _animate_in(victory: bool, total_label: Label, rows: Array, best: float, fills: Array, numbers: Array) -> void:
	var target := _panel.position
	_panel.position = target - Vector2(0, get_viewport_rect().size.y)
	_panel.rotation = deg_to_rad(-6.0 if victory else 7.0)
	_panel.scale = Vector2.ONE * 0.85
	var tween := create_tween()
	if victory:
		tween.tween_property(_panel, "position", target, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Поразка падає важко — з відскоком.
		tween.tween_property(_panel, "position", target, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_panel, "rotation", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var title: Label = _panel.get_node("Title")
	tween.tween_property(title, "scale", Vector2.ONE * 1.18, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(title, "scale", Vector2.ONE, 0.12)
	tween.tween_callback(func() -> void:
		if victory:
			_burst(_rect(RIBBON).get_center(), Color(1.0, 0.85, 0.35))
		AudioManager.play(&"gold" if victory else &"explosion", 0.1))

	# Числа набігають (уся шкода й золото) — одночасно зі шкалами.
	var total := float(_data.get("total_damage", 0.0))
	var gold := float(_data.get("gold", 0))
	tween.tween_callback(func() -> void:
		var count := create_tween()
		count.tween_method(func(value: float) -> void:
			total_label.text = UiTheme.format_amount(int(value * total))
			_shown_gold = int(value * gold)
			_gold_label.text = UiTheme.format_amount(_shown_gold), 0.0, 1.0, COUNT_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC))

	# Шкали — по черзі, кожна зі своїм числом.
	for i in fills.size():
		var fill: Panel = fills[i]
		var number: Label = numbers[i]
		var damage := float(rows[i].damage)
		var full: float = fill.get_meta("full")
		var share := clampf(damage / best, 0.0, 1.0)
		var min_width := fill.size.y   # повна заокругленість навіть у малої шкали
		tween.tween_callback(func() -> void:
			fill.size.x = min_width
			fill.visible = damage > 0.0)
		tween.tween_method(func(value: float) -> void:
			fill.size.x = lerpf(min_width, maxf(full * share, min_width), value)
			number.text = UiTheme.format_amount(int(value * damage)), 0.0, 1.0, BAR_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	tween.tween_callback(func() -> void:
		for button in _buttons:
			if button != _double_button or not _double_done:
				button.disabled = false)

## Іскри золота довкола стрічки (лише перемога).
func _burst(at: Vector2, color: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 40
	particles.lifetime = 1.1
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = _rect(RIBBON).size * 0.45
	particles.direction = Vector2.UP
	particles.spread = 80.0
	particles.initial_velocity_min = 120.0 * _scale * 2.0
	particles.initial_velocity_max = 320.0 * _scale * 2.0
	particles.gravity = Vector2(0, 520.0 * _scale * 2.0)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.85))
	gradient.set_color(1, Color(color, 0.0))
	particles.color_ramp = gradient
	particles.position = at
	_panel.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.5, true).timeout.connect(particles.queue_free)
