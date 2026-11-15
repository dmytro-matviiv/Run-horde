extends MarginContainer
class_name OrnateBanner

## Банер заголовка екрана («Рунічна казка»): золота стрічка з хвостами
## обабіч (UiTheme.ribbon_box), напис темно-коричневий зі світлою
## обвідкою. CREST_RISE — місце над стрічкою, яке давніше займав герб;
## лишилось, щоб сусіди (гаманець) вирівнювались так само.

const CREST_RISE := 6.0

var _box: StyleBox

func _init(text: String = "", font_size: int = 30) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = UiTheme.ribbon_box()
	custom_minimum_size = Vector2(0, 84)
	add_theme_constant_override("margin_left", 72)
	add_theme_constant_override("margin_right", 72)
	add_theme_constant_override("margin_top", int(CREST_RISE))
	add_theme_constant_override("margin_bottom", 40)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiTheme.font(900))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiTheme.RIBBON_TEXT)
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.93, 0.7, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_style_box(_box, Rect2(0.0, CREST_RISE, size.x, size.y - CREST_RISE))
