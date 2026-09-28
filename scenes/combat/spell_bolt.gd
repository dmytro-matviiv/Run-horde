extends Node3D
class_name SpellBolt

## Снаряд чар Чарівниці: арканна стріла, крижаний уламок, отруйна куля.
##
## Як і куля Оперативника, летить видимо, перевіряє шлях променем між
## кадрами (щоб на 30 кадрах не проскакувати крізь ворога) і
## розбивається об стіни. Що саме робить влучання — сповільнює, лишає
## хмару чи просто спалахує, — вирішує той, хто пустив снаряд (on_hit).

const LIFETIME := 1.8

static var _meshes: Dictionary = {}

var kind := "arcane"
var damage_multiplier := 1.0
var color := Color.WHITE
## Як швидко снаряд доводиться на ціль, рад/с (арканна стріла).
var homing := 0.0
var target: Enemy3D
## Скільки ворогів снаряд прошиває наскрізь.
var pierce := 0
## Що робити на влучанні: on_hit.call(ворог або null, точка). null —
## стіна чи кінець польоту (отруйна куля й тоді лишає хмару).
var on_hit: Callable

var _player: Node
var _velocity := Vector3.ZERO
var _life := LIFETIME
var _hit_ids: Array = []

static func create(player: Node, bolt_kind: String, multiplier: float, bolt_color: Color) -> SpellBolt:
	var bolt := SpellBolt.new()
	bolt._player = player
	bolt.kind = bolt_kind
	bolt.damage_multiplier = multiplier
	bolt.color = bolt_color
	return bolt

func _ready() -> void:
	var body := MeshInstance3D.new()
	body.mesh = _get_mesh(kind)
	body.material_override = CombatVfx.get_glow_material(color)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Уламок — загострений уздовж польоту (вперед у Godot — це -Z).
	if kind == "frost":
		body.rotation_degrees.x = -90.0
	add_child(body)
	add_child(CombatVfx.make_trail(color, 0.32 if kind == "venom" else 0.24))

func launch(from: Vector3, direction: Vector3, speed: float) -> void:
	global_position = from
	_velocity = direction.normalized() * speed
	_orient()

func _physics_process(delta: float) -> void:
	if homing > 0.0 and target != null and is_instance_valid(target) and target.is_alive():
		var wanted := (target.global_position + Vector3.UP * target.target_height * 0.55 - global_position).normalized()
		var speed := _velocity.length()
		var current := _velocity / speed
		var angle := current.angle_to(wanted)
		if angle > 0.001:
			_velocity = current.slerp(wanted, minf(1.0, homing * delta / angle)) * speed
			_orient()
	var from := global_position
	var to := from + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	# 1 — стіни, 4 — вороги.
	query.collision_mask = 1 | 4
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_impact(hit.position, hit.get("collider"))
		return
	global_position = to
	_life -= delta
	if _life <= 0.0:
		_finish(global_position)

func _impact(position: Vector3, collider: Variant) -> void:
	var enemy := collider as Enemy3D
	var alive_player: bool = _player != null and is_instance_valid(_player)
	if enemy != null and enemy.is_alive() and alive_player:
		# Цього вже зачепили — пролітаємо крізь нього далі.
		if _hit_ids.has(enemy.get_instance_id()):
			global_position = position + _velocity.normalized() * 0.3
			return
		_hit_ids.append(enemy.get_instance_id())
		var push := _velocity
		push.y = 0.0
		_player.deal_damage(enemy, damage_multiplier, push.normalized() * 0.6, false)
		if on_hit.is_valid():
			on_hit.call(enemy, position)
		if pierce > 0:
			pierce -= 1
			global_position = position + _velocity.normalized() * 0.3
			return
		queue_free()
		return
	_finish(position)

## Кінець польоту: стіна або вичерпаний час.
func _finish(position: Vector3) -> void:
	if on_hit.is_valid() and _player != null and is_instance_valid(_player):
		on_hit.call(null, position)
	queue_free()

func _orient() -> void:
	var direction := _velocity.normalized()
	if absf(direction.y) < 0.98:
		look_at(global_position + direction, Vector3.UP)

## Форма снаряда: кулька (аркана, отрута) або загострений уламок (крига).
static func _get_mesh(bolt_kind: String) -> Mesh:
	if _meshes.has(bolt_kind):
		return _meshes[bolt_kind]
	var mesh: Mesh
	if bolt_kind == "frost":
		var shard := CylinderMesh.new()
		shard.top_radius = 0.0
		shard.bottom_radius = 0.09
		shard.height = 0.62
		shard.radial_segments = 5
		shard.rings = 1
		mesh = shard
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.2 if bolt_kind == "venom" else 0.15
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh = sphere
	_meshes[bolt_kind] = mesh
	return mesh
