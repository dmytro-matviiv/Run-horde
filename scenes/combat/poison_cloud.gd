extends Node3D
class_name PoisonCloud

## Отруйна хмара Посоха трясовини: стоїть на місці кілька секунд і раз
## за разом труїть усіх, хто в ній. Велике болото (здібність посоха)
## ще й сповільнює.
##
## Для телефона — дешево: одне коло на підлозі й кілька бульбашок.

const TICK := 0.5
const COLOR := Color(0.45, 0.95, 0.3, 0.85)

var radius := 2.0
## Хто лишив хмару: &"weapon" (посох отрути) чи id здібності.
var source: StringName = &"weapon"
var duration := 3.0
var tick_damage := 0.3
## Частка швидкості ворога всередині (1 — не сповільнює).
var slow := 1.0

var _player: Node
var _left := 0.0
var _tick_left := 0.0
var _marker: MeshInstance3D

static func spawn(parent: Node, player: Node, position: Vector3, cloud_radius: float, seconds: float,
		damage: float, slow_factor: float = 1.0) -> PoisonCloud:
	var cloud := PoisonCloud.new()
	cloud._player = player
	cloud.radius = cloud_radius
	cloud.duration = seconds
	cloud.tick_damage = damage
	cloud.slow = slow_factor
	parent.add_child(cloud)
	# Хмара лягає на підлогу під точкою влучання.
	cloud.global_position = Vector3(position.x, (player as Node3D).global_position.y, position.z)
	return cloud

func _ready() -> void:
	_left = duration
	_marker = CombatVfx.make_ground_marker(COLOR, radius)
	CombatVfx.set_param(_marker, &"progress", 1.0)
	add_child(_marker)
	_marker.position = Vector3(0, 0.07, 0)
	add_child(_make_bubbles())
	CombatVfx.shockwave(get_parent(), global_position, radius, COLOR, 0.3)

func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or _player == null or not is_instance_valid(_player):
		queue_free()
		return
	# Під кінець хмара блідне — видно, що скоро зникне.
	CombatVfx.set_param(_marker, &"fade", clampf(_left / 0.6, 0.0, 1.0))
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = TICK
	for enemy: Enemy3D in _player.enemies_near(global_position, radius):
		_player.deal_damage(enemy, tick_damage, Vector3.ZERO, false, source)
		if slow < 1.0 and enemy.is_alive():
			enemy.apply_slow(slow, TICK + 0.3)

## Бульбашки, що повільно здіймаються з трясовини.
func _make_bubbles() -> CPUParticles3D:
	var bubbles := CPUParticles3D.new()
	bubbles.amount = int(clampf(radius * 6.0, 8.0, 22.0))
	bubbles.lifetime = 1.1
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(radius * 0.7, 0.05, radius * 0.7)
	bubbles.direction = Vector3.UP
	bubbles.spread = 10.0
	bubbles.gravity = Vector3.ZERO
	bubbles.initial_velocity_min = 0.3
	bubbles.initial_velocity_max = 0.8
	bubbles.scale_amount_min = 1.2
	bubbles.scale_amount_max = 2.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	bubbles.scale_amount_curve = curve
	bubbles.mesh = CombatVfx.spark_mesh()
	bubbles.material_override = CombatVfx.spark_material()
	bubbles.color = COLOR
	bubbles.position = Vector3(0, 0.15, 0)
	return bubbles
