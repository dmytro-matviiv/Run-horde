extends Area2D

## Кристал досвіду/золота: випадає з вбитого ворога, лежить на місці,
## поки не потрапить у PickupArea героя (миттєвий підбір) або в
## MagnetArea (тоді летить до героя через pull_toward, якщо взято
## апгрейд "Магніт").

const MAGNET_SPEED := 300.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var xp_value: int
var gold_value: int
var _pool: ObjectPool
var _active := false

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func spawn(at_position: Vector2, xp: int, gold: int) -> void:
	global_position = at_position
	xp_value = xp
	gold_value = gold

## disabled міняємо через set_deferred — pool_activate() тут
## викликається з enemy.gd _die(), яка сама викликається посеред
## обробки фізичних колізій (снаряд поцілив ворога). Пряма зміна
## disabled у цей момент падає з помилкою "flushing queries".
func pool_activate() -> void:
	_active = true
	visible = true
	collision_shape.set_deferred("disabled", false)

func pool_deactivate() -> void:
	_active = false
	visible = false
	collision_shape.set_deferred("disabled", true)
	global_position = Vector2(-10000, -10000)

## Викликає герой, коли підбирає кристал. Повертає скільки XP/золота
## дісталось гравцю, і сам віддає себе назад у пул.
func collect() -> Dictionary:
	var result := {"xp": xp_value, "gold": gold_value}
	_pool.release(self)
	return result

func pull_toward(target_position: Vector2, delta: float) -> void:
	if not _active:
		return
	global_position += global_position.direction_to(target_position) * MAGNET_SPEED * delta
