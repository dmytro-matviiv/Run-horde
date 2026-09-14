extends CharacterBody2D

## Ворог. Конкретний тип (стати/вигляд/поведінка) задає EnemyDef,
## переданий у spawn() — той самий вузол із пулу можна перевикористати
## під БУДЬ-ЯКИЙ тип ворога, тому форму колізії й колір спрайту щоразу
## перебудовуємо наново (новий CircleShape2D), а не мінятимемо
## існуючий ресурс — інакше зміна розлилась би на інші інстанси в
## пулі, якби Godot вирішив поділити той самий ресурс між ними.

const RANGED_ATTACK_RANGE := 220.0    # тримається на цій відстані й стріляє
const RANGED_ATTACK_COOLDOWN := 1.6
const EXPLOSION_RADIUS := 70.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Polygon2D = $Sprite

var current_hp: float
var xp_drop: int
var gold_drop: int

var _def: EnemyDef
var _hero: Node2D
var _pool: ObjectPool
var _crystal_pool: ObjectPool
var _projectile_pool: ObjectPool
var _on_death: Callable
var _active := false
var _ranged_cooldown_left := 0.0

func _ready() -> void:
	add_to_group("enemies")

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func set_crystal_pool(crystal_pool: ObjectPool) -> void:
	_crystal_pool = crystal_pool

func set_projectile_pool(projectile_pool: ObjectPool) -> void:
	_projectile_pool = projectile_pool

func spawn(spawn_position: Vector2, hero: Node2D, minute_of_run: float, on_death: Callable, def: EnemyDef) -> void:
	global_position = spawn_position
	_hero = hero
	_on_death = on_death
	_def = def
	current_hp = def.hp_base + def.hp_per_minute * minute_of_run
	xp_drop = def.xp_drop
	gold_drop = def.gold_drop
	_ranged_cooldown_left = RANGED_ATTACK_COOLDOWN * 0.5

	var shape := CircleShape2D.new()
	shape.radius = def.radius
	collision_shape.shape = shape

	sprite.color = def.color
	sprite.polygon = _make_polygon(def.radius)

## disabled міняємо через set_deferred — pool_deactivate() тут
## викликається з _die(), тобто посеред обробки фізичних колізій,
## де пряма зміна disabled падає з помилкою "flushing queries".
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
	if not _active or _hero == null:
		return
	if _def.attack_type == "ranged":
		_process_ranged(delta)
	else:
		_process_melee()

func _process_melee() -> void:
	velocity = global_position.direction_to(_hero.global_position) * _def.speed
	move_and_slide()

## Тримається на RANGED_ATTACK_RANGE від героя й періодично стріляє,
## замість того щоб іти в контактну атаку впритул.
func _process_ranged(delta: float) -> void:
	var distance := global_position.distance_to(_hero.global_position)
	if distance > RANGED_ATTACK_RANGE:
		velocity = global_position.direction_to(_hero.global_position) * _def.speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	_ranged_cooldown_left -= delta
	if _ranged_cooldown_left <= 0.0 and distance <= RANGED_ATTACK_RANGE * 1.3:
		_fire_at_hero()
		_ranged_cooldown_left = RANGED_ATTACK_COOLDOWN

func _fire_at_hero() -> void:
	if _projectile_pool == null:
		return
	var projectile: Node = _projectile_pool.acquire()
	var direction := global_position.direction_to(_hero.global_position)
	projectile.spawn(global_position, direction, _def.damage, Balance.ENEMY_PROJECTILE_SPEED)

func get_contact_damage() -> float:
	return _def.damage

func take_damage(amount: float) -> void:
	if not _active:
		return
	current_hp -= amount
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	if _on_death.is_valid():
		_on_death.call()
	if _def.explodes_on_death:
		_explode()
	if _crystal_pool != null:
		var crystal: Node = _crystal_pool.acquire()
		crystal.spawn(global_position, xp_drop, gold_drop)
	_pool.release(self)

## АоЕ-шкода герою, якщо той опинився поруч у момент смерті ворога
## (павук-підривник). Поважає i-фрейми героя, як і звичайний контакт.
func _explode() -> void:
	if _hero == null or global_position.distance_to(_hero.global_position) > EXPLOSION_RADIUS:
		return
	if _hero.has_method("is_invulnerable") and _hero.is_invulnerable():
		return
	if _hero.has_method("take_damage"):
		_hero.take_damage(_def.damage)

static func _make_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 8:
		var angle := TAU / 8.0 * i
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
