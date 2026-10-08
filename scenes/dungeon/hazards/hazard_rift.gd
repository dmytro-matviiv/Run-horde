extends Node3D
class_name HazardRift

## ВИР БЕЗОДНІ: фіолетова вирва на підлозі, що затягує героя до центру
## (Player3D.apply_pull) і пече, поки той у радіусі дії. Вирватись можна
## — швидкості вистачає, якщо бігти від центру, а не стояти чи бити
## боса впритул до неї. Перекатом гравець на мить став невразливим, але
## тягнення не скасовує — саме тому тікати треба заздалегідь.

const TICK := 0.4
## Найсильніша тяга, м/с — 60% бігу героя (Player3D.RUN_SPEED 5.4).
const MAX_PULL := 3.2

var _center := Vector3.ZERO
var _radius := 5.0
var _pull_speed := 3.0
var _tick_damage := 6.0
var _lifetime := 6.0
var _player: Node3D
var _tick_left := 0.15
var _marker: MeshInstance3D
var _core: MeshInstance3D

static func spawn(world: Node, center: Vector3, player: Node3D, radius: float, pull_speed: float,
		tick_damage: float, lifetime: float) -> HazardRift:
	var rift := HazardRift.new()
	rift._center = Vector3(center.x, DungeonBuilder.FLOOR_TOP + 0.04, center.z)
	rift._radius = radius
	rift._pull_speed = pull_speed
	rift._tick_damage = tick_damage
	rift._lifetime = lifetime
	rift._player = player
	world.add_child(rift)
	return rift

func _ready() -> void:
	var color := Color(0.55, 0.2, 0.85)
	_marker = CombatVfx.make_ground_marker(Color(color, 0.55), _radius)
	_marker.set_instance_shader_parameter(&"progress", 1.0)
	add_child(_marker)
	_marker.global_position = _center
	_core = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	mesh.radial_segments = 12
	mesh.rings = 6
	_core.mesh = mesh
	_core.material_override = CombatVfx.get_glow_material(color)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	_core.global_position = _center + Vector3.UP * 0.3
	var spin := _core.create_tween().set_loops()
	spin.tween_property(_core, "rotation:y", TAU, 1.4).from(0.0)
	var pulse := _marker.create_tween().set_loops()
	pulse.tween_property(_marker, "scale", Vector3(_radius * 2.15, 1.0, _radius * 2.15), 0.5)
	pulse.tween_property(_marker, "scale", Vector3(_radius * 1.9, 1.0, _radius * 1.9), 0.5)

func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		var fade := create_tween()
		fade.tween_property(_marker, "modulate:a", 0.0, 0.4)
		fade.parallel().tween_property(_core, "scale", Vector3.ZERO, 0.4)
		fade.tween_callback(queue_free)
		set_physics_process(false)
		return
	if _player == null or not is_instance_valid(_player) or not _player.has_method("apply_pull"):
		return
	var offset := _center - _player.global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > _radius or distance < 0.1:
		return
	# Ближче до центру тягне сильніше — останні метри найнебезпечніші.
	# apply_pull додається до velocity (м/с), а не до позиції напряму —
	# сам delta тут зайвий: Player3D.move_and_slide() застосує його сам,
	# як і зі звичайним рухом.
	# У самому центрі тяга гасне (останні 0.8 м) — інакше героя на місці
	# смикало б туди-сюди через центр. І ніколи не сильніша за ~60% бігу:
	# вирватись можна завжди, якщо тікати, а не стояти.
	var strength := _pull_speed * (0.5 + 0.5 * (1.0 - distance / _radius)) * clampf(distance / 0.8, 0.0, 1.0)
	var pull := offset.normalized() * minf(strength, MAX_PULL)
	_player.apply_pull(pull)
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = TICK
		_player.take_damage(_tick_damage)
