extends Area2D

## Снаряд героя: летить по прямій, при влучанні у ворога завдає шкоди
## й повертається в пул замість queue_free(). Якщо ні в кого не влучив —
## повертається в пул сам після MAX_LIFETIME секунд польоту.

const MAX_LIFETIME := 2.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _direction := Vector2.ZERO
var _pierce_left := 0
var _lifetime_left := 0.0
var _active := false
var _pool: ObjectPool

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func spawn(from_position: Vector2, direction: Vector2) -> void:
	global_position = from_position
	_direction = direction
	rotation = direction.angle()
	_pierce_left = Balance.WEAPON_PIERCE
	_lifetime_left = MAX_LIFETIME

func pool_activate() -> void:
	_active = true
	visible = true
	collision_shape.disabled = false

func pool_deactivate() -> void:
	_active = false
	visible = false
	collision_shape.disabled = true
	global_position = Vector2(-10000, -10000)

func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position += _direction * Balance.WEAPON_PROJECTILE_SPEED * delta
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_return_to_pool()

func _on_body_entered(body: Node) -> void:
	if not _active or not body.has_method("take_damage"):
		return
	body.take_damage(Balance.WEAPON_DAMAGE)
	if _pierce_left <= 0:
		_return_to_pool()
	else:
		_pierce_left -= 1

func _return_to_pool() -> void:
	_pool.release(self)
