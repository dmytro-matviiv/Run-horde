extends Area2D

## Снаряд нової системи зброї. На відміну від старого projectile.gd
## він не знає фіксованих чисел: швидкість, розмір, колір, пробиття,
## статус-ефект і радіус вибуху приходять зі зброї (WeaponDef), тож
## один і той самий вузол у пулі обслуговує і легкий кинджал, і
## метеор, що вибухає.

const MAX_LIFETIME := 2.5
const RICOCHET_SEARCH_RADIUS := 260.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Polygon2D = $Sprite

var _direction := Vector2.ZERO
var _speed := 400.0
var _damage := 0.0
var _pierce_left := 0
var _ricochet_left := 0
var _lifetime_left := 0.0
var _active := false
var _pool: ObjectPool
var _last_hit_enemy: Node = null

var _status: StringName = &""
var _status_power := 0.0
var _status_duration := 0.0
var _aoe_radius := 0.0
var _on_explode: Callable   # виклик у WeaponModule: створити вибух з пулу
var _on_hit: Callable       # виклик у WeaponModule: намальований спалах удару

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

## from_position/direction — звідки й куди; решта — параметри зброї
## плюс бонуси героя (шкода й пробиття вже враховують апгрейди).
func spawn(from_position: Vector2, direction: Vector2, def: WeaponDef, damage: float, pierce: int, ricochet: int, on_explode: Callable, on_hit: Callable = Callable()) -> void:
	global_position = from_position
	_direction = direction
	rotation = direction.angle()
	_speed = def.projectile_speed
	_damage = damage
	_pierce_left = pierce
	_ricochet_left = ricochet
	_lifetime_left = MAX_LIFETIME
	_last_hit_enemy = null
	_status = def.status
	_status_power = def.status_power
	_status_duration = def.status_duration
	_aoe_radius = def.aoe_radius
	_on_explode = on_explode
	_on_hit = on_hit
	sprite.color = def.color
	scale = Vector2.ONE * def.projectile_scale

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
		_return_to_pool()

func _on_body_entered(body: Node) -> void:
	if not _active or body == _last_hit_enemy or not body.has_method("take_damage"):
		return
	_last_hit_enemy = body

	# Снаряд із радіусом вибуху (метеор) шкодить не цілі, а всій зоні —
	# інакше ворог, у якого влучили, отримав би подвійну шкоду.
	if _aoe_radius > 0.0:
		if _on_explode.is_valid():
			_on_explode.call(global_position, _damage)
		_return_to_pool()
		return

	CombatQuery.hit(body, _damage, _status, _status_power, _status_duration)
	if _on_hit.is_valid():
		_on_hit.call(global_position, _direction)
	if _pierce_left > 0:
		_pierce_left -= 1
		return
	if _ricochet_left > 0 and _retarget_to_nearest_enemy(body):
		_ricochet_left -= 1
		return
	_return_to_pool()

func _retarget_to_nearest_enemy(exclude: Node) -> bool:
	var nearest := CombatQuery.nearest_enemy(get_tree(), global_position, RICOCHET_SEARCH_RADIUS, [exclude])
	if nearest == null:
		return false
	_direction = global_position.direction_to(nearest.global_position)
	rotation = _direction.angle()
	return true

func _return_to_pool() -> void:
	_pool.release(self)
