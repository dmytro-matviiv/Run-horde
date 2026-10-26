extends Node3D
class_name RuneSeal

## Рунна печать Руновода: на підлозі проступає коло рун, наливається
## світлом — і вибухає. Поки коло наповнюється, видно, куди вдарить;
## швидкий ворог ще встигає вискочити.
##
## Велика печать (особлива здібність книги) ще й тримає всіх, хто в ній,
## — вони стоять, поки печать не вибухне.

const COLOR := Color(0.35, 0.85, 1.0, 0.9)
const RUNES := 6

static var _rune_mesh: BoxMesh

var radius := 1.7
## Хто поставив печать: &"weapon" (книга рун) чи id здібності.
var source: StringName = &"weapon"
var delay := 0.45
var damage := 1.0
var hold := 0.0

var _player: Node
var _left := 0.0
var _marker: MeshInstance3D
var _runes: Node3D

static func spawn(parent: Node, player: Node, position: Vector3, seal_radius: float, seal_delay: float,
		seal_damage: float, seal_hold: float = 0.0) -> RuneSeal:
	var seal := RuneSeal.new()
	seal._player = player
	seal.radius = seal_radius
	seal.delay = seal_delay
	seal.damage = seal_damage
	seal.hold = seal_hold
	parent.add_child(seal)
	seal.global_position = Vector3(position.x, (player as Node3D).global_position.y, position.z)
	return seal

func _ready() -> void:
	_left = delay
	_marker = CombatVfx.make_ground_marker(COLOR, radius)
	add_child(_marker)
	_marker.position = Vector3(0, 0.07, 0)
	# Руни по колу — світні риски, що повільно обертаються.
	_runes = Node3D.new()
	add_child(_runes)
	_runes.position = Vector3(0, 0.1, 0)
	for i in RUNES:
		var angle := TAU * float(i) / RUNES
		var rune := MeshInstance3D.new()
		rune.mesh = _get_rune_mesh()
		rune.material_override = CombatVfx.get_glow_material(COLOR)
		rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rune.position = Vector3(sin(angle), 0.0, cos(angle)) * radius * 0.78
		rune.rotation.y = angle
		rune.scale = Vector3.ONE * clampf(radius / 1.7, 0.8, 2.0)
		_runes.add_child(rune)
	if hold > 0.0 and _player != null and is_instance_valid(_player):
		for enemy: Enemy3D in _player.enemies_near(global_position, radius):
			enemy.stun(delay + hold, source != &"weapon")

func _physics_process(delta: float) -> void:
	_left -= delta
	_marker.set_instance_shader_parameter(&"progress", clampf(1.0 - _left / delay, 0.0, 1.0))
	_runes.rotation.y += delta * 2.5
	if _left > 0.0:
		return
	if _player != null and is_instance_valid(_player):
		_explode()
	queue_free()

func _explode() -> void:
	var parent := get_parent()
	CombatVfx.shockwave(parent, global_position, radius, COLOR, 0.3)
	CombatVfx.impact(parent, global_position + Vector3.UP * 0.5, COLOR, true)
	var big := hold > 0.0
	for enemy: Enemy3D in _player.enemies_near(global_position, radius):
		var push := enemy.global_position - global_position
		push.y = 0.0
		_player.deal_damage(enemy, damage, push.normalized() * (2.5 if big else 1.2), big, source)
	if big:
		_player.shake_camera(0.1)

static func _get_rune_mesh() -> BoxMesh:
	if _rune_mesh == null:
		_rune_mesh = BoxMesh.new()
		_rune_mesh.size = Vector3(0.08, 0.02, 0.32)
	return _rune_mesh
