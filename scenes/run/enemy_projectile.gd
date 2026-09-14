extends Area2D

## Снаряд ворога-лучника: летить по прямій, завдає шкоди героєві на
## контакті. Пулиться так само, як снаряд героя — на пізніх хвилинах
## рану лучників може бути кілька одночасно.

const MAX_LIFETIME := 3.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _direction := Vector2.ZERO
var _damage := 0.0
var _speed := 0.0
var _lifetime_left := 0.0
var _active := false
var _pool: ObjectPool

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func spawn(from_position: Vector2, direction: Vector2, damage: float, speed: float) -> void:
	global_position = from_position
	_direction = direction
	rotation = direction.angle()
	_damage = damage
	_speed = speed
	_lifetime_left = MAX_LIFETIME

func pool_activate() -> void:
	_active = true
	visible = true
	collision_shape.set_deferred("disabled", false)

func pool_deactivate() -> void:
	_active = false
	visible = false
	collision_shape.set_deferred("disabled", true)
	global_position = Vector2(-10000, -10000)

func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position += _direction * _speed * delta
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_pool.release(self)

## Не б'є героя під час i-фреймів — так само, як контактна шкода,
## інакше стрільба лучника обходила б невразливість після удару.
func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	if body.has_method("take_damage") and body.has_method("is_invulnerable"):
		if not body.is_invulnerable():
			body.take_damage(_damage)
	_pool.release(self)
