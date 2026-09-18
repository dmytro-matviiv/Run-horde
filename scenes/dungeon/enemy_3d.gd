extends CharacterBody3D
class_name Enemy3D

## Ворог у данжі.
##
## 1. НЕ ПРОХОДИТЬ КРІЗЬ СТІНИ — справжнє фізичне тіло, рух через
##    move_and_slide(), а не телепортацією до героя.
## 2. НЕ ТУПИЙ І НЕ ЗАСТРЯГАЄ — шлях рахує NavigationAgent3D по карті
##    прохідності. Зайшов за ріг — ворог обходить кут, а не стоїть носом
##    у стіну.
## 3. НЕ Б'Є Й НЕ СТРІЛЯЄ КРІЗЬ СТІНИ — перед ударом перевіряє, чи
##    бачить героя.
##
## БІЙ, ЯКИЙ МОЖНА ЧИТАТИ Й ОБІГРАВАТИ:
##  - Перед ударом ворог ЗАМАХУЄТЬСЯ: на підлозі з'являється червона
##    зона, яка заповнюється до моменту удару. Вийшов із неї чи зробив
##    перекат — удар пройшов повз.
##  - Бос кожен третій удар б'є об землю: велике коло навколо себе.
##  - Стрілець пускає видимий снаряд, від якого можна ухилитись; підійшов
##    упритул — він відступає, щоб тримати дистанцію.
##  - Удар героя відкидає ворога, а сильний (удар ногою, вихор) ще й
##    збиває замах — агресивна гра винагороджується.
##
## ЕКОНОМІЯ НА СЛАБКИХ ТЕЛЕФОНАХ (гравцеві непомітна): маршрут і
## видимість рахуються кілька разів на секунду з розсинхроном між
## ворогами; анімація поза кадром на паузі, удалині — через кадр; ворог
## без діла не рахує фізику руху.

signal died(position: Vector3, xp_reward: int)

enum Kind {MELEE, RANGED, BOSS}

const HEALTH_BAR_SCRIPT := preload("res://scenes/dungeon/health_bar_3d.gd")

## Колір смужки ворога. Бос отримує ту саму, але помітнішу.
const ENEMY_BAR_COLOR := Color(0.95, 0.25, 0.25)
const TELEGRAPH_COLOR := Color(1.0, 0.22, 0.15, 0.85)
const SLAM_COLOR := Color(1.0, 0.45, 0.1, 0.9)
const HIT_COLOR := Color(1.0, 0.95, 0.8)
const HEAVY_HIT_COLOR := Color(1.0, 0.65, 0.25)

const GRAVITY := 20.0

const REPATH_INTERVAL := 0.3
const SIGHT_INTERVAL := 0.2

## Як швидко гасне відкидання (м/с за секунду).
const KNOCKBACK_DECAY := 28.0

## Замах: скільки секунд від початку до удару. Саме стільки гравець має,
## щоб вийти з червоної зони.
const MELEE_WINDUP := 0.55
const RANGED_WINDUP := 0.5
const BOSS_WINDUP := 0.75
const SLAM_WINDUP := 1.0
const SLAM_RADIUS := 3.6
const SLAM_EVERY := 3

## Під час замаху ворог повільно довертається за героєм — достатньо, щоб
## влучити в того, хто стоїть, але не в того, хто відскочив убік.
const WINDUP_TURN_SPEED := 2.5

## Стрілець тримається не ближче за це.
const RANGED_MIN_DISTANCE := 3.5

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
## у зовсім різному масштабі, тож приводимо кожну до потрібного розміру.
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

var _repath_left := 0.0
var _sight_left := 0.0
var _can_see := false
var _on_screen := true
var _animation_step := 1
var _animation_frame := 0
var _animation_time := 0.0
var _animation_cache: Dictionary = {}

var _knockback := Vector3.ZERO
var _stagger_left := 0.0
var _windup_left := 0.0
var _windup_total := 0.0
var _windup_slam := false
var _attack_counter := 0
var _telegraph: MeshInstance3D
var _charging_shot: EnemyProjectile

func setup(player: Node3D, model_scene: PackedScene) -> void:
	_player = player
	_model = model_scene.instantiate()
	add_child(_model)
	_normalize_size()
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation = players[0]
		_loop(["Idle", "Walk", "Run", "Flying_Idle", "Fast_Flying"])
		# Анімацію крутимо самі (див. _process): так її можна оновлювати
		# рідше або ставити на паузу, коли ворога не видно.
		_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_add_health_bar()
	_add_screen_notifier()

func is_alive() -> bool:
	return not _dying

## Смужка висить трохи вище за голову й ширшає разом із розміром ворога.
func _add_health_bar() -> void:
	_health_bar = HEALTH_BAR_SCRIPT.new()
	add_child(_health_bar)
	var is_boss := kind == Kind.BOSS
	_health_bar.setup(ENEMY_BAR_COLOR, target_height + 0.45, is_boss, 1.0 if not is_boss else 1.8)

## Масштабує модель так, щоб її висота дорівнювала target_height.
##
## Габарити рахуємо у СВІТОВИХ координатах і переводимо в систему
## моделі: у моделей зі скелетом меш лежить у системі кістки, його
## власний розмір крихітний — і масштаб виходив у сотню разів більшим.
func _normalize_size() -> void:
	var bounds := _get_model_bounds()
	if bounds.size.y <= 0.01:
		return
	var factor := target_height / bounds.size.y
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

## Відеокарта й так знає, що потрапляє в кадр; цей вузол просто
## повідомляє нам про це — безкоштовно.
func _add_screen_notifier() -> void:
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-0.8, 0.0, -0.8), Vector3(1.6, target_height + 0.6, 1.6))
	notifier.screen_entered.connect(func() -> void: _on_screen = true)
	notifier.screen_exited.connect(func() -> void: _on_screen = false)
	add_child(notifier)

func _ready() -> void:
	add_to_group(&"enemies")
	current_hp = max_hp
	_agent = NavigationAgent3D.new()
	# Ворог зупиняється трохи раніше цілі, інакше штовхає героя спиною.
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = attack_range * 0.8
	# Взаємне розштовхування агентів (avoidance) вимкнене: воно рахується
	# щокадру для кожного ворога, а результат нам не потрібен.
	_agent.avoidance_enabled = false
	_agent.radius = 0.5
	add_child(_agent)
	# Різний зсув у кожного: вороги не рахують маршрут усі в один кадр.
	_repath_left = randf() * REPATH_INTERVAL
	_sight_left = randf() * SIGHT_INTERVAL

## Сон: далекий ворог не рахує маршрут і не ворушить скелетом.
func set_sleeping(sleeping: bool) -> void:
	if _sleeping == sleeping:
		return
	_sleeping = sleeping
	set_physics_process(not sleeping)
	set_process(not sleeping)
	if _model != null:
		_model.visible = not sleeping

## 1 — анімація щокадру, 2 — через кадр і т.д. Задає данж за відстанню.
func set_animation_step(step: int) -> void:
	_animation_step = maxi(step, 1)

func _process(delta: float) -> void:
	if _animation == null:
		return
	_animation_time += delta
	# Невидимий ворог анімацію не рахує: час накопичується й "доганяється"
	# одним кроком, щойно він з'явиться в кадрі.
	if not _on_screen:
		return
	_animation_frame += 1
	if _animation_frame % _animation_step != 0:
		return
	_animation.advance(_animation_time)
	_animation_time = 0.0

func _physics_process(delta: float) -> void:
	if _dying or _player == null:
		return

	var distance := global_position.distance_to(_player.global_position)
	_update_aggro(distance)
	_attack_left -= delta
	_repath_left -= delta
	_sight_left -= delta
	_stagger_left = maxf(_stagger_left - delta, 0.0)

	# Стоїть без діла на підлозі — рухати нічого, фізику не рахуємо.
	if not _aggro and is_on_floor() and velocity.is_zero_approx() and _knockback.is_zero_approx():
		_play("Idle")
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if _windup_left > 0.0:
		_process_windup(delta)
	elif _stagger_left > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	elif _aggro:
		if kind == Kind.RANGED:
			_process_ranged(distance, delta)
		else:
			_process_melee(distance, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play("Idle")

	# Відкидання від удару героя накладається поверх власного руху.
	velocity.x += _knockback.x
	velocity.z += _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)

	move_and_slide()

	velocity.x -= _knockback.x
	velocity.z -= _knockback.z

## Помітив — переслідує; поки не втік далеко, не забуває.
func _update_aggro(distance: float) -> void:
	if not _aggro and distance <= aggro_range:
		_aggro = true
		_repath_left = 0.0   # помітив — одразу прокладає маршрут
	elif _aggro and distance > leash_range:
		_aggro = false

func _process_melee(distance: float, delta: float) -> void:
	# Далеко — або близько, але між нами стіна: іде маршрутом в обхід.
	if distance > attack_range or not _sees_player():
		_move_along_path(delta)
		return
	velocity.x = 0.0
	velocity.z = 0.0
	_face_player(10.0)
	_try_begin_windup()

## Стрілець тримає дистанцію: не бачить — підходить, задалеко —
## підходить, упритул — відступає. Стріляє лише тоді, коли бачить.
func _process_ranged(distance: float, delta: float) -> void:
	if not _sees_player() or distance > attack_range:
		_move_along_path(delta)
		return
	if distance < RANGED_MIN_DISTANCE:
		var away := global_position - _player.global_position
		away.y = 0.0
		away = away.normalized()
		velocity.x = move_toward(velocity.x, away.x * move_speed, 12.0 * delta)
		velocity.z = move_toward(velocity.z, away.z * move_speed, 12.0 * delta)
		_play("Walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_face_player(10.0)
	_try_begin_windup()

## Іде до героя МАРШРУТОМ по карті прохідності.
func _move_along_path(delta: float) -> void:
	if _repath_left <= 0.0:
		_repath_left = REPATH_INTERVAL
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
	_face(direction, 10.0)
	_play("Walk")

## Видимість героя з кешем: промінь кілька разів на секунду.
func _sees_player() -> bool:
	if _sight_left <= 0.0:
		_sight_left = SIGHT_INTERVAL
		_can_see = _has_line_of_sight()
	return _can_see

## Промінь від очей ворога до грудей героя. Якщо першим трапляється
## стіна — бачити не можна.
func _has_line_of_sight() -> bool:
	var from := global_position + Vector3.UP * eye_height
	var to := _player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	# Маска 1 — світ (стіни, колони).
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

# --- замах і удар ---

## Замахується лише тоді, коли вже повернувся до героя: спершу
## розвернутись, потім бити — а не махати в інший бік.
func _try_begin_windup() -> void:
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() > 0.3 and _model_forward().angle_to(offset.normalized()) > deg_to_rad(35.0):
		return
	_begin_windup()

func _begin_windup() -> void:
	if _attack_left > 0.0 or _windup_left > 0.0:
		return
	if not _has_line_of_sight():
		return
	_attack_counter += 1
	_windup_slam = kind == Kind.BOSS and _attack_counter % SLAM_EVERY == 0
	match kind:
		Kind.RANGED:
			_windup_total = RANGED_WINDUP
		Kind.BOSS:
			_windup_total = SLAM_WINDUP if _windup_slam else BOSS_WINDUP
		_:
			_windup_total = MELEE_WINDUP
	_windup_left = _windup_total
	velocity.x = 0.0
	velocity.z = 0.0
	_play_once(["Punch", "Bite_Front", "Headbutt", "Weapon"])

	if kind == Kind.RANGED:
		# Снаряд "набухає" в руці — це і є попередження для гравця.
		_charging_shot = EnemyProjectile.create(damage)
		add_child(_charging_shot)
		_charging_shot.position = Vector3(0, target_height * 0.7, 0) + _model_forward() * 0.6
		return

	if _windup_slam:
		_show_telegraph(SLAM_RADIUS, PI, SLAM_COLOR)
	else:
		_show_telegraph(_melee_reach(), deg_to_rad(55.0), TELEGRAPH_COLOR)

func _process_windup(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_windup_left -= delta
	if not _windup_slam:
		_face_player(WINDUP_TURN_SPEED)
	var progress := 1.0 - _windup_left / _windup_total
	if _telegraph != null:
		_telegraph.rotation.y = _model.rotation.y
		_telegraph.set_instance_shader_parameter(&"progress", progress)
	if _charging_shot != null and is_instance_valid(_charging_shot):
		_charging_shot.set_charge(progress)
		_charging_shot.position = Vector3(0, target_height * 0.7, 0) + _model_forward() * 0.6
	if _windup_left <= 0.0:
		_resolve_attack()

func _resolve_attack() -> void:
	_windup_left = 0.0
	_attack_left = attack_cooldown
	_hide_telegraph()
	if kind == Kind.RANGED:
		_release_shot()
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if _windup_slam:
		CombatVfx.shockwave(get_parent(), global_position, SLAM_RADIUS, SLAM_COLOR, 0.35)
		var rig := get_tree().get_first_node_in_group(&"camera_rig")
		if rig != null:
			rig.shake(0.22)
		if offset.length() <= SLAM_RADIUS + 0.3:
			_player.take_damage(damage * 1.5)
		return
	# Звичайний удар влучає, лише якщо герой досі в червоній зоні.
	var in_reach := offset.length() <= _melee_reach() + 0.35
	var in_front := offset.length() < 0.5 or _model_forward().angle_to(offset.normalized()) <= deg_to_rad(65.0)
	if in_reach and in_front and _has_line_of_sight():
		_player.take_damage(damage)

func _release_shot() -> void:
	if _charging_shot == null or not is_instance_valid(_charging_shot):
		return
	var shot := _charging_shot
	_charging_shot = null
	var target := _player.global_position + Vector3.UP * 1.0
	shot.launch(target - shot.global_position, _player)

## Замах збито: сильний удар героя перериває ворога.
func _cancel_windup() -> void:
	_windup_left = 0.0
	_hide_telegraph()
	if _charging_shot != null and is_instance_valid(_charging_shot):
		_charging_shot.queue_free()
	_charging_shot = null
	_attack_left = maxf(_attack_left, attack_cooldown * 0.5)

func _melee_reach() -> float:
	return attack_range * 1.15 + 0.3

func _show_telegraph(radius: float, half_arc: float, color: Color) -> void:
	_hide_telegraph()
	_telegraph = CombatVfx.make_ground_marker(color, radius, half_arc)
	add_child(_telegraph)
	_telegraph.position = Vector3(0, 0.05, 0)
	_telegraph.rotation.y = _model.rotation.y

func _hide_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null

# --- отримання шкоди ---

## Удар героя. knockback — напрямок і сила відкидання, heavy — сильний
## удар, що збиває замах.
func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, crit: bool = false, heavy: bool = false) -> void:
	if _dying:
		return
	current_hp -= amount
	if not _aggro:
		_repath_left = 0.0
	_aggro = true   # вдарили — помітив, навіть якщо був далеко
	if _health_bar != null:
		_health_bar.set_ratio(current_hp / max_hp)
		_health_bar.flash()

	var parent := get_parent()
	var chest := global_position + Vector3.UP * target_height * 0.55
	CombatVfx.impact(parent, chest, HEAVY_HIT_COLOR if heavy or crit else HIT_COLOR, heavy or crit)
	CombatVfx.damage_number(parent, global_position + Vector3.UP * (target_height + 0.35), amount, crit)
	CombatVfx.flash_model(_model, Color.WHITE, 0.09)

	# Бос важкий: його майже не зрушити й лише сильним ударом збити замах.
	var is_boss := kind == Kind.BOSS
	_knockback = knockback * (0.25 if is_boss else 1.0)
	if heavy or not is_boss:
		if heavy:
			_cancel_windup()
		_stagger_left = maxf(_stagger_left, (0.45 if heavy else 0.15) * (0.5 if is_boss else 1.0))

	if _windup_left <= 0.0:
		_play_once(["HitReact", "HitRecieve"])
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	_dying = true
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_cancel_windup()
	remove_from_group(&"enemies")
	if _health_bar != null:
		_health_bar.visible = false
	# Мертвий ворог більше не заступає дорогу.
	collision_layer = 0
	died.emit(global_position, xp_reward)
	_play_once(["Death"])
	# Даємо дограти смерть, а тоді прибираємо. Таймер стоїть на паузі
	# разом із грою, і прив'язаний до самого ворога: якщо той зникне
	# раніше (гравець вийшов з данжу), виклик просто не відбудеться.
	get_tree().create_timer(1.6, false).timeout.connect(queue_free)

# --- поворот і анімації ---

func _model_forward() -> Vector3:
	var angle := _model.rotation.y
	return Vector3(sin(angle), 0.0, cos(angle))

func _face_player(speed: float) -> void:
	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction.length() > 0.01:
		_face(direction.normalized(), speed)

func _face(direction: Vector3, speed: float) -> void:
	if _model == null:
		return
	var wanted := atan2(direction.x, direction.z)
	_model.rotation.y = rotate_toward(_model.rotation.y, wanted, speed * get_physics_process_delta_time())

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

## Назви шукаються один раз і запам'ятовуються: _play викликається
## щокадру, і перебирати рядки кожного разу — марна робота.
func _find_animation(candidates: Array) -> String:
	var key := ",".join(candidates)
	if _animation_cache.has(key):
		return _animation_cache[key]
	var found := _search_animation(candidates)
	_animation_cache[key] = found
	return found

func _search_animation(candidates: Array) -> String:
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
