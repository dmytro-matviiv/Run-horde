extends Node3D
class_name EnemyProjectile

## Снаряд стрільця. Раніше постріл був миттєвим променем — від нього
## неможливо було ухилитись, і стрілець просто "знімав" здоров'я. Тепер
## снаряд видно:
##   1. під час замаху він набухає в руці стрільця — попередження;
##   2. летить туди, де герой був у мить пострілу, — тож рух убік чи
##      перекат рятують;
##   3. розбивається об стіни й колони (перевірка променем між кроками,
##      тож крізь тонку стіну він не проскочить навіть на 30 кадрах).

const SPEED := 10.0
const LIFETIME := 3.0
const HIT_RADIUS := 0.55
const COLOR := Color(0.75, 0.35, 1.0)

static var _core_materials: Dictionary = {}
static var _core_mesh: SphereMesh

var damage := 6.0
var color := COLOR
var speed := SPEED
var _velocity := Vector3.ZERO
var _life := LIFETIME
var _launched := false
var _target: Node3D
var _core: MeshInstance3D

## Колір і швидкість — свої в кожного стрільця: отруйні плювки в
## печерах повільні й зелені, крижані стріли в цитаделі швидкі й сині.
static func create(shot_damage: float, shot_color: Color = COLOR, shot_speed: float = SPEED) -> EnemyProjectile:
	var projectile := EnemyProjectile.new()
	projectile.damage = shot_damage
	projectile.color = shot_color
	projectile.speed = shot_speed
	return projectile

func _ready() -> void:
	_core = MeshInstance3D.new()
	_core.mesh = _get_core_mesh()
	_core.material_override = _get_core_material(color)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	set_charge(0.0)

## Наскільки снаряд "набухнув" під час замаху (0..1).
func set_charge(progress: float) -> void:
	scale = Vector3.ONE * lerpf(0.25, 1.0, clampf(progress, 0.0, 1.0))

## world — куди "відпустити" снаряд. Випущений снаряд більше не дитина
## стрільця: якщо той помре, поки снаряд летить, снаряд (і його іскри)
## не зникнуть посеред польоту.
func launch(direction: Vector3, target: Node3D, world: Node) -> void:
	_target = target
	_velocity = direction.normalized() * speed
	reparent(world, true)
	scale = Vector3.ONE
	_launched = true

func _physics_process(delta: float) -> void:
	if not _launched:
		return
	var from := global_position
	var to := from + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_burst(hit.position)
		return
	global_position = to

	if _target != null and is_instance_valid(_target):
		var chest := _target.global_position + Vector3.UP * 1.0
		# Під час перекату герой невразливий — снаряд пролітає крізь нього.
		if chest.distance_to(global_position) < HIT_RADIUS and _target.take_damage(damage):
			_burst(global_position)
			return

	_life -= delta
	if _life <= 0.0:
		queue_free()

func _burst(position: Vector3) -> void:
	CombatVfx.impact(get_parent(), position, color, false)
	queue_free()

static func _get_core_mesh() -> SphereMesh:
	if _core_mesh == null:
		_core_mesh = SphereMesh.new()
		_core_mesh.radius = 0.2
		_core_mesh.height = 0.4
		_core_mesh.radial_segments = 12
		_core_mesh.rings = 6
	return _core_mesh

## Світна куля без справжнього джерела світла: вигляд сяйва дає
## сам матеріал, а телефону не треба рахувати ще одну лампу.
static func _get_core_material(tint: Color) -> StandardMaterial3D:
	var key := tint.to_html()
	if _core_materials.has(key):
		return _core_materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint.lightened(0.35)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 3.0
	_core_materials[key] = material
	return material
