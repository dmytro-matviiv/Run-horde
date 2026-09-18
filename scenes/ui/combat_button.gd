extends Control
class_name CombatButton

## Кругла бойова кнопка для телефона.
##
## Звичайна Button тут не годиться: на телефоні вона реагує лише на
## ПЕРШИЙ палець. А гравець одночасно тримає джойстик лівим пальцем і
## б'є правим — тому кнопка сама слухає дотики з будь-яким номером
## пальця. Мишею на ПК теж натискається.
##
## Уміє показувати перезарядку: темний сектор, що зменшується, і секунди.

signal pressed_down
signal released

enum Icon {ATTACK, DODGE, SKILL}

var radius := 60.0
var icon: Icon = Icon.ATTACK
var caption := ""
var accent := Color(0.98, 0.72, 0.25)

## 0 — готово, 1 — щойно використано. Задає власник кнопки.
var cooldown_ratio := 0.0:
	set(value):
		if not is_equal_approx(value, cooldown_ratio):
			cooldown_ratio = value
			queue_redraw()
var cooldown_seconds := 0.0

var _touch_index := -1
var _down := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(radius * 2.0, radius * 2.0)
	custom_minimum_size = size
	pivot_offset = size * 0.5

## Кнопка кругла — і натискається лише в колі, а не в кутах квадрата.
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= radius * 1.12

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_press()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			_release()
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		# Телефон дублює перший дотик "мишею" — такі копії просто ковтаємо,
		# інакше кнопка спрацьовувала б двічі.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			accept_event()
			return
		var click := event as InputEventMouseButton
		if click.pressed and _touch_index == -1:
			_touch_index = -2
			_press()
		elif not click.pressed and _touch_index == -2:
			_touch_index = -1
			_release()
		accept_event()

## Гра стала на паузу (вибір здібності) — під час паузи кнопка не чує
## пальця, і відпускання загубилось би: герой після паузи бив би сам
## без упину. Тому на паузі кнопку "відпускаємо" примусово.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _down:
		_touch_index = -1
		_release()

func _press() -> void:
	_down = true
	scale = Vector2.ONE * 0.92
	queue_redraw()
	pressed_down.emit()

func _release() -> void:
	_down = false
	scale = Vector2.ONE
	queue_redraw()
	released.emit()

func _draw() -> void:
	var center := size * 0.5
	var is_ready := cooldown_ratio <= 0.0
	# Обідок — кільце з двох кіл, а не згладжена лінія: так кнопка
	# малюється однією командою разом із фоном (дешевше для телефона).
	draw_circle(center, radius, Color(accent, 0.95 if is_ready else 0.4))
	draw_circle(center, radius - 4.0, Color(0.05, 0.06, 0.09, 0.8 if not _down else 0.9))
	var glyph_color := Color(1, 1, 1, 0.95 if is_ready else 0.45)
	match icon:
		Icon.ATTACK:
			_draw_sword(center, radius * 0.5, glyph_color)
		Icon.DODGE:
			_draw_chevrons(center, radius * 0.42, glyph_color)
		Icon.SKILL:
			_draw_whirl(center, radius * 0.45, glyph_color)

	if not is_ready:
		# Темний сектор перезарядки: зменшується за годинниковою стрілкою.
		var points := PackedVector2Array([center])
		var steps := 32
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * cooldown_ratio * float(i) / steps
			points.append(center + Vector2(cos(angle), sin(angle)) * (radius - 3.0))
		draw_colored_polygon(points, Color(0, 0, 0, 0.55))
		var font := ThemeDB.fallback_font
		var text := "%.1f" % cooldown_seconds if cooldown_seconds < 3.0 else "%d" % ceili(cooldown_seconds)
		var font_size := int(radius * 0.5)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.35), text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

	if caption != "":
		var font := ThemeDB.fallback_font
		var caption_size := 15
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, caption_size).x
		draw_string(font, center + Vector2(-width * 0.5, radius + 18.0), caption,
			HORIZONTAL_ALIGNMENT_CENTER, -1, caption_size, Color(1, 1, 1, 0.9))

## Меч навскіс: лезо, гарда й руків'я.
func _draw_sword(center: Vector2, length: float, color: Color) -> void:
	var direction := Vector2(1, -1).normalized()
	var tip := center + direction * length
	var hilt := center - direction * length * 0.55
	var normal := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([
		tip, hilt + normal * length * 0.12, hilt - normal * length * 0.12]), color)
	draw_line(hilt + normal * length * 0.32, hilt - normal * length * 0.32, color, length * 0.12)
	draw_line(hilt, hilt - direction * length * 0.35, color, length * 0.1)

## Дві стрілки — ривок.
func _draw_chevrons(center: Vector2, size_px: float, color: Color) -> void:
	for offset: float in [-0.45, 0.35]:
		var base := center + Vector2(offset * size_px, 0)
		draw_polyline(PackedVector2Array([
			base + Vector2(-size_px * 0.35, -size_px * 0.6),
			base + Vector2(size_px * 0.35, 0),
			base + Vector2(-size_px * 0.35, size_px * 0.6)]), color, size_px * 0.22)

## Три дуги по колу — вихор.
func _draw_whirl(center: Vector2, size_px: float, color: Color) -> void:
	for i in 3:
		var start := TAU * i / 3.0
		draw_arc(center, size_px * (0.45 + 0.2 * i), start, start + PI * 0.9, 16, color, size_px * 0.16)
