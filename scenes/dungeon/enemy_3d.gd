extends CharacterBody3D
class_name Enemy3D

## Ворог у данжі. Замовник окремо назвав три речі, які тут вирішуються:
##
## 1. НЕ ПРОХОДИТЬ КРІЗЬ СТІНИ — у ворога справжнє фізичне тіло, і рух
##    іде через move_and_slide(), а не телепортацією до героя.
## 2. НЕ ТУПИЙ І НЕ ЗАСТРЯГАЄ — шлях рахує NavigationAgent3D по карті
##    прохідності данжу. Якщо герой зайшов за ріг, ворог обходить кут,
##    а не впирається носом у стіну.
## 3. СТРІЛЕЦЬ НЕ СТРІЛЯЄ КРІЗЬ СТІНИ — перед пострілом перевіряє, чи
##    бачить героя (промінь від очей до цілі).
##
## Агро теж чесне: поки герой далеко, ворог стоїть на місці; помітив —
## починає переслідувати, і вже не губить, поки той не втече далеко.

signal died(position: Vector3, xp_reward: int)

enum Kind {MELEE, RANGED, BOSS}

const HEALTH_BAR_SCRIPT := preload("res://scenes/dungeon/health_bar_3d.gd")

## Колір смужки ворога. Бос отримує ту саму, але помітнішу.
const ENEMY_BAR_COLOR := Color(0.95, 0.25, 0.25)

const GRAVITY := 20.0
const ATTACK_ANIMATION_TIME := 0.5

@export var kind: Kind = Kind.MELEE
@export var max_hp := 30.0
@export var damage := 8.0
@export var move_speed := 2.8
@export var xp_reward := 3

## Радіус, у якому ворог помічає героя, і більший радіус, у якому вже
## не втрачає його з поля зору.
@export var aggro_range := 11.0
@export var leash_range := 24.0

@export var attack_range := 2.2
@export var attack_cooldown := 1.4

## Звідки "дивиться" стрілець, коли перевіряє видимість цілі.
@export var eye_height := 1.2

## Зріст ворога на екрані в метрах. Моделі з різних наборів приходять
## у зовсім різному масштабі (одна завбільшки з палець, інша — з
## будинок), тож приводимо кожну до потрібного розміру самі.
@export var target_height := 1.7

var current_hp := 0.0
var _player: Node3D
var _agent: NavigationAgent3D
var _model: Node3D
var _animation: AnimationPlayer
var _attack_left := 0.0
var _aggro := false
var _dying := false
var _health_bar: HealthBar3D
var _sleeping := false

func setup(player: Node3D, model_scene: PackedScene) -> void:
	_player = player
	_model = model_scene.instantiate()
	add_child(_model)
	_normalize_size()
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation = players[0]
		_loop(["Idle", "Walk", "Run", "Flying_Idle", "Fast_Flying"])
	_add_health_bar()

## Смужка висить трохи вище за голову й ширшає разом із розміром ворога:
## у боса вона має бути помітною, у дрібноти — не затуляти його самого.
func _add_health_bar() -> void:
	_health_bar = HEALTH_BAR_SCRIPT.new()
	add_child(_health_bar)
	var is_boss := kind == Kind.BOSS
	_health_bar.setup(ENEMY_BAR_COLOR, target_height + 0.45, is_boss, 1.0 if not is_boss else 1.8)

## Масштабує модель так, щоб її висота дорівнювала target_height.
##
## Габарити рахуємо у СВІТОВИХ координатах і переводимо в систему
## моделі. Локальні габарити тут не годяться: у моделей зі скелетом
## меш лежить у системі кістки, його власний розмір крихітний — і
## масштаб виходив у сотню разів більшим за потрібний.
func _normalize_size() -> void:
	var bounds := _get_model_bounds()
	if bounds.size.y <= 0.01:
		return
	var factor := target_height / bounds.size.y
	# Запобіжник на випадок дивних моделей: краще лишити як є, ніж
	# отримати ворога завбільшки з будинок.
	if factor < 0.01 or factor > 100.0:
		push_warning("Дивний масштаб моделі ворога: %f" % factor)
		return
	_model.scale = Vector3.ONE * factor
	# Модель має стояти на підлозі, а не тонути в ній.
	_model.position.y = -bounds.position.y * factor

func _get_model_bounds() -> AABB:
	var to_local := _model.global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for child in _model.find_children("*", "VisualInstance3D", true, false):
		var instance := child as VisualInstance3D
		var child_bounds: AABB = to_local * (instance.global_transform * instance.get_aabb())
		if first:
			bounds = child_bounds
			first = false
		else:
			bounds = bounds.merge(child_bounds)
	return bounds

func _ready() -> void:
	current_hp = max_hp
	_agent = NavigationAgent3D.new()
	# Ворог зупиняється трохи раніше цілі, інакше штовхає героя спиною.
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = attack_range * 0.8
	_agent.avoidance_enabled = true
	_agent.radius = 0.5
	add_child(_agent)

## Сон: ворог далеко від гравця не рахує маршрут і не ворушить
## скелетом. Анімація скелета — найдорожча річ на телефоні, а бачити
## того, хто за три кімнати звідси, все одно неможливо.
func set_sleeping(sleeping: bool) -> void:
	if _sleeping == sleeping:
		return
	_sleeping = sleeping
	set_physics_process(not sleeping)
	if _animation != null:
		_animation.active = not sleeping
	if _model != null:
		_model.visible = not sleeping

func _physics_process(delta: float) -> void:
	if _dying or _player == null:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var distance := global_position.distance_to(_player.global_position)
	_update_aggro(distance)
	_attack_left -= delta

	if _aggro:
		if kind == Kind.RANGED:
			_process_ranged(distance, delta)
		else:
			_process_melee(distance, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play("Idle")

	move_and_slide()

## Помітив — переслідує; поки не втік далеко, не забуває. Два різні
## радіуси не дають ворогові "блимати" між станами на межі агро.
func _update_aggro(distance: float) -> void:
	if not _aggro and distance <= aggro_range:
		_aggro = true
	elif _aggro and distance > leash_range:
		_aggro = false

func _process_melee(distance: float, delta: float) -> void:
	if distance > attack_range:
		_move_along_path(delta)
		return
	velocity.x = 0.0
	velocity.z = 0.0
	_face_player()
	_try_attack()

## Стрілець тримає дистанцію і б'є лише тоді, коли СПРАВДІ бачить ціль.
func _process_ranged(distance: float, delta: float) -> void:
	var can_see := _has_line_of_sight()
	if not can_see:
		# Не бачить — підходить ближче, доки не з'явиться видимість.
		_move_along_path(delta)
		return
	if distance < attack_range * 2.0:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		_move_along_path(delta)
	_face_player()
	_try_attack()

## Йде до героя МАРШРУТОМ по карті прохідності: обходить кути, стіни й
## колони замість того, щоб упиратись у них.
func _move_along_path(delta: float) -> void:
	_agent.target_position = _player.global_position
	if _agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var next_point := _agent.get_next_path_position()
	var direction := (next_point - global_position)
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	direction = direction.normalized()
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 12.0 * delta)
	_face(direction)
	_play("Walk")

## Промінь від очей ворога до грудей героя. Якщо першим трапляється
## стіна — стріляти не можна.
func _has_line_of_sight() -> bool:
	var from := global_position + Vector3.UP * eye_height
	var to := _player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	# Маска 1 — світ (стіни, колони). Героя промінь ігнорує: нас цікавить
	# саме те, чи є перешкода на шляху.
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _try_attack() -> void:
	if _attack_left > 0.0:
		return
	# Б'ємо лише те, що бачимо: інакше ворог дістає героя крізь стіну,
	# просто стоячи впритул з іншого боку.
	if not _has_line_of_sight():
		return
	_attack_left = attack_cooldown
	_play_once(["Punch", "Bite_Front", "Headbutt"])
	if kind == Kind.RANGED:
		_shoot()
	elif _player.has_method("take_damage"):
		_player.take_damage(damage)

## Постріл — миттєвий промінь: ворог уже перевірив видимість, тож
## влучання чесне й не пролітає крізь стіну.
func _shoot() -> void:
	if not _has_line_of_sight():
		return
	if _player.has_method("take_damage"):
		_player.take_damage(damage)

func take_damage(amount: float) -> void:
	if _dying:
		return
	current_hp -= amount
	_aggro = true   # вдарили — помітив, навіть якщо був далеко
	# Смужка з'являється від першого ж удару й спадає з кожним тіком.
	if _health_bar != null:
		_health_bar.set_ratio(current_hp / max_hp)
		_health_bar.flash()
	_play_once(["HitReact", "HitRecieve"])
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	_dying = true
	velocity = Vector3.ZERO
	if _health_bar != null:
		_health_bar.visible = false
	died.emit(global_position, xp_reward)
	_play_once(["Death"])
	# Даємо дограти смерть, а тоді прибираємо.
	await get_tree().create_timer(1.6).timeout
	queue_free()

func _face_player() -> void:
	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction.length() > 0.01:
		_face(direction.normalized())

func _face(direction: Vector3) -> void:
	if _model == null:
		return
	var wanted := atan2(direction.x, direction.z)
	_model.rotation.y = rotate_toward(_model.rotation.y, wanted, 10.0 * get_physics_process_delta_time())

## Анімації в різних моделей звуться по-різному, тож шукаємо за
## кількома можливими назвами.
func _play(wanted: String) -> void:
	if _animation == null:
		return
	var name := _find_animation([wanted, "Idle", "Flying_Idle"])
	if name != "" and _animation.current_animation != name:
		_animation.play(name)

func _play_once(candidates: Array) -> void:
	if _animation == null:
		return
	var name := _find_animation(candidates)
	if name != "":
		_animation.play(name)

func _find_animation(candidates: Array) -> String:
	for wanted: String in candidates:
		for name: String in _animation.get_animation_list():
			if name.get_slice("|", name.get_slice_count("|") - 1) == wanted:
				return name
	return ""

func _loop(names: Array) -> void:
	for wanted: String in names:
		var name := _find_animation([wanted])
		if name != "":
			_animation.get_animation(name).loop_mode = Animation.LOOP_LINEAR
