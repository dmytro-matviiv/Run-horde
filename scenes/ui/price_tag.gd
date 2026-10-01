extends CenterContainer
class_name PriceTag

## Ціна на кнопці: "Купити 500" і іконка валюти одразу за числом.
## Вбудована іконка кнопки (Button.icon) так не вміє: збоку вона тулиться
## до краю, далеко від числа, а по центру лягає під текст. Тому —
## окремий ряд посередині кнопки, а власний текст кнопки на цей час
## порожній. Кольори й шрифт беремо з самої кнопки — і вимкнена кнопка
## ("не вистачає гемів") притемнює ціну так само, як звичайний напис.
##
##   PriceTag.apply(button, &"gem", 500, "Купити")
##   PriceTag.clear(button)  # кнопка знову показує свій button.text

const NODE_NAME := &"PriceTag"

var _button: Button
var _label: Label
var _icon: TextureRect
## Стан кнопки, під який уже підібрано колір (вимкнена + варіант теми):
## щоб не переставляти те саме на кожне перемальовування.
var _shown_state := ""

static func apply(button: Button, kind: StringName, amount: int, prefix: String = "") -> void:
	var tag := button.get_node_or_null(NodePath(NODE_NAME)) as PriceTag
	if tag == null:
		tag = PriceTag.new()
		tag._attach(button)
	tag.visible = true
	button.text = ""
	tag._label.text = (prefix + " " if prefix != "" else "") + UiTheme.format_amount(amount)
	tag._icon.texture = ArtSlots.currency_icon(kind)
	tag._shown_state = ""
	tag._sync()

## Прибрати ціну — далі кнопка знову показує свій button.text.
static func clear(button: Button) -> void:
	var tag := button.get_node_or_null(NodePath(NODE_NAME))
	if tag != null:
		tag.visible = false

func _attach(button: Button) -> void:
	_button = button
	name = NODE_NAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	button.add_child(self)
	# Вимкнення кнопки перемальовує її — тоді й підтягуємо колір. Відкладено:
	# міняти вигляд дочірніх вузлів посеред малювання кнопки не можна.
	button.draw.connect(_sync, CONNECT_DEFERRED)

## Шрифт, розмір і колір — з кнопки (звичайний чи вимкнений стан).
func _sync() -> void:
	if not is_instance_valid(_button) or not visible:
		return
	var disabled := _button.disabled
	var state := "%s|%s" % [disabled, _button.theme_type_variation]
	if state == _shown_state:
		return
	_shown_state = state
	var font_size := _button.get_theme_font_size("font_size")
	_label.add_theme_font_override("font", _button.get_theme_font("font"))
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", _button.get_theme_color("font_disabled_color" if disabled else "font_color"))
	_label.add_theme_color_override("font_outline_color", _button.get_theme_color("font_outline_color"))
	_label.add_theme_constant_override("outline_size", _button.get_theme_constant("outline_size"))
	_icon.custom_minimum_size = Vector2.ONE * roundf(font_size * 1.35)
	_icon.modulate = Color(0.75, 0.75, 0.75, 0.8) if disabled else Color.WHITE
