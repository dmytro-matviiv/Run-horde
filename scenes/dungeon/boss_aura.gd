extends Node3D
class_name BossAura

## Аура фінального боса — щоб із першого погляду було видно: це не просто
## ще один ворог. Під ногами — рунне коло, що повільно обертається й
## пульсує; довкола — іскри-тіні, що здіймаються вгору; над головою —
## тонкий стовп світла. З кожною фазою аура густішає, яскравішає й
## наливається кольором люті (set_phase). Усе — частинки й світні матеріали,
## без справжніх джерел світла: телефону це майже нічого не коштує.
##
## Вузол чіпляє Enemy3D.configure_boss, якщо в описі боса є "aura":
##   "aura": {"color": Color(...), "rage_color": Color(...), "radius": 3.0}

const BASE_PARTICLES := 18
const RING_ALPHA := 0.2

var _color := Color(0.75, 0.55, 1.0)
var _rage_color := Color(1.0, 0.3, 0.9)
var _radius := 3.0
var _ring: MeshInstance3D
var _inner: MeshInstance3D
var _motes: CPUParticles3D
var _crown: CPUParticles3D
var _pulse: Tween

func configure(settings: Dictionary, scale_height: float) -> void:
	_color = settings.get("color", _color)
	_rage_color = settings.get("rage_color", _rage_color)
	_radius = float(settings.get("radius", 3.0))
	position = Vector3.ZERO
	# Коло лежить на підлозі під босом; модель — дочірній вузол Enemy3D,
	# тож аура рухається й обертається разом із ним.
	# Ледь помітне коло: не затуляє ні героя, ні червоні кола-попередження.
	_ring = CombatVfx.make_ground_marker(Color(_color, RING_ALPHA), _radius)
	CombatVfx.set_param(_ring, &"progress", 1.0)
	add_child(_ring)
	_ring.position = Vector3(0, 0.04, 0)
	_inner = CombatVfx.make_ground_marker(Color(_color.lerp(Color.WHITE, 0.4), RING_ALPHA * 0.8), _radius * 0.55)
	CombatVfx.set_param(_inner, &"progress", 1.0)
	add_child(_inner)
	_inner.position = Vector3(0, 0.05, 0)

	_motes = _make_particles(BASE_PARTICLES, _radius * 0.8, scale_height * 0.9, 0.09)
	add_child(_motes)
	# "Корона" — щільніші іскри довкола плечей і голови.
	_crown = _make_particles(10, 0.5, 0.8, 0.06)
	_crown.position = Vector3(0, scale_height * 0.85, 0)
	add_child(_crown)
	_animate()

func _make_particles(amount: int, spread: float, rise: float, size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 1.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_axis = Vector3.UP
	particles.emission_ring_radius = spread
	particles.emission_ring_inner_radius = spread * 0.3
	particles.emission_ring_height = 0.1
	particles.direction = Vector3.UP
	particles.spread = 15.0
	particles.gravity = Vector3(0, rise * 0.6, 0)
	particles.initial_velocity_min = rise * 0.4
	particles.initial_velocity_max = rise * 0.8
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve
	var gradient := Gradient.new()
	gradient.set_color(0, Color(_color.lerp(Color.WHITE, 0.5), 1.0))
	gradient.set_color(1, Color(_color, 0.0))
	particles.color_ramp = gradient
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	particles.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles

func _animate() -> void:
	var spin := _ring.create_tween().set_loops()
	spin.tween_property(_ring, "rotation:y", TAU, 9.0).from(0.0)
	var spin_back := _inner.create_tween().set_loops()
	spin_back.tween_property(_inner, "rotation:y", -TAU, 6.0).from(0.0)
	_restart_pulse(1.0)

func _restart_pulse(strength: float) -> void:
	if _pulse != null:
		_pulse.kill()
	_pulse = _ring.create_tween().set_loops()
	var low := Vector3.ONE * _radius * 1.9
	var high := Vector3.ONE * _radius * (1.9 + 0.25 * strength)
	low.y = 1.0
	high.y = 1.0
	_pulse.tween_property(_ring, "scale", high, 0.6 / strength)
	_pulse.tween_property(_ring, "scale", low, 0.6 / strength)

## Фаза 2-3: більше іскор, швидший пульс, колір люті.
func set_phase(phase: int) -> void:
	var t := clampf((phase - 1) / 2.0, 0.0, 1.0)
	var color := _color.lerp(_rage_color, t)
	# Колір кола — у спільному матеріалі: беремо матеріал нового кольору
	# з того ж кешу CombatVfx, а set_param робить з нього власну копію й
	# переносить уже задані параметри (progress).
	var probe := CombatVfx.make_ground_marker(Color(color, RING_ALPHA + 0.1 * t), 1.0)
	_ring.material_override = probe.material_override
	probe.free()
	CombatVfx.set_param(_ring, &"progress", 1.0)
	_motes.amount = BASE_PARTICLES + 14 * (phase - 1)
	_motes.initial_velocity_max *= 1.25
	for particles in [_motes, _crown]:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(color.lerp(Color.WHITE, 0.4), 1.0))
		gradient.set_color(1, Color(color, 0.0))
		particles.color_ramp = gradient
	_restart_pulse(1.0 + 0.6 * (phase - 1))

## Бос упав: стовп світла з неба, хвиля на всю залу, коло спалахує й гасне.
func collapse() -> void:
	var parent := get_parent().get_parent()
	CombatVfx.sky_beam(parent, global_position, _color.lerp(Color.WHITE, 0.3))
	CombatVfx.shockwave(parent, global_position, 14.0, _color, 1.2)
	CombatVfx.impact(parent, global_position + Vector3.UP * 2.0, Color.WHITE, true)
	_motes.emitting = false
	_crown.emitting = false
	var fade := create_tween()
	fade.tween_property(_ring, "scale", Vector3(_radius * 3.0, 1.0, _radius * 3.0), 0.8)
	fade.parallel().tween_property(_inner, "scale", Vector3.ZERO, 0.8)
	fade.tween_callback(queue_free)
