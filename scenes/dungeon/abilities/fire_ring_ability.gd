extends EnemyAbility

## ПАЛАЮЧИЙ КРУГ (Ватажок розбійників). Ватажок підпалює село довкола:
## вогняне кільце (від start до finish м радіусом за shrink с) стискається
## до центру зали. Поза кільцем — вогонь: шкода щопів секунди (tick).
## Безпечно лише всередині — а там Ватажок. Потім кільце гасне (hold с).

const COLOR := Color(1.0, 0.45, 0.12)
const TICK := 0.5

var _left_time := 0.0
var _center := Vector3.ZERO
var _ring: Node3D
var _flames: CPUParticles3D
var _tick_left := 0.0

func _init() -> void:
	id = "fire_ring"
	cooldown = 24.0

func is_active() -> bool:
	return _left_time > 0.0

func try_use(_distance: float) -> bool:
	if _left_time > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 1.0)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_center = enemy.global_position
	_center.y = DungeonBuilder.FLOOR_TOP
	_left_time = float(config.get("shrink", 8.0)) + float(config.get("hold", 2.5))
	# Стіна полум'я (шейдер вогню) і чорний дим палаючого села над нею.
	_ring = Fx.make_fire_wall()
	world().add_child(_ring)
	_ring.global_position = _center
	_flames = Fx.make_particles("smoke_07", Color(0.12, 0.1, 0.09, 0.55), 26, 2.2, 2.2)
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_flames.emission_ring_axis = Vector3.UP
	_flames.emission_ring_height = 0.2
	_flames.emission_ring_inner_radius = 0.97
	_flames.emission_ring_radius = 1.0
	_flames.direction = Vector3.UP
	_flames.spread = 8.0
	_flames.initial_velocity_min = 1.2
	_flames.initial_velocity_max = 2.0
	_flames.gravity = Vector3(0, 0.6, 0)
	_flames.local_coords = true
	_ring.add_child(_flames)
	_flames.position.y = 1.4
	_scale_ring()

func _radius() -> float:
	var shrink := float(config.get("shrink", 8.0))
	var passed := float(config.get("shrink", 8.0)) + float(config.get("hold", 2.5)) - _left_time
	return lerpf(float(config.get("start", 11.0)), float(config.get("finish", 3.5)), clampf(passed / shrink, 0.0, 1.0))

func _scale_ring() -> void:
	if _ring != null and is_instance_valid(_ring):
		var r := _radius()
		var grow := clampf((float(config.get("shrink", 8.0)) + float(config.get("hold", 2.5)) - _left_time) / 0.6, 0.0, 1.0)
		var fade := clampf(_left_time / 0.5, 0.0, 1.0)
		Fx.update_fire_wall(_ring, r, 1.6 * grow, grow * fade)
		if _flames != null and is_instance_valid(_flames):
			_flames.emission_ring_radius = r
			_flames.emission_ring_inner_radius = r * 0.96

func tick(delta: float) -> void:
	super.tick(delta)
	if _left_time <= 0.0:
		return
	_left_time -= delta
	_scale_ring()
	_tick_left -= delta
	var hero := player()
	if _tick_left <= 0.0 and hero != null and is_instance_valid(hero):
		var offset := hero.global_position - _center
		offset.y = 0.0
		if offset.length() > _radius():
			_tick_left = TICK
			hero.take_damage(damage() * float(config.get("tick", 0.22)))
	if _left_time <= 0.0:
		_clear()

func on_death() -> void:
	_left_time = 0.0
	_clear()

func _clear() -> void:
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
