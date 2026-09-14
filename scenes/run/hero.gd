extends CharacterBody2D

## Герой. Керування — аналоговий джойстик від точки дотику: гравець
## притискає палець (або мишу — для тестів на ПК) і тягне в потрібну
## сторону, герой рухається в цьому напрямку з силою, пропорційною
## відстані відтягування. Зброя стріляє сама по найближчому ворогу.

signal died
signal xp_collected(amount: int)
signal gold_collected(amount: int)

const JOYSTICK_MAX_RADIUS := 80.0   # відстань відтягування для 100% швидкості
const JOYSTICK_DEAD_ZONE := 4.0     # менші рухи ігноруються як тремтіння пальця

@onready var hurt_box: Area2D = $HurtBox
@onready var pickup_area: Area2D = $PickupArea

var current_hp: float = Balance.HERO_MAX_HP

var _move_direction := Vector2.ZERO
var _touch_active := false
var _touch_start := Vector2.ZERO
var _invulnerable := false
var _weapon_cooldown_left := 0.0
var _projectile_pool: ObjectPool

func _ready() -> void:
	pickup_area.area_entered.connect(_on_pickup_area_entered)

func setup(projectile_pool: ObjectPool) -> void:
	_projectile_pool = projectile_pool

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		_touch_active = event.pressed
		if event.pressed:
			_touch_start = event.position
		else:
			_move_direction = Vector2.ZERO
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _touch_active:
		var offset: Vector2 = event.position - _touch_start
		var distance := offset.length()
		if distance > JOYSTICK_DEAD_ZONE:
			_move_direction = offset.normalized() * clampf(distance / JOYSTICK_MAX_RADIUS, 0.0, 1.0)
		else:
			_move_direction = Vector2.ZERO

func _physics_process(delta: float) -> void:
	velocity = _move_direction * Balance.HERO_MOVE_SPEED
	move_and_slide()
	_process_weapon(delta)
	_process_contact_damage()

func _process_weapon(delta: float) -> void:
	_weapon_cooldown_left -= delta
	if _weapon_cooldown_left > 0.0:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	_fire_at(target)
	_weapon_cooldown_left = Balance.WEAPON_COOLDOWN

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.visible:
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest

func _fire_at(target: Node2D) -> void:
	if _projectile_pool == null:
		return
	var projectile: Node = _projectile_pool.acquire()
	var direction := global_position.direction_to(target.global_position)
	projectile.spawn(global_position, direction)

## Поки герой торкається ворога і не в i-фреймах — щоразу після
## закінчення невразливості contact-урон застосовується знову.
func _process_contact_damage() -> void:
	if _invulnerable:
		return
	for body in hurt_box.get_overlapping_bodies():
		if body.has_method("get_contact_damage"):
			take_damage(body.get_contact_damage())
			break

func take_damage(amount: float) -> void:
	current_hp -= amount
	if current_hp <= 0.0:
		current_hp = 0.0
		set_physics_process(false)
		died.emit()
	else:
		_start_iframes()

func _start_iframes() -> void:
	_invulnerable = true
	modulate.a = 0.5
	await get_tree().create_timer(Balance.HERO_IFRAMES).timeout
	_invulnerable = false
	modulate.a = 1.0

func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("collect"):
		var result: Dictionary = area.collect()
		xp_collected.emit(result.xp)
		gold_collected.emit(result.gold)
