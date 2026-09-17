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

## Швидкість, з якої хода переходить у біг (для змішування анімацій).
const RUN_THRESHOLD := 3.4

@onready var model: Node3D = $Model
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var camera_pivot: Node3D = $CameraPivot

var _input_direction := Vector2.ZERO
var _facing_angle := 0.0

func _ready() -> void:
	_build_animation_tree()
	animation_tree.active = true
	_facing_angle = rotation.y

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
	var direction := _get_world_direction()

	# Розгін і гальмування: різні швидкості, щоб старт був жвавим, а
	# зупинка — не миттєвою.
	var target_speed := RUN_SPEED * clampf(direction.length(), 0.0, 1.0)
	var target_velocity := direction.normalized() * target_speed
	var rate := ACCELERATION if direction.length() > 0.05 else DECELERATION
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

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
	var camera_yaw := camera_pivot.global_rotation.y
	var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(-forward.z, 0.0, forward.x)
	return (right * input.x + forward * input.y) * input.length()

## Плавний доворот: персонаж не "телепортує" погляд, а повертається з
## обмеженою швидкістю — саме це дає відчуття живого руху на 360°.
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

## Удар мечем — програється поверх руху (окрема гілка OneShot).
func attack() -> void:
	animation_tree.set("parameters/AttackShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
