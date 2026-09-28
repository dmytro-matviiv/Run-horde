extends Node3D
class_name PlayerProjectile

## Куля героя.
##
## Летить швидко, але НЕ миттєво: видно трасу, чути ритм пострілів, і
## по ворогові, що біжить, треба трохи вести. Об стіни розбивається —
## стріляти крізь стіни не можна, як і ворогам.
##
## Перевіряємо шлях променем між кадрами, а не лише точкою: на 30 кадрах
## куля долає понад метр за крок, і без променя вона проскакувала б
## крізь ворога.

const LIFETIME := 1.6
const TRACER_LENGTH := 0.9

static var _tracer_mesh: BoxMesh
static var _materials: Dictionary = {}

var damage_multiplier := 1.0
var knockback := 1.0
var color := Color(1.0, 0.9, 0.5)
## Скільки ворогів куля прошиває наскрізь ("Пробивний набій").
var pierce := 0
## Розрив на влучанні ("Розривні кулі"): радіус і частка шкоди сусідам.
var explosion_radius := 0.0
var explosion_damage := 0.0

## Кого вже зачепили — щоб та сама куля не била одного двічі.
var _hit_ids: Array = []

var _velocity := Vector3.ZERO
var _life := LIFETIME
var _player: Node

## Створює кулю. Шкода рахується через героя (deal_damage), тож
## працюють і критичні удари, і пасивні риси на кшталт мітки цілі.
static func create(player: Node, multiplier: float, bullet_color: Color, push: float) -> PlayerProjectile:
	var bullet := PlayerProjectile.new()
	bullet._player = player
	bullet.damage_multiplier = multiplier
	bullet.color = bullet_color
	bullet.knockback = push
	return bullet

func _ready() -> void:
	var tracer := MeshInstance3D.new()
	tracer.mesh = _get_tracer_mesh()
	tracer.material_override = _get_material(color)
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracer)

func launch(from: Vector3, direction: Vector3, speed: float) -> void:
	global_position = from
	_velocity = direction.normalized() * speed
	look_at(from + _velocity, Vector3.UP)

func _physics_process(delta: float) -> void:
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
		queue_free()

func _impact(position: Vector3, collider: Variant) -> void:
	var enemy := collider as Enemy3D
	var alive_player: bool = _player != null and is_instance_valid(_player)
	if enemy != null and enemy.is_alive() and alive_player:
		if _hit_ids.has(enemy.get_instance_id()):
			return   # цього вже зачепили — летимо далі
		_hit_ids.append(enemy.get_instance_id())
		var push: Vector3 = _velocity
		push.y = 0.0
		_player.deal_damage(enemy, damage_multiplier, push.normalized() * knockback, false)
		_explode(position)
		CombatVfx.impact(get_parent(), position, color, false)
		# "Пробивний набій": куля не зупиняється, поки не витратить
		# пробиття. Вороги позаду отримують те саме влучання.
		if pierce > 0:
			pierce -= 1
			global_position = position + _velocity.normalized() * 0.25
			return
		queue_free()
		return
	# Об стіну — дрібні іскри, щоб було видно, куди пішла куля.
	_explode(position)
	CombatVfx.impact(get_parent(), position, color, false)
	queue_free()

## Розривна куля зачіпає всіх поруч із точкою влучання.
func _explode(position: Vector3) -> void:
	if explosion_radius <= 0.0 or _player == null or not is_instance_valid(_player):
		return
	CombatVfx.shockwave(get_parent(), position, explosion_radius, color, 0.25)
	for enemy: Enemy3D in _player.enemies_near(position, explosion_radius):
		if _hit_ids.has(enemy.get_instance_id()):
			continue
		_player.deal_damage(enemy, explosion_damage, Vector3.ZERO, false)

## Витягнута коробочка — на швидкості читається як трасер.
static func _get_tracer_mesh() -> BoxMesh:
	if _tracer_mesh == null:
		_tracer_mesh = BoxMesh.new()
		_tracer_mesh.size = Vector3(0.05, 0.05, TRACER_LENGTH)
	return _tracer_mesh

static func _get_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	_materials[key] = material
	return material
