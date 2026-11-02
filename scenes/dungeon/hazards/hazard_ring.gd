extends Node3D
class_name HazardRing

## КІЛЬЦЕ УДАРНОЇ ХВИЛІ: бос б'є об землю, і по підлозі від нього
## розбігається світне кільце. Воно ранить, коли проходить крізь героя, —
## утекти не вийде, треба перекотитись крізь нього в мить удару
## (ідеальний перекат) або стояти вже за межею, куди воно не дійде.

const WIDTH := 0.65

var _center := Vector3.ZERO
var _max_radius := 11.0
var _speed := 8.0
var _damage := 10.0
var _color := Color(1.0, 0.5, 0.15)
var _player: Node3D
## Хто вдарив (для перевірки "ще живий" — упав боса, поки кільце
## розбігається, останній помах не ранить: чесно й узгоджено з дощем
## небезпек BossPhases).
var _owner: Enemy3D
var _age := 0.0
var _hit := false
var _marker: MeshInstance3D

## Скільки секунд кільце тримає героя вмерзлим на місці (0 — не тримає).
var freeze := 0.0

static func spawn(world: Node, center: Vector3, player: Node3D, max_radius: float, speed: float, damage: float,
		color: Color, owner: Enemy3D = null) -> HazardRing:
	var ring := HazardRing.new()
	ring._center = Vector3(center.x, DungeonBuilder.FLOOR_TOP + 0.05, center.z)
	ring._max_radius = max_radius
	ring._speed = speed
	ring._damage = damage
	ring._color = color
	ring._player = player
	ring._owner = owner
	world.add_child(ring)
	return ring

func _ready() -> void:
	_marker = CombatVfx.make_ground_marker(_color, _max_radius)
	CombatVfx.set_param(_marker, &"wave", 1.0)
	CombatVfx.set_param(_marker, &"progress", 0.0)
	add_child(_marker)
	_marker.global_position = _center

func _physics_process(delta: float) -> void:
	_age += delta
	var radius := _age * _speed
	if radius >= _max_radius:
		queue_free()
		return
	CombatVfx.set_param(_marker, &"progress", radius / _max_radius)
	if _hit or _player == null or not is_instance_valid(_player):
		return
	if _owner != null and (not is_instance_valid(_owner) or not _owner.is_alive()):
		return
	var offset := _player.global_position - _center
	offset.y = 0.0
	if absf(offset.length() - radius) <= WIDTH:
		_hit = true
		if _player.take_damage(_damage) and freeze > 0.0 and _player.has_method("root"):
			_player.root(freeze)
