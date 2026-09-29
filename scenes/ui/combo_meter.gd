extends Control
class_name ComboMeter

## СЕРІЯ УДАРІВ. Кожен удар, що влучив, додає до серії; пропустив удар
## по собі або три секунди не бив нікого — серія згорає. На 10, 25 і 50
## ударах — нагорода (tier_reached: що саме дати, вирішує данж). Серію
## видно праворуч над бойовими кнопками: велике "×12" й смужка часу.

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

var _count := 0
var _left := 0.0
var _tier := 0
var _number: Label
var _caption: Label
var _bar: ProgressBar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -250.0
	offset_right = -40.0
	offset_top = -210.0
	offset_bottom = -110.0
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	_number = Label.new()
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.hud_text(_number, 44, UiTheme.HEADING)
	column.add_child(_number)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.text = "серія"
	UiTheme.hud_text(_caption, 16)
	column.add_child(_caption)
	_bar = UiTheme.make_bar(UiTheme.GOLD, Vector2(120, 5))
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.max_value = WINDOW
	column.add_child(_bar)
	pivot_offset = Vector2(105, 50)
	visible = false

func add_hit() -> void:
	_count += 1
	_left = WINDOW
	if _count >= SHOW_FROM:
		visible = true
		_number.text = "×%d" % _count
		# Кожен удар — легкий "стрибок" числа.
		scale = Vector2.ONE * 1.15
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.12)
	while _tier < TIERS.size() and _count >= int(TIERS[_tier].hits):
		_tier += 1
		_number.add_theme_color_override("font_color", UiTheme.GOLD if _tier >= 2 else UiTheme.HEADING)
		tier_reached.emit(_tier, TIERS[_tier - 1].title)

## Герой пропустив удар — серія згорає.
func reset() -> void:
	_count = 0
	_tier = 0
	_left = 0.0
	visible = false
	_number.add_theme_color_override("font_color", UiTheme.HEADING)

func get_count() -> int:
	return _count

func _process(delta: float) -> void:
	if _count == 0:
		return
	_left -= delta
	_bar.value = maxf(_left, 0.0)
	if _left <= 0.0:
		reset()
