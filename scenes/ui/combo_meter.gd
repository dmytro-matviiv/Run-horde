extends Control
class_name ComboMeter

## СЕРІЯ УДАРІВ. Кожен удар, що влучив, додає до серії; пропустив удар
## по собі або три секунди не бив нікого — серія згорає. На 10, 25 і 50
## ударах — нагорода (tier_reached: що саме дати, вирішує данж).
##
## Видно праворуч над бойовими кнопками, трохи нахилене, як у файтингах:
##   ранг серії — "Жорстко" -> "Нищівно" -> "Кривава лють" -> "БЕЗУМСТВО",
##     що вищий, то гарячіший колір; новий ранг — спалах і тремтіння;
##   велике число ударів (кожен удар — "стрибок" числа) і "ударів";
##   ромбики ланок комбо — котра ланка серії зараз (останній, більший, —
##     фініш); гаснуть, коли серія ланок урвалась;
##   смужка часу — скільки ще серія жива.

signal tier_reached(tier: int, title: String)

## Скільки секунд без влучання серія ще жива.
const WINDOW := 3.0
## Серію показуємо з цього числа — два-три удари ще не серія.
const SHOW_FROM := 3
const TIERS := [
	{"hits": 10, "title": "Серія!"},
	{"hits": 25, "title": "Нестримний!"},
	{"hits": 50, "title": "Непереможний!"},
]
## Ранги серії (лише вигляд, нагороди — TIERS).
const RANKS := [
	{"hits": 3, "title": "", "color": Color(1.0, 0.95, 0.85)},
	{"hits": 8, "title": "Жорстко", "color": Color(1.0, 0.78, 0.35)},
	{"hits": 18, "title": "Нищівно", "color": Color(1.0, 0.5, 0.2)},
	{"hits": 32, "title": "Кривава лють", "color": Color(1.0, 0.25, 0.2)},
	{"hits": 50, "title": "БЕЗУМСТВО", "color": Color(1.0, 0.3, 0.75)},
]
const TILT := -0.08
## Ромбики ланок: скільки секунд світяться після останньої ланки.
const PIPS_HOLD := 1.2
const PIP_OFF := Color(1.0, 1.0, 1.0, 0.18)
const PIP_ON := Color(1.0, 0.85, 0.4)
const PIP_FINISH := Color(1.0, 0.4, 0.2)

var _count := 0
var _left := 0.0
var _tier := 0
var _rank := 0
var _column: VBoxContainer
var _rank_label: Label
var _number: Label
var _caption: Label
var _bar: ProgressBar
var _pips: Control
var _pip_total := 0
var _pip_index := -1
var _pip_left := 0.0
var _pip_flash := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -260.0
	offset_right = -30.0
	offset_top = -240.0
	offset_bottom = -100.0
	_column = VBoxContainer.new()
	_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 2)
	_column.rotation = TILT
	_column.pivot_offset = Vector2(115, 70)
	add_child(_column)
	_rank_label = _make_label(22, RANKS[0].color)
	_column.add_child(_rank_label)
	_number = _make_label(54, RANKS[0].color)
	_column.add_child(_number)
	_caption = _make_label(15, Color(1, 1, 1, 0.75))
	_caption.text = "ударів"
	_column.add_child(_caption)
	_bar = UiTheme.make_bar(UiTheme.GOLD, Vector2(130, 5))
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.max_value = WINDOW
	_column.add_child(_bar)
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(150, 22)
	_pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.draw.connect(_draw_pips)
	_column.add_child(_pips)
	pivot_offset = Vector2(115, 70)
	_column.modulate.a = 0.0

func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.hud_text(label, size, color)
	label.add_theme_constant_override("outline_size", maxi(size / 6, 3))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.02, 0.9))
	return label

func add_hit() -> void:
	_count += 1
	_left = WINDOW
	if _count >= SHOW_FROM:
		_show_counter(true)
		_number.text = "%d" % _count
		# Кожен удар — "стрибок" числа.
		_number.pivot_offset = _number.size * 0.5
		_number.scale = Vector2.ONE * 1.25
		_number.create_tween().tween_property(_number, "scale", Vector2.ONE, 0.12)
	while _rank + 1 < RANKS.size() and _count >= int(RANKS[_rank + 1].hits):
		_rank += 1
		_rank_up()
	while _tier < TIERS.size() and _count >= int(TIERS[_tier].hits):
		_tier += 1
		tier_reached.emit(_tier, TIERS[_tier - 1].title)

## Ланка комбо героя почалась (index від 0 з total) — ромбики.
func set_combo_step(index: int, total: int) -> void:
	_pip_total = total
	_pip_index = index
	_pip_left = PIPS_HOLD
	_pip_flash = 1.0 if index == total - 1 else 0.4
	_pips.queue_redraw()

## Новий ранг: колір, назва, спалах і коротке тремтіння.
func _rank_up() -> void:
	var rank: Dictionary = RANKS[_rank]
	_rank_label.text = rank.title
	_rank_label.add_theme_color_override("font_color", rank.color)
	_number.add_theme_color_override("font_color", rank.color)
	_rank_label.pivot_offset = _rank_label.size * 0.5
	_rank_label.scale = Vector2.ONE * 1.6
	var tween := create_tween()
	tween.tween_property(_rank_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var shake := create_tween()
	for i in 6:
		shake.tween_property(_column, "position", Vector2(randf_range(-6, 6), randf_range(-4, 4)), 0.03)
	shake.tween_property(_column, "position", Vector2.ZERO, 0.04)

## Герой пропустив удар — серія згорає.
func reset() -> void:
	_count = 0
	_tier = 0
	_rank = 0
	_left = 0.0
	_rank_label.text = ""
	_rank_label.add_theme_color_override("font_color", RANKS[0].color)
	_number.add_theme_color_override("font_color", RANKS[0].color)
	_show_counter(false)

func get_count() -> int:
	return _count

var _shown := false

func _show_counter(shown: bool) -> void:
	if shown == _shown:
		return
	_shown = shown
	create_tween().tween_property(_column, "modulate:a", 1.0 if shown else 0.0, 0.15 if shown else 0.35)

func _process(delta: float) -> void:
	if _pip_left > 0.0:
		_pip_left -= delta
		_pip_flash = maxf(_pip_flash - delta * 2.5, 0.0)
		if _pip_left <= 0.0:
			_pip_index = -1
		_pips.queue_redraw()
	if _count == 0:
		return
	_left -= delta
	_bar.value = maxf(_left, 0.0)
	if _left <= 0.0:
		reset()

## Ромбики ланок: пройдені світяться, поточний — яскравіше, фініш — більший
## і червоно-помаранчевий.
func _draw_pips() -> void:
	if _pip_total <= 1:
		return
	var gap := 26.0
	var start := _pips.size.x * 0.5 - gap * (_pip_total - 1) * 0.5
	var fade := clampf(_pip_left / 0.4, 0.0, 1.0) if _pip_index >= 0 else 0.0
	for i in _pip_total:
		var finish := i == _pip_total - 1
		var radius := 9.0 if finish else 6.5
		var center := Vector2(start + gap * i, _pips.size.y * 0.5)
		var lit := _pip_index >= 0 and i <= _pip_index
		var color := PIP_OFF
		if lit:
			color = (PIP_FINISH if finish else PIP_ON)
			if i == _pip_index:
				radius += 2.5 * _pip_flash
				color = color.lerp(Color.WHITE, 0.5 * _pip_flash)
			color.a *= maxf(fade, 0.25)
		var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.8, 0),
			center + Vector2(0, radius), center + Vector2(-radius * 0.8, 0)])
		_pips.draw_colored_polygon(points, Color(0.1, 0.03, 0.02, 0.7 * maxf(fade, 0.3)) if not lit else color)
		if not lit:
			_pips.draw_polyline(points + PackedVector2Array([points[0]]), PIP_OFF, 1.5, true)
