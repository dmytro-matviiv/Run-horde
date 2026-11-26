extends EnemyAbility

## НАСКОК (Сніговий вовк). Вовк припадає до землі (морда вниз, тіло
## стиснуте) — windup, — і стрибає дугою на героя, здіймаючи сніг. Влучив
## — пазурі рвуть (три білі смуги) і збивають з ніг (knock). Промахнувся —
## приземляється в замет і мить отямлюється. Зграя стрибає по черзі, з
## різних боків (див. wolf_circle).
## Налаштування: min, max, windup, flight, knock, damage.

const COLOR := Color(0.85, 0.95, 1.0)

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _fly_left := 0.0
var _flight := 0.45

func _init() -> void:
	id = "wolf_pounce"
	cooldown = 5.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 2.2)) or distance > float(config.get("max", 7.0)) or _fly_left > 0.0:
		return false
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.45))
	enemy.face_point(hero.global_position)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	BossFx.gesture(enemy.get("_model") as Node3D, -14.0, -0.22, windup, 0.25)
	CombatVfx.smoke_puff(world(), enemy.global_position + Vector3.UP * 0.2, Color(0.9, 0.95, 1.0), 0.8)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_from = enemy.global_position
	# Цілиться трохи на випередження — у груди героєві.
	_to = hero.global_position
	if hero is CharacterBody3D:
		var run := (hero as CharacterBody3D).velocity
		run.y = 0.0
		_to += run * 0.25
	_to.y = _from.y
	var dir := _to - _from
	dir.y = 0.0
	if dir.length() > 0.8:
		_to -= dir.normalized() * 0.6
	_flight = float(config.get("flight", 0.45))
	_fly_left = _flight
	var snow := Fx.make_particles("circle_05", Color(0.95, 0.98, 1.0, 0.9), 14, 0.5, 0.12)
	snow.direction = Vector3.UP
	snow.spread = 60.0
	snow.initial_velocity_min = 1.0
	snow.initial_velocity_max = 2.5
	snow.local_coords = false
	enemy.add_child(snow)
	snow.position = Vector3.UP * 0.5
	enemy.get_tree().create_timer(_flight + 0.1).timeout.connect(func() -> void:
		if is_instance_valid(snow):
			snow.emitting = false
			snow.get_tree().create_timer(0.6).timeout.connect(snow.queue_free))

func tick(delta: float) -> void:
	super.tick(delta)
	if _fly_left <= 0.0:
		return
	_fly_left -= delta
	var t := clampf(1.0 - _fly_left / _flight, 0.0, 1.0)
	enemy.teleport_to(_from.lerp(_to, t) + Vector3.UP * sin(t * PI) * 1.4)
	if _fly_left <= 0.0:
		_land()

func _land() -> void:
	enemy.teleport_to(_to)
	var spot := Vector3(_to.x, DungeonBuilder.FLOOR_TOP, _to.z)
	CombatVfx.smoke_puff(world(), spot + Vector3.UP * 0.3, Color(0.92, 0.96, 1.0), 1.2)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var off := hero.global_position - spot
	off.y = 0.0
	if off.length() < 1.5 and hero.take_damage(damage()):
		# Три смуги пазурів навхрест.
		var yaw := atan2(off.x, off.z)
		for k in 3:
			CombatVfx.slash(world(), hero.global_position + Vector3.UP * (0.7 + k * 0.25), yaw + PI + (k - 1) * 0.25, 0.9, 70.0, COLOR)
		if hero.has_method("knock_down"):
			hero.knock_down(off.normalized() * 5.0, float(config.get("knock", 0.35)))
	else:
		enemy.stun_for(0.6)
	enemy.face_point(hero.global_position)

func is_busy() -> bool:
	return _fly_left > 0.0
