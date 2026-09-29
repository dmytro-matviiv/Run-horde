extends Node3D

## Камера, закріплена за героєм.
##
## 1. Камера НЕ приклеєна до персонажа намертво — вона наздоганяє його з
##    невеликим запізненням, тож різкі зміни напрямку не смикають екран.
## 2. SpringArm3D сам підтягує камеру ближче, якщо між нею й героєм
##    опинилась стіна чи скеля — не буває "камери в горі".
## 3. Кут повороту змінює ТІЛЬКИ гравець: палець на правій половині
##    екрана або права кнопка миші. Раніше камера сама заходила героєві
##    за спину, коли той біг убік чи назад, — у бою це дуже заважало:
##    відступаєш від ворога, а світ крутиться. Тепер камера стоїть, як
##    її поставили.
## 4. Сильні удари злегка трусять камеру — так удар відчувається.

const FOLLOW_SPEED := 6.0      # як швидко камера наздоганяє героя
const HEIGHT_OFFSET := 1.2     # дивимось на груди, а не на ноги

## Тряска гасне сама; сила — зсув камери в метрах.
const SHAKE_DECAY := 5.0
const SHAKE_FREQUENCY := 38.0

@export var target_path: NodePath
@export var distance := 7.0
@export var pitch_degrees := -34.0

## Межі нахилу. Вище горизонту камеру не пускаємо (видно було б порожнє
## небо й стелю), а прямовисно згори гра перетворюється на план кімнати.
@export var min_pitch_degrees := -72.0
@export var max_pitch_degrees := -12.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _target: Node3D
var _yaw := 0.0
var _pitch := 0.0
var _shake := 0.0
var _shake_time := 0.0

func _ready() -> void:
	add_to_group(&"camera_rig")
	_target = get_node_or_null(target_path) as Node3D
	spring_arm.spring_length = distance
	spring_arm.rotation_degrees.x = pitch_degrees
	_yaw = rotation.y
	_pitch = deg_to_rad(pitch_degrees)
	if _target != null:
		global_position = _target.global_position + Vector3.UP * HEIGHT_OFFSET

## Чи підтягувати камеру ближче, коли між нею й героєм стіна. На острові
## будівлі високі, і без цього камера опинялась би в даху. У данжі стіни
## по пояс, камера дивиться поверх них — а підтягування біля стіни
## "в'їжджало" камерою впритул до героя посеред бою, тож там воно вимкнене.
func set_world_collision(enabled: bool) -> void:
	spring_arm.collision_mask = 1 if enabled else 0

## Поворот камери: палець по правій половині екрана або права кнопка миші.
func rotate_by(amount: float) -> void:
	_yaw = wrapf(_yaw + amount, -PI, PI)

## Межі нахилу й початковий нахил — для місць, де потрібен свій кут
## (у данжі камера дивиться круто згори).
func set_pitch_limits(min_degrees: float, max_degrees: float, start_degrees: float) -> void:
	min_pitch_degrees = min_degrees
	max_pitch_degrees = max_degrees
	_pitch = deg_to_rad(clampf(start_degrees, min_degrees, max_degrees))
	spring_arm.rotation.x = _pitch

## Нахил камери вгору-вниз тим самим пальцем.
func pitch_by(amount: float) -> void:
	_pitch = clampf(_pitch + amount, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	spring_arm.rotation.x = _pitch

## Струснути камеру. Сильніший поштовх перекриває слабший, а не
## складається з ним, — інакше серія ударів розгойдала б екран.
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)

## Миттєво стати над героєм. Коли героя переставили (повернувся з
## будівлі), камера інакше летіла б до нього через усе місто.
func snap_to_target() -> void:
	if _target != null:
		global_position = _target.global_position + Vector3.UP * HEIGHT_OFFSET

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var wanted := _target.global_position + Vector3.UP * HEIGHT_OFFSET
	# lerp зі швидкістю, обмеженою кадром: рух камери лишається плавним
	# і на 30, і на 120 кадрах за секунду.
	global_position = global_position.lerp(wanted, clampf(FOLLOW_SPEED * delta, 0.0, 1.0))
	rotation.y = _yaw

func _process(delta: float) -> void:
	if _shake <= 0.001:
		if camera.h_offset != 0.0 or camera.v_offset != 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
		return
	_shake_time += delta * SHAKE_FREQUENCY
	camera.h_offset = sin(_shake_time * 1.3) * _shake
	camera.v_offset = cos(_shake_time * 1.7) * _shake * 0.7
	_shake = move_toward(_shake, 0.0, SHAKE_DECAY * _shake * delta + 0.02 * delta)
