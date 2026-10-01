extends MarginContainer
class_name OrnateBanner

## Банер заголовка екрана (арт гравця): фіолетове полотно з різьбленими
## наконечниками обабіч і гербом з короною над верхнім краєм. Полотно
## тягнеться 9-slice (наконечники не тягнуться), а герб малюється окремо,
## по центру: як частину рамки його розмазало б на широкому банері.
## Висота вузла включає місце під герб — він не вилазить за сусідів.
## Немає файлів — звичайна панель теми.

const BODY_PATH := "res://assets/ui/theme/banner_title.png"
const CREST_PATH := "res://assets/ui/theme/banner_title_crest.png"
## Наконечники обабіч — 64 px текстури, кант згори/знизу — 12.
const CAP := 64
const EDGE := 12
## На скільки герб піднімається над полотном.
const CREST_RISE := 18.0

var _box: StyleBox
var _crest: Texture2D

func _init(text: String = "", font_size: int = 30) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BODY_PATH):
		var box := StyleBoxTexture.new()
		box.texture = load(BODY_PATH)
		box.texture_margin_left = CAP
		box.texture_margin_right = CAP
		box.texture_margin_top = EDGE
		box.texture_margin_bottom = EDGE
		_box = box
	else:
		_box = UiTheme.panel_box()
	if ResourceLoader.exists(CREST_PATH):
		_crest = load(CREST_PATH)
	add_theme_constant_override("margin_left", CAP + 8)
	add_theme_constant_override("margin_right", CAP + 8)
	add_theme_constant_override("margin_top", int(CREST_RISE) + EDGE)
	add_theme_constant_override("margin_bottom", EDGE)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiTheme.font(700))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.2, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_style_box(_box, Rect2(0.0, CREST_RISE, size.x, size.y - CREST_RISE))
	if _crest != null:
		draw_texture(_crest, Vector2(roundf((size.x - _crest.get_width()) * 0.5), 0.0))
