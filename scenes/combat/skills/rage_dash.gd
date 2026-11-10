extends HeroSkill3D

## РИВОК ЛЮТІ — Клинкова Вартова, друга кнопка (ульта).
##
## Заряджається ЛЮТТЮ (пасивка Rage): шкала повільно наповнюється сама, а
## удари по ворогах наповнюють її значно швидше. Повна — вартова кидається
## на НАЙБЛИЖЧОГО ворога (або на ціль, яку вже б'є), зупиняється перед ним
## і б'є клинком знизу вгору: ціль отримує повну шкоду, сусіди — частину,
## усіх розкидає. Крізь стіни не летить: ривок закінчується перед стіною.
## Ворогів поруч нема — короткий ривок уперед. Під час ривка невразлива,
## після — кілька секунд б'є швидше.

const RANGE := 10.0
const SPEED := 17.0
## Наскільки не долітати до ворога (плюс його власний радіус).
const STOP_GAP := 0.8
const NO_TARGET_DISTANCE := 3.5
const WALL_GAP := 0.6
const DAMAGE := 2.6
const PATH_DAMAGE := 0.8
const PATH_RADIUS := 1.3
const SPLASH_RADIUS := 2.4
const SPLASH_SHARE := 0.5
const STRIKE_REACH := 3.2
const KNOCKBACK := 6.0
const FURY_TIME := 4.0
const FURY_ATTACK_SPEED := 1.3
const RAGE_COLOR := Color(1.0, 0.5, 0.2)

var _dash_left := -1.0
var _target: Enemy3D
var _hit_ids: Array = []

func _init() -> void:
	id = &"rage_dash"
	title = "Ривок"
	description = "Шкала люті повна — ривок у найближчого ворога й удар клинком: ціль і сусіди отримують шкоду, вартова невразлива й потім б'є швидше."
	color = RAGE_COLOR
	icon_kind = "dash"
	cooldown = 0.6   # лише щоб не спрацювало двічі за один дотик

## Кнопка світиться не за таймером, а за люттю.
func get_charge(player: Node) -> float:
	var passive: HeroPassive3D = player.passive
	return passive.get_charge() if passive != null else -1.0

func _use(player: Node) -> bool:
	var passive: HeroPassive3D = player.passive
	if passive == null or passive.get_charge() < 1.0:
		return false
	passive.consume_charge()
	_target = _pick_target(player)
	var direction: Vector3 = player.facing_vector()
	var distance := NO_TARGET_DISTANCE
	if _target != null:
		var offset: Vector3 = _target.global_position - player.global_position
		offset.y = 0.0
		direction = offset.normalized() if offset.length() > 0.05 else direction
		distance = maxf(offset.length() - STOP_GAP - _target.body_radius(), 0.0)
	# "Таран" із походу робить ривок довшим і болючішим.
	distance = _clear_distance(player, direction, distance * (1.0 + (player.dash_power() - 1.0) * 0.3))
	var time := maxf(distance / SPEED, 0.08)
	_dash_left = time
	_hit_ids.clear()
	if _target != null:
		_hit_ids.append(_target.get_instance_id())
	player.face_direction(direction)
	player.dash(direction, distance / time, time)
	player.play_dash_strike(time)
	player.grant_invulnerable(time + 0.3)
	player.add_attack_speed(FURY_ATTACK_SPEED, FURY_TIME)
	var parent: Node = player.get_parent()
	# Поштовх з місця — пил з-під ніг (не вогняне коло).
	Fx.puff(parent, player.global_position + Vector3.UP * 0.25, Color(0.8, 0.75, 0.68), 1.0)
	player.shake_camera(0.08)
	return true

## Ціль: та, яку вартова вже б'є (якщо поруч), інакше — найближчий ворог,
## якого видно.
func _pick_target(player: Node) -> Enemy3D:
	var current: Variant = player.get("_target")
	if is_instance_valid(current) and current is Enemy3D and (current as Enemy3D).is_aim_target():
		var offset: Vector3 = (current as Enemy3D).global_position - player.global_position
		offset.y = 0.0
		if offset.length() <= RANGE:
			return current
	var best: Enemy3D = null
	var best_distance := RANGE + 1.0
	for enemy: Enemy3D in player.enemies_in_radius(RANGE, true):
		if not enemy.is_aim_target():
			continue
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		if offset.length() < best_distance:
			best_distance = offset.length()
			best = enemy
	return best

## Скільки можна пролетіти, не врізавшись у стіну.
func _clear_distance(player: Node, direction: Vector3, distance: float) -> float:
	var from: Vector3 = player.global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * (distance + WALL_GAP), 1)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return distance
	return maxf(from.distance_to(hit.position) - WALL_GAP, 0.0)

## Поки летить — зачіпає тих, крізь кого пробігла; долетіла — удар.
func _update(player: Node, delta: float) -> void:
	if _dash_left < 0.0:
		return
	_dash_left -= delta
	for enemy: Enemy3D in player.enemies_in_radius(PATH_RADIUS, false):
		if _hit_ids.has(enemy.get_instance_id()):
			continue
		_hit_ids.append(enemy.get_instance_id())
		var push: Vector3 = enemy.global_position - player.global_position
		push.y = 0.0
		player.deal_damage(enemy, PATH_DAMAGE * player.dash_power(), push.normalized() * 2.0, false, id)
	if _dash_left <= 0.0:
		_dash_left = -1.0
		_strike(player)

func _strike(player: Node) -> void:
	var parent: Node = player.get_parent()
	var forward: Vector3 = player.facing_vector()
	var center: Vector3 = player.global_position + forward * 1.0
	var power: float = player.dash_power()
	if _target != null and is_instance_valid(_target) and _target.is_alive():
		var offset: Vector3 = _target.global_position - player.global_position
		offset.y = 0.0
		if offset.length() <= STRIKE_REACH + _target.body_radius():
			var crit: bool = player.deal_damage(_target, DAMAGE * power, offset.normalized() * KNOCKBACK, true, id)
			CombatVfx.hit_spark(parent, _target.global_position + Vector3.UP * _target.target_height * 0.55,
				offset, "finisher", crit)
	for enemy: Enemy3D in player.enemies_near(center, SPLASH_RADIUS):
		if enemy == _target:
			continue
		var push: Vector3 = enemy.global_position - center
		push.y = 0.0
		player.deal_damage(enemy, DAMAGE * SPLASH_SHARE * power, push.normalized() * KNOCKBACK * 0.6, true, id)
	CombatVfx.slash(parent, player.global_position + Vector3.UP * 1.1, player.facing_angle(), 3.0, 160.0, color,
		false, -0.5, 0.3)
	CombatVfx.hitstop(player.get_tree(), 0.07)
	player.shake_camera(0.15)
	_target = null
