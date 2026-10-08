extends Control
class_name CombatButton

## Кругла бойова кнопка для телефона.
##
## Звичайна Button тут не годиться: на телефоні вона реагує лише на
## ПЕРШИЙ палець. А гравець одночасно тримає джойстик лівим пальцем і
## б'є правим — тому кнопка сама слухає дотики з будь-яким номером
## пальця. Мишею на ПК теж натискається.
##
## Уміє показувати перезарядку (темний сектор і секунди) та шкалу
## накопичення — як "Лють" вартової, що заряджається від ударів.
##
## Якщо в res://assets/ui/icons/skills/<id>.png лежить картинка, кнопка
## бере її. Поки немає — іконку з набору Kenney Mobile Controls
## (assets/ui/controls, PACK_ICONS), а для решти видів (посохи, книга,
## карти, крига, отрута...) малює просту фігуру сама.
##
## Сама кнопка — темний диск із того ж набору з тонким обідком кольору
## здібності.

signal pressed_down
signal released

const BUTTON_TEXTURE := "res://assets/ui/controls/button_circle.png"
## Вид кнопки → іконка з набору (assets/ui/controls/icon_<назва>.png).
const PACK_ICONS := {
	"attack": "sword",
	"gun": "crosshair",
	"dodge": "jump",
	"whirl": "arrow_rotate",
	"dash": "arrow",
	"nova": "target",
	"fire": "fire",
}
## Подвійна стрілка з набору дивиться вгору ("стрибок") — для перекату
## повертаємо її вправо.
const PACK_ICON_TURN := {"dodge": PI * 0.5}

var radius := 60.0
## У скільки разів зона натиску ширша за намальоване коло. Перекату —
## найбільша: у бою по ньому б'ють наосліп, і промах коштує життя.
var hit_scale := 1.12
## Яку фігуру малювати: attack, dodge, whirl, dash, nova, fire, smoke.
var icon_kind := "attack"
## Готова картинка (якщо художник уже дав) — малюється замість фігури.
var icon_texture: Texture2D
var caption := ""
var accent := Color(0.98, 0.72, 0.25)

## Шкала накопичення 0..1 (лють, заряд) або -1, якщо її немає.
var charge := -1.0:
	set(value):
		if not is_equal_approx(value, charge):
			charge = value
			queue_redraw()

## 0 — готово, 1 — щойно використано. Задає власник кнопки.
var cooldown_ratio := 0.0:
	set(value):
		if not is_equal_approx(value, cooldown_ratio):
			cooldown_ratio = value
			queue_redraw()
var cooldown_seconds := 0.0

## Напис усередині кнопки (набої "24 / 30"). Порожньо — нічого не малюємо.
var inner_text := ""

var _touch_index := -1
var _down := false
var _background: Texture2D
var _pack_icon: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(BUTTON_TEXTURE):
		_background = load(BUTTON_TEXTURE)
	if PACK_ICONS.has(icon_kind):
		_pack_icon = UiTheme.control_icon(PACK_ICONS[icon_kind])
	size = Vector2(radius * 2.0, radius * 2.0)
	custom_minimum_size = size
	pivot_offset = size * 0.5

## Кнопка кругла — і натискається лише в колі, а не в кутах квадрата.
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= radius * hit_scale

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
	var is_ready := cooldown_ratio <= 0.0 and (charge < 0.0 or charge >= 1.0)
	# Обідок кольору здібності — диск під темною кнопкою, а не згладжена
	# лінія: дві прості команди малювання (дешевше для телефона).
	draw_circle(center, radius, Color(accent, 0.95 if is_ready else 0.35), true, -1.0, true)
	if _background != null:
		var inner := radius - 3.0
		draw_texture_rect(_background, Rect2(center - Vector2(inner, inner), Vector2(inner, inner) * 2.0),
			false, Color(0.72, 0.72, 0.72) if _down else Color.WHITE)
	else:
		draw_circle(center, radius - 4.0, Color(0.05, 0.06, 0.09, 0.8 if not _down else 0.9))
	var glyph_color := Color(1, 1, 1, 0.95 if is_ready else 0.45)
	if icon_texture != null:
		var side := radius * 1.1
		draw_texture_rect(icon_texture, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)),
			false, Color(1, 1, 1, 0.95 if is_ready else 0.5))
	elif _pack_icon != null:
		var side := radius * 0.92
		draw_set_transform(center, PACK_ICON_TURN.get(icon_kind, 0.0))
		draw_texture_rect(_pack_icon, Rect2(-Vector2(side, side) * 0.5, Vector2(side, side)), false, glyph_color)
		draw_set_transform(Vector2.ZERO)
	else:
		match icon_kind:
			"attack":
				_draw_sword(center, radius * 0.5, glyph_color)
			"dodge":
				_draw_chevrons(center, radius * 0.42, glyph_color)
			"dash":
				_draw_dash(center, radius * 0.45, glyph_color)
			"nova":
				_draw_nova(center, radius * 0.45, glyph_color)
			"fire":
				_draw_fire(center, radius * 0.45, glyph_color)
			"smoke":
				_draw_smoke(center, radius * 0.45, glyph_color)
			"gun":
				_draw_gun(center, radius * 0.5, glyph_color)
			"staff":
				_draw_staff(center, radius * 0.5, glyph_color)
			"frost":
				_draw_frost(center, radius * 0.45, glyph_color)
			"venom":
				_draw_venom(center, radius * 0.45, glyph_color)
			"bolt":
				_draw_bolt(center, radius * 0.45, glyph_color)
			"book":
				_draw_book(center, radius * 0.45, glyph_color)
			"cards":
				_draw_cards(center, radius * 0.45, glyph_color)
			"rune":
				_draw_rune(center, radius * 0.45, glyph_color)
			_:
				_draw_whirl(center, radius * 0.45, glyph_color)

	# Шкала накопичення: кільце наповнюється знизу за годинниковою.
	if charge >= 0.0 and charge < 1.0:
		var points := PackedVector2Array([center])
		var steps := 28
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * (1.0 - charge) * float(i) / steps
			points.append(center + Vector2(cos(angle), sin(angle)) * (radius - 3.0))
		draw_colored_polygon(points, Color(0, 0, 0, 0.5))
	elif charge >= 1.0:
		# Готово — навколо кнопки світиться кільце.
		draw_arc(center, radius + 3.0, 0.0, TAU, 40, Color(accent, 0.6), 4.0, true)

	if cooldown_ratio > 0.0:
		# Темний сектор перезарядки: зменшується за годинниковою стрілкою.
		var points := PackedVector2Array([center])
		var steps := 32
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * cooldown_ratio * float(i) / steps
			points.append(center + Vector2(cos(angle), sin(angle)) * (radius - 3.0))
		draw_colored_polygon(points, Color(0, 0, 0, 0.55))
		# Секунди показуємо, лише коли їх варто читати. Раніше тут був
		# вихід із малювання — і разом із секундами зникав напис із
		# набоями.
		if cooldown_seconds >= 0.15:
			var font := ThemeDB.fallback_font
			var text := "%.1f" % cooldown_seconds if cooldown_seconds < 3.0 else "%d" % ceili(cooldown_seconds)
			var font_size := int(radius * 0.5)
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.35), text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

	# Набої малюємо всередині кнопки: підпис під нею на телефоні
	# опинявся б за краєм екрана.
	if inner_text != "":
		var ammo_font := ThemeDB.fallback_font
		var ammo_size := int(radius * 0.32)
		var ammo_width := ammo_font.get_string_size(inner_text, HORIZONTAL_ALIGNMENT_CENTER, -1, ammo_size).x
		draw_string(ammo_font, center + Vector2(-ammo_width * 0.5, radius * 0.62), inner_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, ammo_size, Color(1, 1, 1, 0.9))

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

## Стріла вперед — ривок.
func _draw_dash(center: Vector2, size_px: float, color: Color) -> void:
	draw_line(center - Vector2(size_px, 0), center + Vector2(size_px * 0.4, 0), color, size_px * 0.25)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(size_px, 0),
		center + Vector2(size_px * 0.2, -size_px * 0.55),
		center + Vector2(size_px * 0.2, size_px * 0.55)]), color)

## Кола, що розходяться, — нова.
func _draw_nova(center: Vector2, size_px: float, color: Color) -> void:
	draw_circle(center, size_px * 0.28, color)
	draw_arc(center, size_px * 0.62, 0.0, TAU, 20, color, size_px * 0.13)
	draw_arc(center, size_px * 0.95, 0.0, TAU, 24, Color(color, color.a * 0.6), size_px * 0.1)

## Язик полум'я.
func _draw_fire(center: Vector2, size_px: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -size_px),
		center + Vector2(size_px * 0.6, size_px * 0.2),
		center + Vector2(0, size_px * 0.9),
		center + Vector2(-size_px * 0.6, size_px * 0.2)]), color)
	draw_circle(center + Vector2(0, size_px * 0.35), size_px * 0.3, Color(1, 1, 1, color.a * 0.7))

## Клуби диму.
func _draw_smoke(center: Vector2, size_px: float, color: Color) -> void:
	draw_circle(center + Vector2(-size_px * 0.4, size_px * 0.15), size_px * 0.45, color)
	draw_circle(center + Vector2(size_px * 0.35, size_px * 0.25), size_px * 0.4, Color(color, color.a * 0.8))
	draw_circle(center + Vector2(0, -size_px * 0.3), size_px * 0.5, Color(color, color.a * 0.6))

## Силует пістолета — для стрілецької зброї.
func _draw_gun(center: Vector2, size_px: float, color: Color) -> void:
	var body := Rect2(center + Vector2(-size_px * 0.9, -size_px * 0.45), Vector2(size_px * 1.5, size_px * 0.5))
	draw_rect(body, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size_px * 0.5, size_px * 0.05),
		center + Vector2(-size_px * 0.1, size_px * 0.05),
		center + Vector2(-size_px * 0.25, size_px * 0.85),
		center + Vector2(-size_px * 0.7, size_px * 0.85)]), color)

## Посох навскіс із кулею на верхівці — кнопка чар.
func _draw_staff(center: Vector2, length: float, color: Color) -> void:
	var direction := Vector2(1, -1).normalized()
	var top := center + direction * length * 0.75
	draw_line(center - direction * length, top, color, length * 0.13)
	draw_circle(top, length * 0.28, color)
	draw_arc(top, length * 0.45, 0.0, TAU, 18, Color(color, color.a * 0.5), length * 0.08)

## Сніжинка — крига.
func _draw_frost(center: Vector2, size_px: float, color: Color) -> void:
	for i in 3:
		var direction := Vector2.from_angle(PI / 2.0 + TAU * i / 6.0)
		draw_line(center - direction * size_px, center + direction * size_px, color, size_px * 0.16)
		for side: float in [-1.0, 1.0]:
			var tip := center + direction * size_px * 0.6 * side
			var branch := direction.rotated(0.7 if side > 0.0 else PI - 0.7) * size_px * 0.3
			draw_line(tip, tip + branch, color, size_px * 0.1)

## Крапля отрути з бульбашками.
func _draw_venom(center: Vector2, size_px: float, color: Color) -> void:
	draw_circle(center + Vector2(0, size_px * 0.25), size_px * 0.55, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -size_px * 0.95),
		center + Vector2(size_px * 0.5, size_px * 0.1),
		center + Vector2(-size_px * 0.5, size_px * 0.1)]), color)
	draw_circle(center + Vector2(-size_px * 0.15, size_px * 0.2), size_px * 0.14, Color(1, 1, 1, color.a * 0.6))

## Блискавка — злам.
func _draw_bolt(center: Vector2, size_px: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(size_px * 0.25, -size_px),
		center + Vector2(-size_px * 0.45, size_px * 0.1),
		center + Vector2(-size_px * 0.02, size_px * 0.1),
		center + Vector2(-size_px * 0.25, size_px),
		center + Vector2(size_px * 0.45, -size_px * 0.15),
		center + Vector2(size_px * 0.02, -size_px * 0.15)]), color)

## Розгорнута книга.
func _draw_book(center: Vector2, size_px: float, color: Color) -> void:
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -size_px * 0.55),
			center + Vector2(side * size_px, -size_px * 0.75),
			center + Vector2(side * size_px, size_px * 0.6),
			center + Vector2(0, size_px * 0.8)]), color)
	draw_line(center + Vector2(0, -size_px * 0.55), center + Vector2(0, size_px * 0.8),
		Color(0.05, 0.06, 0.09, 0.9), size_px * 0.1)

## Дві карти віялом.
func _draw_cards(center: Vector2, size_px: float, color: Color) -> void:
	for angle: float in [-0.3, 0.25]:
		var card := PackedVector2Array()
		for corner: Vector2 in [Vector2(-0.45, -0.7), Vector2(0.45, -0.7), Vector2(0.45, 0.7), Vector2(-0.45, 0.7)]:
			card.append(center + (corner * size_px).rotated(angle))
		draw_colored_polygon(card, color)
		card.append(card[0])
		draw_polyline(card, Color(0.05, 0.06, 0.09, 0.9), size_px * 0.08)

## Руна "Феху" в колі печаті: стовбур і дві гілки навскіс угору.
func _draw_rune(center: Vector2, size_px: float, color: Color) -> void:
	draw_arc(center, size_px * 0.95, 0.0, TAU, 28, color, size_px * 0.12)
	var width := size_px * 0.16
	var stave := center + Vector2(-size_px * 0.18, 0)
	draw_line(stave + Vector2(0, size_px * 0.6), stave + Vector2(0, -size_px * 0.6), color, width)
	draw_line(stave + Vector2(0, -size_px * 0.12), stave + Vector2(size_px * 0.45, -size_px * 0.5), color, width)
	draw_line(stave + Vector2(0, size_px * 0.22), stave + Vector2(size_px * 0.45, -size_px * 0.16), color, width)

## Три дуги по колу — вихор.
func _draw_whirl(center: Vector2, size_px: float, color: Color) -> void:
	for i in 3:
		var start := TAU * i / 3.0
		draw_arc(center, size_px * (0.45 + 0.2 * i), start, start + PI * 0.9, 16, color, size_px * 0.16)
