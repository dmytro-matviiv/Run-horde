extends CharacterBody3D

## Герой у 3D-світі. Головні вимоги замовника — плавність:
##
## 1. Рух у будь-якому напрямку (360°), а не по вісьмох напрямках.
## 2. Персонаж ПЛАВНО довертається в бік руху, а не клацає між позами.
## 3. Анімації переливаються одна в одну (стоїть -> іде -> біжить), а не
##    перемикаються ривком. За це відповідає AnimationTree: він змішує
##    сусідні анімації за швидкістю, тож перехід непомітний.
##
## Керування камеро-відносне: "вперед" — це вперед відносно камери, як у
## всіх сучасних іграх від третьої особи.

const WALK_SPEED := 2.6
const RUN_SPEED := 5.4
const ACCELERATION := 14.0      # як швидко набирає швидкість
const DECELERATION := 18.0      # як швидко спиняється
const ROTATION_SPEED := 12.0    # як швидко довертається в бік руху
const GRAVITY := 22.0

## Бій. Удар б'є по дузі перед героєм — саме так читається замах мечем.
const ATTACK_RANGE := 2.6
const ATTACK_ARC_DEG := 120.0
const ATTACK_COOLDOWN := 0.55
const BASE_DAMAGE := 14.0
const BASE_MAX_HP := 100.0

const HEALTH_BAR_SCRIPT := preload("res://scenes/dungeon/health_bar_3d.gd")

## Зелена смужка — для своїх: героя й дружніх NPC. На відміну від
## ворожої, вона видима завжди.
const ALLY_BAR_COLOR := Color(0.35, 0.9, 0.4)
const BAR_HEIGHT := 2.1

## Швидкість, з якої хода переходить у біг (для змішування анімацій).
const RUN_THRESHOLD := 3.4

@onready var model: Node3D = $Model
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var camera_pivot: Node3D = $CameraPivot

signal died
signal health_changed(current: float, maximum: float)

var _input_direction := Vector2.ZERO
var _facing_angle := 0.0

var max_hp := BASE_MAX_HP
var current_hp := BASE_MAX_HP
var _damage := BASE_DAMAGE
var _speed_bonus := 0.0
var _attack_left := 0.0
var _dead := false
var _regen_per_second := 0.0
var _health_bar: HealthBar3D

func _ready() -> void:
	_build_animation_tree()
	animation_tree.active = true
	_facing_angle = rotation.y
	_health_bar = HEALTH_BAR_SCRIPT.new()
	add_child(_health_bar)
	_health_bar.setup(ALLY_BAR_COLOR, BAR_HEIGHT, true)

## Дерево анімацій будуємо кодом, а не мишкою в редакторі: так видно
## увесь набір станів в одному місці, і його легко переносити на інших
## персонажів — у моделей Quaternius анімації звуться однаково.
##
## Влаштоване так: BlendSpace1D "Move" плавно переливає спокій -> ходу ->
## біг за швидкістю, а OneShot "AttackShot" накладає зверху удар мечем,
## не перериваючи руху.
func _build_animation_tree() -> void:
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	animation_tree.anim_player = animation_tree.get_path_to(player)
	_make_looping(player, ["CharacterArmature|Idle", "CharacterArmature|Walk", "CharacterArmature|Run"])

	var move := AnimationNodeBlendSpace1D.new()
	move.min_space = 0.0
	move.max_space = 2.0
	move.add_blend_point(_animation_node("CharacterArmature|Idle"), 0.0)
	move.add_blend_point(_animation_node("CharacterArmature|Walk"), 1.0)
	move.add_blend_point(_animation_node("CharacterArmature|Run"), 2.0)

	var attack := AnimationNodeOneShot.new()
	attack.fadein_time = 0.1
	attack.fadeout_time = 0.2

	var tree := AnimationNodeBlendTree.new()
	tree.add_node(&"Move", move, Vector2(0, 0))
	tree.add_node(&"Slash", _animation_node("CharacterArmature|Sword_Slash"), Vector2(0, 160))
	tree.add_node(&"AttackShot", attack, Vector2(320, 60))
	tree.connect_node(&"AttackShot", 0, &"Move")
	tree.connect_node(&"AttackShot", 1, &"Slash")
	tree.connect_node(&"output", 0, &"AttackShot")
	animation_tree.tree_root = tree

func _animation_node(animation_name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation_name
	return node

## Хода, біг і спокій мають крутитись по колу; імпорт glTF за
## замовчуванням лишає їх одноразовими.
func _make_looping(player: AnimationPlayer, names: Array) -> void:
	for name: String in names:
		if player.has_animation(name):
			player.get_animation(name).loop_mode = Animation.LOOP_LINEAR

## Напрямок від джойстика або клавіатури: (0,0) — стоїмо.
## Приймаємо ззовні, щоб той самий герой працював і з екранним
## джойстиком на телефоні, і з клавіатурою на ПК.
func set_move_input(direction: Vector2) -> void:
	_input_direction = direction

func _physics_process(delta: float) -> void:
	_attack_left -= delta
	if _dead:
		return
	var direction := _get_world_direction()

	# Розгін і гальмування: різні швидкості, щоб старт був жвавим, а
	# зупинка — не миттєвою.
	var target_speed := RUN_SPEED * (1.0 + _speed_bonus) * clampf(direction.length(), 0.0, 1.0)
	var target_velocity := direction.normalized() * target_speed
	var rate := ACCELERATION if direction.length() > 0.05 else DECELERATION
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if _regen_per_second > 0.0 and current_hp > 0.0:
		current_hp = minf(current_hp + _regen_per_second * delta, max_hp)
		_update_health_bar()
		health_changed.emit(current_hp, max_hp)

	move_and_slide()
	_update_facing(direction, delta)
	_update_animation()

## Напрямок руху у світових координатах: клавіші/джойстик дають напрямок
## відносно ЕКРАНА, а рухатись треба відносно камери.
func _get_world_direction() -> Vector3:
	var input := _input_direction
	# "Вгору" на клавіатурі = вперед від камери, тобто -Y у цій системі.
	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	if keyboard != Vector2.ZERO:
		input = keyboard
	if input == Vector2.ZERO:
		return Vector3.ZERO

	# "Вперед" для камери — це -Z (так влаштований Godot), тому вектор
	# від'ємний: інакше герой іде рівно в протилежний бік.
	#
	# Кут беремо з АКТИВНОЇ камери, а не з окремого вузла: камера тепер
	# обертається (пальцем на телефоні, мишею на ПК або сама за рухом),
	# і "вперед" має рахуватись від того, що гравець бачить.
	var camera_yaw := _get_camera_yaw()
	var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(-forward.z, 0.0, forward.x)
	return (right * input.x + forward * input.y) * input.length()

## Плавний доворот: персонаж не "телепортує" погляд, а повертається з
## обмеженою швидкістю — саме це дає відчуття живого руху на 360°.
## Кут активної камери; поки її немає (наприклад, у тестах) — нуль.
func _get_camera_yaw() -> float:
	var camera := get_viewport().get_camera_3d()
	return 0.0 if camera == null else camera.global_rotation.y

## Куди герой зараз біжить — цим користується камера, щоб плавно
## заходити йому за спину.
func get_move_yaw() -> float:
	return atan2(velocity.x, velocity.z)

func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.6

func _update_facing(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.05:
		return
	var wanted := atan2(direction.x, direction.z)
	_facing_angle = rotate_toward(_facing_angle, wanted, ROTATION_SPEED * delta)
	model.rotation.y = _facing_angle

## Швидкість -> положення в дереві анімацій. 0 — стоїть, 1 — хода,
## 2 — біг; проміжні значення AnimationTree змішує сам.
func _update_animation() -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var blend := 0.0
	if speed > 0.05:
		blend = remap(speed, 0.0, WALK_SPEED, 0.0, 1.0) if speed <= WALK_SPEED \
			else remap(speed, WALK_SPEED, RUN_SPEED, 1.0, 2.0)
	animation_tree.set("parameters/Move/blend_position", clampf(blend, 0.0, 2.0))

## Удар мечем: анімація поверх руху (гілка OneShot) плюс сама шкода —
## по всіх ворогах у дузі перед героєм.
func attack() -> void:
	if _dead or _attack_left > 0.0:
		return
	_attack_left = ATTACK_COOLDOWN
	animation_tree.set("parameters/AttackShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_hit_enemies_in_arc()

## Шукаємо ворогів кулею навколо героя й лишаємо тих, хто справді
## попереду: удар мечем не має діставати тих, хто за спиною.
func _hit_enemies_in_arc() -> void:
	var shape := SphereShape3D.new()
	shape.radius = ATTACK_RANGE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position + Vector3.UP)
	query.collision_mask = 4          # шар ворогів
	query.collide_with_bodies = true

	var forward := Vector3(sin(_facing_angle), 0.0, cos(_facing_angle))
	var half_arc := deg_to_rad(ATTACK_ARC_DEG) * 0.5
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body: Variant = hit.get("collider")
		if body == null or not body.has_method("take_damage"):
			continue
		var to_enemy: Vector3 = body.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() > 0.01 and forward.angle_to(to_enemy.normalized()) <= half_arc:
			body.take_damage(_damage)

func take_damage(amount: float) -> void:
	if _dead:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		_dead = true
		velocity = Vector3.ZERO
		died.emit()

## Здібності з вибору на рівні. Ідентифікатори ті самі, що й у
## 2D-частині гри, тож окремого списку заводити не довелось.
func apply_ability(id: StringName) -> void:
	match id:
		&"weapon_damage":
			_damage *= 1.25
		&"weapon_cooldown", &"weapon_multishot":
			_attack_left = 0.0
			_damage *= 1.1
		&"move_speed":
			_speed_bonus += 0.12
		&"max_hp":
			max_hp += 25.0
			current_hp += 25.0
		&"regen":
			_regen_per_second += 1.0
		_:
			# Невідома здібність — просто невелике посилення, щоб вибір
			# ніколи не був порожнім.
			_damage *= 1.08
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)

func _update_health_bar() -> void:
	if _health_bar != null:
		_health_bar.set_ratio(current_hp / max_hp)
