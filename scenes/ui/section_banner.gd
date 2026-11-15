extends MarginContainer
class_name SectionBanner

## Підзаголовок розділу («Рунічна казка»): сливова плашка в золотому канті
## (UiTheme.inset_box) із золотим написом.

const HEIGHT := 46.0

var _box: StyleBox

func _init(text: String = "", font_size: int = 20) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = UiTheme.inset_box()
	custom_minimum_size = Vector2(0, HEIGHT)
	add_theme_constant_override("margin_left", 28)
	add_theme_constant_override("margin_right", 28)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiTheme.font(900))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiTheme.GOLD)
	label.add_theme_color_override("font_outline_color", UiTheme.OUTLINE)
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
