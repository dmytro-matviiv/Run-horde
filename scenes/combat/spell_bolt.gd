extends Node3D
class_name SpellBolt

## Снаряд чар Чарівниці: арканна стріла, крижаний уламок, отруйна куля.
##
## Як і куля Оперативника, летить видимо, перевіряє шлях променем між
## кадрами (щоб на 30 кадрах не проскакувати крізь ворога) і
## розбивається об стіни. Що саме робить влучання — сповільнює, лишає
## хмару чи просто спалахує, — вирішує той, хто пустив снаряд (on_hit).

const LIFETIME := 1.8
## Карта-бумеранг летить стільки секунд, а тоді повертає до героя.
const BOOMERANG_TURN := 0.5
const CARD_TEXTURE := "res://assets/textures/rune_card.png"

static var _meshes: Dictionary = {}
static var _card_material: StandardMaterial3D

var kind := "arcane"
## Хто випустив: &"weapon" (посох) чи id здібності — для підсумків походу.
var source: StringName = &"weapon"
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
## Карта: крутиться в польоті (рад/с) і може повертатись бумерангом —
## тоді б'є і на зворотному шляху.
var spin := 0.0
var boomerang := false

var _player: Node
var _velocity := Vector3.ZERO
var _life := LIFETIME
var _age := 0.0
var _returning := false
var _hit_ids: Array = []
var _body: MeshInstance3D

static func create(player: Node, bolt_kind: String, multiplier: float, bolt_color: Color) -> SpellBolt:
	var bolt := SpellBolt.new()
	bolt._player = player
	bolt.kind = bolt_kind
	bolt.damage_multiplier = multiplier
	bolt.color = bolt_color
	return bolt

func _ready() -> void:
	_body = MeshInstance3D.new()
	_body.mesh = _get_mesh(kind)
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "card":
		# Карта летить пласко, як тарілка, і крутиться.
		_body.material_override = _get_card_material()
		_body.rotation_degrees.x = -90.0
	else:
		_body.material_override = CombatVfx.get_glow_material(color)
	# Уламок — загострений уздовж польоту (вперед у Godot — це -Z).
	if kind == "frost":
		_body.rotation_degrees.x = -90.0
	add_child(_body)
	add_child(CombatVfx.make_trail(color, 0.32 if kind == "venom" else 0.24))
	if boomerang:
		_life = LIFETIME + 0.6

func launch(from: Vector3, direction: Vector3, speed: float) -> void:
	global_position = from
	_velocity = direction.normalized() * speed
	_orient()

func _physics_process(delta: float) -> void:
	_age += delta
	if spin != 0.0:
		_body.rotation.y += spin * delta
	if boomerang:
		if not _returning and _age >= BOOMERANG_TURN:
			# Розвернулась — на зворотному шляху знову б'є тих самих.
			_returning = true
			_hit_ids.clear()
		if _returning and _player != null and is_instance_valid(_player):
			var home: Vector3 = (_player as Node3D).global_position + Vector3.UP
			if global_position.distance_to(home) < 0.9:
				queue_free()
				return
			_steer_to(home, 9.0, delta)
	elif homing > 0.0 and target != null and is_instance_valid(target) and target.is_alive():
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
		_player.deal_damage(enemy, damage_multiplier, push.normalized() * 0.6, false, source)
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

## Плавно довернути політ на точку (turn — рад/с).
func _steer_to(point: Vector3, turn: float, delta: float) -> void:
	var speed := _velocity.length()
	var current := _velocity / speed
	var wanted := (point - global_position).normalized()
	var angle := current.angle_to(wanted)
	if angle > 0.001:
		_velocity = current.slerp(wanted, minf(1.0, turn * delta / angle)) * speed
		_orient()

func _orient() -> void:
	var direction := _velocity.normalized()
	if absf(direction.y) < 0.98:
		look_at(global_position + direction, Vector3.UP)

## Форма снаряда: кулька (аркана, отрута) або загострений уламок (крига).
static func _get_mesh(bolt_kind: String) -> Mesh:
	if _meshes.has(bolt_kind):
		return _meshes[bolt_kind]
	var mesh: Mesh
	if bolt_kind == "card":
		# Легкий пласкій прямокутник із малюнком карти: справжня модель
		# карти — 3 тис. вершин, забагато для зграї снарядів на телефоні.
		var quad := QuadMesh.new()
		quad.size = Vector2(0.34, 0.48)
		mesh = quad
	elif bolt_kind == "frost":
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

static func _get_card_material() -> StandardMaterial3D:
	if _card_material == null:
		_card_material = StandardMaterial3D.new()
		_card_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_card_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_card_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		if ResourceLoader.exists(CARD_TEXTURE):
			_card_material.albedo_texture = load(CARD_TEXTURE)
		else:
			_card_material.albedo_color = Color(0.85, 0.2, 0.2)
	return _card_material
