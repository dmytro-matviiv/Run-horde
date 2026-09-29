extends Node3D
class_name LobShell

## БОМБА ПО ДУЗІ. Летить туди, де герой стояв у мить кидка: на підлозі
## одразу видно коло, що заповнюється до вибуху, — є час відійти.
## Після вибуху може лишитися калюжа (HazardPool).

const FLIGHT := 1.0
const ARC_HEIGHT := 3.5

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _radius := 1.6
var _damage := 8.0
var _color := Color(1.0, 0.45, 0.1)
var _pool_seconds := 0.0
var _player: Node3D
## Хто кинув (перевірка "ще живий" на вибуху — кинуте до смерті долітає
## й показує вибух, але вже не ранить і не лишає калюжі).
var _owner: Enemy3D
var _marker: MeshInstance3D
var _shell: Node3D

## shell_scene — чим кидає (гарбуз, казанок); порожньо — світна куля.
static func launch(world: Node, from: Vector3, to: Vector3, player: Node3D, radius: float, damage: float,
		color: Color, pool_seconds: float = 0.0, shell_scene: PackedScene = null, owner: Enemy3D = null) -> LobShell:
	var lob := LobShell.new()
	lob._from = from
	lob._to = Vector3(to.x, DungeonBuilder.FLOOR_TOP, to.z)
	lob._radius = radius
	lob._damage = damage
	lob._color = color
	lob._pool_seconds = pool_seconds
	lob._player = player
	lob._owner = owner
	if shell_scene != null:
		lob._shell = shell_scene.instantiate()
	world.add_child(lob)
	return lob

func _ready() -> void:
	_marker = CombatVfx.make_ground_marker(Color(_color, 0.85), _radius)
	add_child(_marker)
	_marker.global_position = _to + Vector3(0, 0.05, 0)
	if _shell == null:
		var sphere := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.28
		mesh.height = 0.56
		mesh.radial_segments = 10
		mesh.rings = 6
		sphere.mesh = mesh
		sphere.material_override = CombatVfx.get_glow_material(_color)
		_shell = sphere
	if _shell is GeometryInstance3D:
		(_shell as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	_shell.global_position = _from
	var tween := create_tween()
	tween.tween_method(_fly, 0.0, 1.0, FLIGHT)
	tween.tween_callback(_explode)

func _fly(t: float) -> void:
	var position := _from.lerp(_to, t)
	position.y += ARC_HEIGHT * 4.0 * t * (1.0 - t)
	_shell.global_position = position
	_shell.rotation.x = t * TAU
	_marker.set_instance_shader_parameter(&"progress", t)

func _explode() -> void:
	var world := get_parent()
	CombatVfx.shockwave(world, _to, _radius, _color, 0.35)
	CombatVfx.impact(world, _to + Vector3.UP * 0.5, _color, true)
	AudioManager.play(&"explosion", 0.15)
	# Кинуте до смерті долітає й вибухає — видовищно, але кривдника вже
	# нема, тож не ранить і не лишає калюжі.
	var owner_alive := _owner == null or (is_instance_valid(_owner) and _owner.is_alive())
	if owner_alive and _player != null and is_instance_valid(_player):
		var offset := _player.global_position - _to
		offset.y = 0.0
		if offset.length() <= _radius:
			_player.take_damage(_damage)
	if owner_alive and _pool_seconds > 0.0:
		# Калюжа далі горить сама: вона вже не залежить від того, хто її
		# кинув — так само, як пастки чи бочки данжу.
		HazardPool.spawn(world, _to, _player, _radius * 0.9, _damage * 0.3, _pool_seconds, _color)
	queue_free()
