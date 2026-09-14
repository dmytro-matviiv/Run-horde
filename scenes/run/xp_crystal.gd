extends Area2D

## Кристал досвіду/золота: випадає з вбитого ворога, лежить на місці,
## поки герой не підбере його своєю PickupArea (магнітом виступає її
## радіус — Balance.HERO_PICKUP_RADIUS).

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

func pool_activate() -> void:
	_active = true
	visible = true
	collision_shape.disabled = false

func pool_deactivate() -> void:
	_active = false
	visible = false
	collision_shape.disabled = true
	global_position = Vector2(-10000, -10000)

## Викликає герой, коли підбирає кристал. Повертає скільки XP/золота
## дісталось гравцю, і сам віддає себе назад у пул.
func collect() -> Dictionary:
	var result := {"xp": xp_value, "gold": gold_value}
	_pool.release(self)
	return result
