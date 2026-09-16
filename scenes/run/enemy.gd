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
## Спрайт ворога малюємо трохи більшим за його фізичний радіус:
## крила, зброя й шолом виходять за межі кола зіткнень.
const ART_SIZE_FACTOR := 3.4

@onready var sprite: Polygon2D = $Sprite
@onready var art: Sprite2D = $Art

var current_hp: float
var xp_drop: int
var gold_drop: int

var _def: EnemyDef
var _hero: Node2D
var _pool: ObjectPool
var _crystal_pool: ObjectPool
var _projectile_pool: ObjectPool
var _on_death: Callable
var _on_damage: Callable
var _active := false
var _ranged_cooldown_left := 0.0

# Статус-ефекти (StatusEffects): id -> {"power": float, "left": float}.
# Отрута й горіння шкодять щосекунди, сповільнення ріже швидкість,
# мітка збільшує отриману шкоду. Все разом дає гравцю видимий
# зворотний зв'язок: підсвічений ворог = на ньому щось висить.
var _statuses: Dictionary = {}
var _dot_tick_left := 0.0

func _ready() -> void:
	add_to_group("enemies")

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func set_crystal_pool(crystal_pool: ObjectPool) -> void:
	_crystal_pool = crystal_pool

func set_projectile_pool(projectile_pool: ObjectPool) -> void:
	_projectile_pool = projectile_pool

func spawn(spawn_position: Vector2, hero: Node2D, minute_of_run: float, on_death: Callable, def: EnemyDef, on_damage: Callable) -> void:
	global_position = spawn_position
	_hero = hero
	_on_death = on_death
	_on_damage = on_damage
	_def = def
	current_hp = def.hp_base + def.hp_per_minute * minute_of_run
	xp_drop = def.xp_drop
	gold_drop = def.gold_drop
	_ranged_cooldown_left = RANGED_ATTACK_COOLDOWN * 0.5
	_statuses.clear()
	_dot_tick_left = 0.0
	modulate = Color.WHITE

	var shape := CircleShape2D.new()
	shape.radius = def.radius
	collision_shape.shape = shape

	sprite.color = def.color
	sprite.polygon = _make_polygon(def.radius)
	_apply_art(def)

## Один і той самий вузол із пулу щоразу грає іншого ворога, тому
## картинку (або її відсутність) переставляємо на кожен спавн.
func _apply_art(def: EnemyDef) -> void:
	if def.texture == null:
		art.visible = false
		sprite.visible = true
		return
	art.texture = def.texture
	art.scale = Vector2.ONE * (def.radius * ART_SIZE_FACTOR / float(def.texture.get_height()))
	art.visible = true
	sprite.visible = false

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
	_process_statuses(delta)
	if not _active:
		return   # згорів/отруївся на цьому кадрі — вже в пулі
	if _def.attack_type == "ranged":
		_process_ranged(delta)
	else:
		_process_melee()

func _process_melee() -> void:
	velocity = global_position.direction_to(_get_chase_position()) * get_move_speed()
	move_and_slide()

## Коли асасин у димовій завісі, вороги його не бачать і біжать туди,
## де бачили востаннє, — саме це робить завісу помітною для гравця.
func _get_chase_position() -> Vector2:
	if _hero.has_method("is_stealthed") and _hero.is_stealthed():
		return _hero.get_last_seen_position()
	return _hero.global_position

## Вішає статус-ефект. Повторне накладання не додається, а поновлює
## тривалість і лишає сильніший ефект — інакше десяток снарядів
## складався б у нездоланну отруту.
func apply_status(id: StringName, power: float, duration: float) -> void:
	if id == &"" or duration <= 0.0:
		return
	var current: Dictionary = _statuses.get(id, {"power": 0.0, "left": 0.0})
	_statuses[id] = {
		"power": maxf(current.power, power),
		"left": maxf(current.left, duration),
	}
	_update_status_tint()

func has_status(id: StringName) -> bool:
	return _statuses.has(id)

## Швидкість з урахуванням сповільнення (0.5 = -50%).
func get_move_speed() -> float:
	var slow: float = _statuses.get(StatusEffects.SLOW, {}).get("power", 0.0)
	return _def.speed * (1.0 - clampf(slow, 0.0, 0.85))

func _process_statuses(delta: float) -> void:
	if _statuses.is_empty():
		return
	var expired: Array = []
	for id in _statuses:
		_statuses[id].left -= delta
		if _statuses[id].left <= 0.0:
			expired.append(id)
	for id in expired:
		_statuses.erase(id)
	if not expired.is_empty():
		_update_status_tint()

	# Шкода від отрути/горіння — раз на секунду, а не щокадру: так
	# числа в балансі читаються як "шкода за секунду".
	_dot_tick_left -= delta
	if _dot_tick_left > 0.0:
		return
	_dot_tick_left = 1.0
	var dot := 0.0
	for id in [StatusEffects.POISON, StatusEffects.BURN]:
		dot += _statuses.get(id, {}).get("power", 0.0)
	if dot > 0.0:
		take_damage(dot)

func _update_status_tint() -> void:
	modulate = StatusEffects.get_tint(_statuses.keys())

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
	# Мітка (коса асасина) робить ворога вразливішим — множник тут,
	# щоб діяв на будь-яке джерело шкоди, а не лише на зброю.
	var mark: float = _statuses.get(StatusEffects.MARK, {}).get("power", 0.0)
	var final_damage := amount * (1.0 + mark)
	AudioManager.play(&"hit")
	if _on_damage.is_valid():
		_on_damage.call(final_damage)
	current_hp -= final_damage
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	AudioManager.play(&"enemy_death")
	if _on_death.is_valid():
		_on_death.call(global_position)
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
