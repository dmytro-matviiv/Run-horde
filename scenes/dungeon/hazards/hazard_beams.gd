extends Node3D
class_name HazardBeams

## ПРОМЕНІ БОСА: кілька променів від боса, що повільно обертаються. Спершу
## тонкі й бліді (попередження), тоді спалахують і ранять того, кого
## зачіплять. Від променя треба йти по колу разом із ним або перекотитись
## крізь нього.

const WARN := 0.9
const HIT_COOLDOWN := 0.5

var _owner: Node3D
var _player: Node3D
var _count := 3
var _length := 13.0
var _width := 0.7
var _active_time := 3.5
var _turn_speed := 1.2
var _damage := 8.0
var _color := Color(1.0, 0.25, 0.3)
var _age := 0.0
var _angle := 0.0
var _hit_left := 0.0
var _beams: Array[MeshInstance3D] = []
var _strips: Array[MeshInstance3D] = []

static func spawn(owner: Node3D, player: Node3D, count: int, length: float, active_time: float,
		turn_speed: float, damage: float, color: Color) -> HazardBeams:
	var beams := HazardBeams.new()
	beams._owner = owner
	beams._player = player
	beams._count = count
	beams._length = length
	beams._active_time = active_time
	beams._turn_speed = turn_speed * (1.0 if randf() < 0.5 else -1.0)
	beams._damage = damage
	beams._color = color
	beams._angle = randf() * TAU
	owner.get_parent().add_child(beams)
	return beams

func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	for i in _count:
		var beam := MeshInstance3D.new()
		beam.mesh = mesh
		beam.material_override = CombatVfx.get_glow_material(_color)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		_beams.append(beam)
		var strip := CombatVfx.make_line_telegraph(_color, _length, _width * 2.2, "flames")
		add_child(strip)
		_strips.append(strip)
	_place()

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= WARN + _active_time or _owner == null or not is_instance_valid(_owner) \
			or not (_owner as Enemy3D).is_alive():
		queue_free()
		return
	_angle += _turn_speed * delta
	_place()
	if _age < WARN:
		return
	_hit_left -= delta
	if _hit_left > 0.0 or _player == null or not is_instance_valid(_player):
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	for i in _count:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, _beam_angle(i))
		var along := offset.dot(direction)
		if along < 0.0 or along > _length:
			continue
		if (offset - direction * along).length() <= _width * 0.5 + 0.35:
			_hit_left = HIT_COOLDOWN
			_player.take_damage(_damage)
			return

func _beam_angle(index: int) -> float:
	return _angle + TAU * index / _count

## Промені йдуть від боса на висоті грудей; поки попередження — тонкі.
## Під кожним на підлозі — вогняна смуга: під час попередження вона
## заливається від боса до кінця, далі горить, поки б'є промінь.
func _place() -> void:
	global_position = _owner.global_position + Vector3(0, 1.0, 0)
	var thickness := _width if _age >= WARN else 0.12
	for i in _count:
		var strip := _strips[i]
		strip.rotation.y = _beam_angle(i) + PI
		strip.position = Vector3.FORWARD.rotated(Vector3.UP, _beam_angle(i)) * _length * 0.5 + Vector3(0, -0.94, 0)
		strip.set_instance_shader_parameter(&"progress", minf(_age / WARN, 1.0))
		var direction := Vector3.FORWARD.rotated(Vector3.UP, _beam_angle(i))
		var beam := _beams[i]
		beam.basis = Basis(Vector3.UP, _beam_angle(i)).scaled(Vector3(thickness, thickness * 0.5, _length))
		beam.position = direction * _length * 0.5
		beam.transparency = 0.0 if _age >= WARN else 0.6
