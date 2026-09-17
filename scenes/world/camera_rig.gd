extends Node3D

## Камера, закріплена за героєм. Три речі, які роблять картинку плавною:
##
## 1. Камера НЕ приклеєна до персонажа намертво — вона наздоганяє його з
##    невеликим запізненням, тож різкі зміни напрямку не смикають екран.
## 2. SpringArm3D сам підтягує камеру ближче, якщо між нею й героєм
##    опинилась стіна чи скеля — не буває "камери в горі".
## 3. Кут нахилу фіксований, як просив замовник: гравець завжди бачить
##    світ під одним ракурсом, а обертається сам персонаж.

const FOLLOW_SPEED := 6.0      # як швидко камера наздоганяє героя
const HEIGHT_OFFSET := 1.2     # дивимось на груди, а не на ноги

## Камера сама доводиться за спину героєві, коли той біжить: інакше,
## повернувши назад, гравець біжить "на себе" й не бачить, куди йде.
## Робимо це повільно — різкий доворот камери викликає нудоту.
const AUTO_FOLLOW_SPEED := 2.4

## Після ручного повороту (палець на правій половині чи права кнопка
## миші) автодоведення мовчить кілька секунд, щоб не боротися з гравцем.
const MANUAL_HOLD_TIME := 3.0

@export var target_path: NodePath
@export var distance := 7.0
@export var pitch_degrees := -34.0

## Чи доводити камеру за рухом автоматично.
@export var auto_follow := true

## Межі нахилу. Вище горизонту камеру не пускаємо (видно було б порожнє
## небо й стелю), а прямовисно згори гра перетворюється на план кімнати.
@export var min_pitch_degrees := -72.0
@export var max_pitch_degrees := -12.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

var _target: Node3D
var _yaw := 0.0
var _pitch := 0.0
var _manual_left := 0.0

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	spring_arm.spring_length = distance
	spring_arm.rotation_degrees.x = pitch_degrees
	_yaw = rotation.y
	_pitch = deg_to_rad(pitch_degrees)
	if _target != null:
		global_position = _target.global_position + Vector3.UP * HEIGHT_OFFSET

## Ручний поворот камери: палець по правій половині екрана або права
## кнопка миші.
func rotate_by(amount: float) -> void:
	_yaw = wrapf(_yaw + amount, -PI, PI)
	_manual_left = MANUAL_HOLD_TIME

## Нахил камери вгору-вниз тим самим пальцем. Автодоведення нахилу не
## чіпає: висота погляду — справа гравця, і вона лишається такою, як він
## поставив.
func pitch_by(amount: float) -> void:
	_pitch = clampf(_pitch + amount, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	spring_arm.rotation.x = _pitch
	_manual_left = MANUAL_HOLD_TIME

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var wanted := _target.global_position + Vector3.UP * HEIGHT_OFFSET
	# lerp зі швидкістю, обмеженою кадром: рух камери лишається плавним
	# і на 30, і на 120 кадрах за секунду.
	global_position = global_position.lerp(wanted, clampf(FOLLOW_SPEED * delta, 0.0, 1.0))
	_update_yaw(delta)

func _update_yaw(delta: float) -> void:
	if _manual_left > 0.0:
		_manual_left -= delta
	elif auto_follow and _target.has_method("get_move_yaw") and _target.is_moving():
		# Камера повільно заходить героєві за спину: він біжить "від
		# нас", і дорогу попереду видно.
		_yaw = rotate_toward(_yaw, _target.get_move_yaw() + PI, AUTO_FOLLOW_SPEED * delta)
	rotation.y = _yaw
