extends Control

## Джойстик для телефона. Раніше керування було "невидимим": гравець
## тягнув пальцем будь-де й мусив здогадуватись, що відбувається. Тепер
## під пальцем малюється справжній джойстик — основа й ручка.
##
## Джойстик "плаваючий": з'являється там, де гравець торкнувся лівої
## половини екрана, і зникає, коли відпустив. Так не треба цілитись у
## фіксований кружечок, а великий палець завжди попадає.
##
## Права половина екрана лишається вільною для кнопок (пауза тощо).
##
## Вигляд — темний диск і ручка з набору Kenney Mobile Controls. Поки
## палець не торкається, блідий джойстик стоїть у лівому нижньому куті —
## видно, куди ставити палець.

signal direction_changed(direction: Vector2)

const MAX_RADIUS := 90.0      # відтягування на цю відстань = повна швидкість
const DEAD_ZONE := 8.0        # менше — вважаємо, що гравець просто тримає палець
const BASE_ALPHA := 0.25
const KNOB_ALPHA := 0.55
const IDLE_ALPHA := 0.35
const KNOB_RADIUS := 38.0
const PAD_TEXTURE := "res://assets/ui/controls/joystick_circle_pad_a.png"
const NUB_TEXTURE := "res://assets/ui/controls/joystick_circle_nub_a.png"

var _pad: Texture2D
var _nub: Texture2D

var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _active := false

func _ready() -> void:
	# Джойстик малюється поверх гри, але не краде події в кнопок HUD.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)
	if ResourceLoader.exists(PAD_TEXTURE):
		_pad = load(PAD_TEXTURE)
	if ResourceLoader.exists(NUB_TEXTURE):
		_nub = load(NUB_TEXTURE)
	resized.connect(queue_redraw)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_press(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_handle_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Миша — для перевірки на ПК: поводиться так само, як палець.
		_handle_press(-2, event.position, event.pressed)
	elif event is InputEventMouseMotion and _active and _touch_index == -2:
		_handle_drag(event.position)

## Гра стала на паузу — палець, відпущений під час паузи, джойстик уже не
## почує, і герой після паузи біг би сам. Тому на паузі джойстик
## відпускаємо.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _active:
		_active = false
		_touch_index = -1
		direction_changed.emit(Vector2.ZERO)
		queue_redraw()

func _handle_press(index: int, position: Vector2, pressed: bool) -> void:
	if pressed:
		if _active or position.x > size.x * 0.5:
			return   # права половина екрана — не для керування
		_touch_index = index
		_origin = position
		_knob = position
		_active = true
		queue_redraw()
	elif index == _touch_index:
		_active = false
		_touch_index = -1
		direction_changed.emit(Vector2.ZERO)
		queue_redraw()

func _handle_drag(position: Vector2) -> void:
	# Протягування без активного дотику ігноруємо: інакше рух міг би
	# початись від випадкової події (наприклад, коли палець прийшов з
	# правої половини екрана, де керування немає).
	if not _active:
		return
	_knob = position
	var offset := _knob - _origin
	var distance := offset.length()
	if distance < DEAD_ZONE:
		direction_changed.emit(Vector2.ZERO)
	else:
		# Сила залежить від того, наскільки далеко відтягнули ручку.
		direction_changed.emit(offset.normalized() * clampf(distance / MAX_RADIUS, 0.0, 1.0))
	queue_redraw()

func _draw() -> void:
	if not _active:
		# Підказка, куди ставити палець: блідий джойстик у кутку.
		_draw_stick(_idle_center(), Vector2.ZERO, IDLE_ALPHA)
		return
	var offset := _knob - _origin
	if offset.length() > MAX_RADIUS:
		offset = offset.normalized() * MAX_RADIUS
	_draw_stick(_origin, offset, 1.0)

func _idle_center() -> Vector2:
	return Vector2(MAX_RADIUS + 60.0, size.y - MAX_RADIUS - 50.0)

func _draw_stick(center: Vector2, offset: Vector2, alpha: float) -> void:
	if _pad == null or _nub == null:
		draw_circle(center, MAX_RADIUS, Color(1, 1, 1, BASE_ALPHA * 0.35 * alpha))
		draw_arc(center, MAX_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, BASE_ALPHA * alpha), 3.0)
		draw_circle(center + offset, 34.0, Color(0.98, 0.72, 0.25, KNOB_ALPHA * alpha))
		return
	var pad_radius := MAX_RADIUS + 18.0
	draw_texture_rect(_pad, Rect2(center - Vector2(pad_radius, pad_radius), Vector2(pad_radius, pad_radius) * 2.0),
		false, Color(1, 1, 1, 0.85 * alpha))
	draw_texture_rect(_nub, Rect2(center + offset - Vector2(KNOB_RADIUS, KNOB_RADIUS), Vector2(KNOB_RADIUS, KNOB_RADIUS) * 2.0),
		false, Color(1, 1, 1, alpha))
