extends Area2D

## Снаряд героя: летить по прямій, при влучанні у ворога завдає шкоди
## й повертається в пул замість queue_free(). Шкода/пробиття/рикошет
## передаються ззовні при spawn(), бо залежать від апгрейдів героя,
## а не від фіксованих чисел балансу.

const MAX_LIFETIME := 2.0
const RICOCHET_SEARCH_RADIUS := 260.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _direction := Vector2.ZERO
var _damage := 0.0
var _pierce_left := 0
var _ricochet_left := 0
var _lifetime_left := 0.0
var _active := false
var _pool: ObjectPool
var _last_hit_enemy: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func spawn(from_position: Vector2, direction: Vector2, damage: float, pierce: int, ricochet: int) -> void:
	global_position = from_position
	_direction = direction
	rotation = direction.angle()
	_damage = damage
	_pierce_left = pierce
	_ricochet_left = ricochet
	_lifetime_left = MAX_LIFETIME
	_last_hit_enemy = null

## disabled міняємо через set_deferred — pool_deactivate() тут
## викликається прямо з _on_body_entered(), тобто посеред обробки
## фізичних колізій, де пряма зміна disabled падає з помилкою
## "flushing queries".
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
	global_position += _direction * Balance.WEAPON_PROJECTILE_SPEED * delta
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_return_to_pool()

func _on_body_entered(body: Node) -> void:
	if not _active or body == _last_hit_enemy or not body.has_method("take_damage"):
		return
	body.take_damage(_damage)
	_last_hit_enemy = body
	if _pierce_left > 0:
		_pierce_left -= 1
		return
	if _ricochet_left > 0 and _retarget_to_nearest_enemy(body):
		_ricochet_left -= 1
		return
	_return_to_pool()

## Шукає найближчого іншого ворога й перенаправляє снаряд на нього.
## Повертає false, якщо ціль для рикошету не знайшлась (тоді снаряд
## просто повертається в пул як звичайно).
func _retarget_to_nearest_enemy(exclude: Node) -> bool:
	var nearest: Node2D = null
	var nearest_distance := RICOCHET_SEARCH_RADIUS * RICOCHET_SEARCH_RADIUS
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == exclude or not enemy.visible:
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	if nearest == null:
		return false
	_direction = global_position.direction_to(nearest.global_position)
	rotation = _direction.angle()
	return true

func _return_to_pool() -> void:
	_pool.release(self)
