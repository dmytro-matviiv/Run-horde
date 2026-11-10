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
## Межі карти (данж), Rect2 у метрах (x, z): екран не показує нічого за
## ними. Камера рахує, яку ділянку підлоги видно (кути екрана, спроєктовані
## на підлогу — за поточним поворотом і нахилом), і зсувається так, щоб ця
## ділянка не виходила за край. Біля краю герой іде далі, а камера стоїть.
var _bounds := Rect2()
## Висота підлоги, на яку проєктуємо кути екрана.
var _floor_y := 0.0
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

## Межі карти на площині (x, z). Порожній Rect2 — без меж.
func set_bounds(bounds: Rect2, floor_y: float = 0.0) -> void:
	_bounds = bounds
	_floor_y = floor_y

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
		rotation.y = _yaw
		global_position = _clamp_view(_target.global_position + Vector3.UP * HEIGHT_OFFSET)

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	rotation.y = _yaw
	var wanted := _clamp_view(_target.global_position + Vector3.UP * HEIGHT_OFFSET)
	# lerp зі швидкістю, обмеженою кадром: рух камери лишається плавним
	# і на 30, і на 120 кадрах за секунду.
	global_position = global_position.lerp(wanted, clampf(FOLLOW_SPEED * delta, 0.0, 1.0))
	# Кут змінився (гравець крутнув камеру) — межі теж: не чекаємо lerp,
	# інакше на мить визирнув би край карти.
	global_position = _clamp_view(global_position)

## Точка, куди стати камері, щоб видима ділянка підлоги не виходила за
## межі карти. Ділянка більша за карту по якійсь осі — стаємо посередині.
func _clamp_view(wanted: Vector3) -> Vector3:
	if _bounds.size == Vector2.ZERO:
		return wanted
	var reach := _view_reach()
	if reach.size == Vector2.ZERO:
		return wanted
	# reach — ділянка видимої підлоги відносно самої камери-кріплення.
	var low := _bounds.position - reach.position
	var high := _bounds.end - reach.end
	var clamped := wanted
	clamped.x = clampf(wanted.x, low.x, high.x) if low.x <= high.x else (low.x + high.x) * 0.5
	clamped.z = clampf(wanted.z, low.y, high.y) if low.y <= high.y else (low.y + high.y) * 0.5
	if _target == null:
		return clamped
	# Але героя видно завжди: він не заходить під панель здоров'я вгорі й
	# під кнопки внизу. Якщо край карти й герой сперечаються — перемагає
	# герой (камера зсувається до нього рівно настільки, скільки треба).
	var centered := _target.global_position + Vector3.UP * HEIGHT_OFFSET
	if _hero_safe(clamped):
		return clamped
	var safe_t := 0.0
	var unsafe_t := 1.0
	for i in 7:
		var t := (safe_t + unsafe_t) * 0.5
		if _hero_safe(centered.lerp(clamped, t)):
			safe_t = t
		else:
			unsafe_t = t
	return centered.lerp(clamped, safe_t)

## Безпечна зона екрана (частки ширини й висоти): тут героя не закривають
## панель здоров'я, підказки й кнопки.
const SAFE_AREA := Rect2(0.15, 0.3, 0.7, 0.52)

## Чи буде герой у безпечній зоні, якщо кріплення камери стане в spot.
## Зсув камери на d — те саме, що зсув героя на -d: проєктуємо героя,
## зсунутого навпаки, поточною камерою.
func _hero_safe(spot: Vector3) -> bool:
	var viewport := get_viewport()
	if viewport == null or not camera.is_inside_tree():
		return true
	var size := viewport.get_visible_rect().size
	var hero := _target.global_position + Vector3.UP * 0.9 + (global_position - spot)
	if camera.is_position_behind(hero):
		return false
	var screen := camera.unproject_position(hero)
	var area := Rect2(SAFE_AREA.position * size, SAFE_AREA.size * size)
	return area.has_point(screen)

## Прямокутник (x, z), який займає видима підлога, — у метрах відносно
## кріплення камери. Кути екрана проєктуємо на підлогу; промінь, що не
## дістає підлоги (дивиться вище горизонту), обрізаємо на 60 м.
func _view_reach() -> Rect2:
	var viewport := get_viewport()
	if viewport == null or not camera.is_inside_tree():
		return Rect2()
	var size := viewport.get_visible_rect().size
	var origin := global_position
	# Позиція камери відносно кріплення не залежить від того, де кріплення
	# стоїть: рахуємо від поточної, без трясіння.
	var eye := camera.global_position - camera.global_basis.x * camera.h_offset - camera.global_basis.y * camera.v_offset
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(0.0, size.y), size]:
		var direction := camera.project_ray_normal(corner)
		var hit: Vector3
		if direction.y < -0.02:
			hit = eye + direction * ((_floor_y - eye.y) / direction.y)
		else:
			hit = eye + Vector3(direction.x, 0.0, direction.z).normalized() * 60.0
		var flat := Vector2(hit.x - origin.x, hit.z - origin.z)
		low = Vector2(minf(low.x, flat.x), minf(low.y, flat.y))
		high = Vector2(maxf(high.x, flat.x), maxf(high.y, flat.y))
	return Rect2(low, high - low)

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
