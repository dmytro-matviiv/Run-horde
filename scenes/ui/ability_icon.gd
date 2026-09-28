extends Button
class_name AbilityIcon

## Іконка здібності на екрані героїв. Малюється кодом, а не картинкою:
## поки намальованих іконок немає, гравець усе одно бачить різні
## символи різного кольору, а не однакові сірі квадрати.

const SIZE := 64.0

var _kind: StringName = &"rune"
var _color := Color.WHITE

func setup(kind: StringName, color: Color, title: String) -> void:
	_kind = kind
	_color = color
	text = ""
	tooltip_text = title
	custom_minimum_size = Vector2(SIZE, SIZE)
	# Іконка кругла — прямокутна рамка кнопки з теми тут зайва.
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	# Підкладка кольору здібності, щоб іконка читалась як кнопка.
	draw_circle(center, radius + 5.0, Color(_color.r, _color.g, _color.b, 0.18))
	draw_arc(center, radius + 5.0, 0.0, TAU, 32, _color, 2.0)

	match _kind:
		&"rune":
			# Ромб із крапкою — магія.
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius), center + Vector2(radius * 0.7, 0),
				center + Vector2(0, radius), center + Vector2(-radius * 0.7, 0),
			]), _color)
			draw_circle(center, radius * 0.22, Color(1, 1, 1, 0.9))
		&"blade":
			# Клинок вістрям угору.
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius), center + Vector2(radius * 0.35, radius * 0.4),
				center + Vector2(0, radius * 0.2), center + Vector2(-radius * 0.35, radius * 0.4),
			]), _color)
			draw_line(center + Vector2(-radius * 0.5, radius * 0.45), center + Vector2(radius * 0.5, radius * 0.45), _color, 4.0)
		&"flame":
			# Язик полум'я.
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius), center + Vector2(radius * 0.6, radius * 0.1),
				center + Vector2(radius * 0.3, radius * 0.75), center + Vector2(-radius * 0.3, radius * 0.75),
				center + Vector2(-radius * 0.6, radius * 0.1),
			]), _color)
			draw_circle(center + Vector2(0, radius * 0.25), radius * 0.25, Color(1, 1, 0.8, 0.85))
		&"shadow":
			# Серп тіні: коло з вирізаним колом.
			draw_circle(center, radius, _color)
			draw_circle(center + Vector2(radius * 0.45, -radius * 0.25), radius * 0.85, Color(0.07, 0.07, 0.1))
		&"weapon":
			# Меч.
			draw_line(center + Vector2(0, radius * 0.8), center + Vector2(0, -radius * 0.9), _color, 5.0)
			draw_line(center + Vector2(-radius * 0.45, radius * 0.25), center + Vector2(radius * 0.45, radius * 0.25), _color, 4.0)
		_:
			# Зірка таланту.
			var points := PackedVector2Array()
			for i in 10:
				var angle := -PI / 2.0 + TAU / 10.0 * i
				var r := radius if i % 2 == 0 else radius * 0.45
				points.append(center + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(points, _color)
