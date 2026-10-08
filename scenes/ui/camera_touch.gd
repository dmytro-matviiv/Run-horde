extends Control

## Права половина екрана: обертання камери пальцем. Ліва половина
## лишається джойстику руху, тож великі пальці не заважають один одному.
## Короткий дотик по екрану більше НЕ б'є: б'є лише кнопка удару. Інакше
## промах повз кнопку перекату ставав ударом — герой завмирав у замаху
## замість ухилу й міг загинути.
##
## На ПК те саме роблять миша й права кнопка: перетягування з натиснутою
## правою крутить камеру, ліва кнопка в правій половині — удар (утримання
## б'є серією). Це для зручності тестування, поки немає телефона під рукою.

signal rotate_requested(amount: float)
signal pitch_requested(amount: float)
signal attack_held_changed(held: bool)

## Скільки радіанів повороту дає один піксель протягування.
## Вертикаль трохи млявіша за горизонталь: нахил має бути точним, бо
## його діапазон куди менший, ніж повний оберт навколо героя.
const ROTATE_PER_PIXEL := 0.006
const PITCH_PER_PIXEL := 0.004

var _touch_index := -1
var _start_position := Vector2.ZERO
var _last_position := Vector2.ZERO
var _mouse_rotating := false
var _mouse_attacking := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_handle_drag(event.position)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_rotating:
		rotate_requested.emit(-event.relative.x * ROTATE_PER_PIXEL)
		pitch_requested.emit(-event.relative.y * PITCH_PER_PIXEL)

## На паузі дотики сюди не доходять — скидаємо стан, щоб після паузи
## не лишився "затиснутий" удар чи оберт камери.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PAUSED:
		return
	_touch_index = -1
	_mouse_rotating = false
	if _mouse_attacking:
		_mouse_attacking = false
		attack_held_changed.emit(false)

func _handle_touch(index: int, position: Vector2, pressed: bool) -> void:
	if pressed:
		# Ліва половина — рух, її не чіпаємо.
		if _touch_index != -1 or position.x < size.x * 0.5:
			return
		_touch_index = index
		_start_position = position
		_last_position = position
	elif index == _touch_index:
		_touch_index = -1

func _handle_drag(position: Vector2) -> void:
	var shift := position - _last_position
	_last_position = position
	# Один палець робить обидва рухи: вбік — оберт навколо героя,
	# вгору-вниз — нахил камери.
	rotate_requested.emit(-shift.x * ROTATE_PER_PIXEL)
	pitch_requested.emit(-shift.y * PITCH_PER_PIXEL)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_rotating = event.pressed
	elif event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and event.position.x > size.x * 0.5:
			_mouse_attacking = true
			attack_held_changed.emit(true)
		elif not event.pressed and _mouse_attacking:
			_mouse_attacking = false
			attack_held_changed.emit(false)
