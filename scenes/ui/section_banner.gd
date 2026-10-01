extends MarginContainer
class_name SectionBanner

## Заголовок розділу (арт гравця): фіолетовий банер зі скошеними краями,
## руни-наконечники обабіч і по ромбику посередині згори й знизу.
## Полотно тягнеться 9-slice лише вшир (висота текстури = HEIGHT, тож
## наконечники не сплющує), а ромбики малюються окремо по центру — як
## частину рамки їх розтягнуло б. Немає файлів — плашка-пігулка теми.

const BODY_PATH := "res://assets/ui/theme/section_banner.png"
const GEM_TOP_PATH := "res://assets/ui/theme/section_banner_gem_top.png"
const GEM_BOTTOM_PATH := "res://assets/ui/theme/section_banner_gem_bottom.png"
const HEIGHT := 58.0
## Наконечник обабіч разом зі скосом.
const CAP := 24

var _box: StyleBox
var _gem_top: Texture2D
var _gem_bottom: Texture2D

func _init(text: String = "", font_size: int = 20) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BODY_PATH):
		var box := StyleBoxTexture.new()
		box.texture = load(BODY_PATH)
		box.texture_margin_left = CAP
		box.texture_margin_right = CAP
		box.texture_margin_top = HEIGHT * 0.5 - 1
		box.texture_margin_bottom = HEIGHT * 0.5 - 1
		_box = box
		custom_minimum_size = Vector2(0, HEIGHT)
	else:
		_box = UiTheme.panel_box()
	if ResourceLoader.exists(GEM_TOP_PATH):
		_gem_top = load(GEM_TOP_PATH)
	if ResourceLoader.exists(GEM_BOTTOM_PATH):
		_gem_bottom = load(GEM_BOTTOM_PATH)
	add_theme_constant_override("margin_left", CAP + 12)
	add_theme_constant_override("margin_right", CAP + 12)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiTheme.font(800))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.2, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	if _gem_top != null:
		draw_texture(_gem_top, Vector2(roundf((size.x - _gem_top.get_width()) * 0.5), 0.0))
	if _gem_bottom != null:
		draw_texture(_gem_bottom, Vector2(roundf((size.x - _gem_bottom.get_width()) * 0.5), size.y - _gem_bottom.get_height()))
