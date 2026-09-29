extends Node3D
class_name HazardPool

## КАЛЮЖА: вогонь, отрута чи кислота на підлозі після бомби. Кілька
## секунд пече того, хто стоїть усередині (раз на TICK), потім згасає.
## Видно коло на підлозі, що ледь пульсує, — обходь.

const TICK := 0.5

var radius := 1.5
var tick_damage := 4.0
var lifetime := 3.0
var color := Color(1.0, 0.45, 0.1)

var _player: Node3D
var _tick_left := 0.2
var _marker: MeshInstance3D

static func spawn(world: Node, center: Vector3, player: Node3D, pool_radius: float, damage_per_tick: float, seconds: float, pool_color: Color) -> HazardPool:
	var pool := HazardPool.new()
	pool.radius = pool_radius
	pool.tick_damage = damage_per_tick
	pool.lifetime = seconds
	pool.color = pool_color
	pool._player = player
	world.add_child(pool)
	pool.global_position = Vector3(center.x, DungeonBuilder.FLOOR_TOP + 0.03, center.z)
	return pool

func _ready() -> void:
	_marker = CombatVfx.make_ground_marker(Color(color, 0.7), radius)
	_marker.set_instance_shader_parameter(&"progress", 1.0)
	add_child(_marker)
	var pulse := _marker.create_tween().set_loops()
	pulse.tween_property(_marker, "scale", Vector3(radius * 2.1, 1.0, radius * 2.1), 0.45)
	pulse.tween_property(_marker, "scale", Vector3(radius * 1.9, 1.0, radius * 1.9), 0.45)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = TICK
	if _player == null or not is_instance_valid(_player):
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() <= radius:
		_player.take_damage(tick_damage)
