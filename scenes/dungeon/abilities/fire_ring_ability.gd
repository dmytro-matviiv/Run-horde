extends EnemyAbility

## ПАЛАЮЧИЙ КРУГ (Ватажок розбійників). Ватажок підпалює село довкола:
## вогняне кільце (від start до finish м радіусом за shrink с) стискається
## до центру зали. Поза кільцем — вогонь: шкода щопів секунди (tick).
## Безпечно лише всередині — а там Ватажок. Потім кільце гасне (hold с).

const COLOR := Color(1.0, 0.45, 0.12)
const TICK := 0.5

var _left_time := 0.0
var _center := Vector3.ZERO
var _ring: MeshInstance3D
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
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring.material_override = CombatVfx.get_glow_material(COLOR)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world().add_child(_ring)
	_ring.global_position = _center + Vector3.UP * 0.15
	_flames = CombatVfx.make_trail(COLOR, 0.6)
	_flames.amount = 48
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_flames.emission_ring_axis = Vector3.UP
	_flames.emission_ring_height = 0.1
	_flames.emission_ring_inner_radius = 0.95
	_flames.emission_ring_radius = 1.0
	_flames.direction = Vector3.UP
	_flames.gravity = Vector3(0, 2.5, 0)
	_ring.add_child(_flames)
	_scale_ring()
	CombatVfx.shockwave(world(), _center, float(config.get("start", 11.0)), COLOR, 0.6)

func _radius() -> float:
	var shrink := float(config.get("shrink", 8.0))
	var passed := float(config.get("shrink", 8.0)) + float(config.get("hold", 2.5)) - _left_time
	return lerpf(float(config.get("start", 11.0)), float(config.get("finish", 3.5)), clampf(passed / shrink, 0.0, 1.0))

func _scale_ring() -> void:
	if _ring != null and is_instance_valid(_ring):
		var r := _radius()
		_ring.scale = Vector3(r, 1.0, r)

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
