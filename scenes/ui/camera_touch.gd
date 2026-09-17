extends Control

## Права половина екрана: обертання камери пальцем, а короткий дотик —
## удар. Ліва половина лишається джойстику руху, тож великі пальці не
## заважають один одному — стандартна схема мобільних екшенів.
##
## На ПК те саме роблять миша й права кнопка: перетягування з натиснутою
## правою крутить камеру, клік лівою в правій половині — удар. Це для
## зручності тестування, поки немає телефона під рукою.

signal rotate_requested(amount: float)
signal tap_attack

## Скільки радіанів повороту дає один піксель протягування.
const ROTATE_PER_PIXEL := 0.006

## Дотик, коротший за це і без помітного зсуву, вважається ударом, а не
## спробою покрутити камеру.
const TAP_TIME := 0.25
const TAP_DISTANCE := 18.0

var _touch_index := -1
var _start_position := Vector2.ZERO
var _last_position := Vector2.ZERO
var _travelled := 0.0
var _held_time := 0.0
var _mouse_rotating := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)

func _process(delta: float) -> void:
	if _touch_index != -1:
		_held_time += delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_handle_drag(event.position)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_rotating:
		rotate_requested.emit(-event.relative.x * ROTATE_PER_PIXEL)

func _handle_touch(index: int, position: Vector2, pressed: bool) -> void:
	if pressed:
		# Ліва половина — рух, її не чіпаємо.
		if _touch_index != -1 or position.x < size.x * 0.5:
			return
		_touch_index = index
		_start_position = position
		_last_position = position
		_travelled = 0.0
		_held_time = 0.0
	elif index == _touch_index:
		# Відпустив швидко й майже не зрушивши пальця — це удар.
		if _held_time <= TAP_TIME and _travelled <= TAP_DISTANCE:
			tap_attack.emit()
		_touch_index = -1

func _handle_drag(position: Vector2) -> void:
	var shift := position.x - _last_position.x
	_travelled += absf(position.x - _last_position.x) + absf(position.y - _last_position.y)
	_last_position = position
	rotate_requested.emit(-shift * ROTATE_PER_PIXEL)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_rotating = event.pressed
	elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.position.x > size.x * 0.5:
		tap_attack.emit()
