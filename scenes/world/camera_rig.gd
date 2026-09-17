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

@export var target_path: NodePath
@export var distance := 7.0
@export var pitch_degrees := -34.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

var _target: Node3D

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	spring_arm.spring_length = distance
	spring_arm.rotation_degrees.x = pitch_degrees
	if _target != null:
		global_position = _target.global_position + Vector3.UP * HEIGHT_OFFSET

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var wanted := _target.global_position + Vector3.UP * HEIGHT_OFFSET
	# lerp зі швидкістю, обмеженою кадром: рух камери лишається плавним
	# і на 30, і на 120 кадрах за секунду.
	global_position = global_position.lerp(wanted, clampf(FOLLOW_SPEED * delta, 0.0, 1.0))
