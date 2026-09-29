extends Enemy3D
class_name ExplosiveBarrel

## ВИБУХОВА БОЧКА. Червона бочка з тліючим ґнотом. Будь-який удар — меч,
## куля, чари, вихор — підпалює її, і за мить вона вибухає: зносить
## ворогів довкола, підпалює сусідні бочки ланцюжком і ранить героя, якщо
## той стоїть надто близько. Заманив натовп до бочки — і одним ударом
## розчистив залу.
##
## Для зброї героя бочка — "ворог": так її зачіпає будь-яка атака, без
## окремого коду в кожному вмінні. Для гри — ні: не ходить, не б'є, не
## дає ні досвіду, ні золота, автоприціл і самонавідні чари на неї не
## наводяться, лічильник ворогів її не рахує.

const BARREL_SCENE := preload("res://assets/models/dungeon/Barrel.fbx")
const TINT := Color(1.0, 0.34, 0.26)
const HEIGHT := 1.35
## Від удару до вибуху. Бочку, яку підпалив вибух сусідньої, рве швидше —
## але не миттєво: видно, як біжить ланцюжок.
const BARREL_FUSE := 0.55
const CHAIN_FUSE := 0.18
const BLAST_RADIUS := 3.3
## Героя ранить лише ближча частина вибуху: стояв на краю — встиг.
const HERO_BLAST_SHARE := 0.8
const BLAST_KNOCKBACK := 9.0
const BLAST_COLOR := Color(1.0, 0.52, 0.16)
const EMBER_COLOR := Color(1.0, 0.6, 0.2)

## Шкода вибуху по ворогах і по герою. Задає данж — із силою рівня.
var blast_damage := 45.0
var hero_damage := 12.0

var _fuse := -1.0
var _fuse_total := BARREL_FUSE
var _ember: MeshInstance3D

## Пофарбовані матеріали спільні для всіх бочок рівня.
static var _painted: Dictionary = {}

func _ready() -> void:
	add_to_group(&"enemies")
	max_hp = 1.0
	current_hp = 1.0
	target_height = HEIGHT
	xp_reward = 0

func setup(player: Node3D, _model_scene: PackedScene) -> void:
	_player = player
	_model = BARREL_SCENE.instantiate()
	add_child(_model)
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.get_surface_override_material_count():
			mesh_instance.set_surface_override_material(surface, _paint(mesh_instance.get_active_material(surface)))
		# Далека бочка не малюється: у кадрі її однаково не видно.
		mesh_instance.visibility_range_end = 40.0
	_add_ember()

## Червона фарба поверх дерева — вибухову бочку не сплутаєш із простою.
static func _paint(source: Material) -> Material:
	var standard := source as StandardMaterial3D
	if standard == null:
		return source
	var key := standard.get_rid()
	if not _painted.has(key):
		var painted := standard.duplicate() as StandardMaterial3D
		painted.albedo_color = standard.albedo_color * TINT
		_painted[key] = painted
	return _painted[key]

## Тліючий ґніт на кришці: жаринка "дихає" — бочка жива, її можна рвонути.
func _add_ember() -> void:
	_ember = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	sphere.radial_segments = 8
	sphere.rings = 4
	_ember.mesh = sphere
	_ember.material_override = CombatVfx.get_glow_material(EMBER_COLOR)
	_ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ember.position = Vector3(0, HEIGHT + 0.06, 0)
	add_child(_ember)
	var tween := _ember.create_tween().set_loops()
	tween.tween_property(_ember, "scale", Vector3.ONE * 1.6, 0.45)
	tween.tween_property(_ember, "scale", Vector3.ONE, 0.45)

func is_aim_target() -> bool:
	return false

func take_damage(_amount: float, _knockback: Vector3 = Vector3.ZERO, _crit: bool = false, _heavy: bool = false) -> void:
	ignite(BARREL_FUSE)

## Підпалити ґніт. Уже горить — лишається коротший із двох строків.
func ignite(seconds: float) -> void:
	if _dying:
		return
	if _fuse >= 0.0:
		_fuse = minf(_fuse, seconds)
		return
	_fuse = seconds
	_fuse_total = seconds
	_show_telegraph(BLAST_RADIUS, PI, EXPLODE_COLOR)
	CombatVfx.flash_model(_model, Color(1.0, 0.85, 0.4), 0.1)

# Бочка не рухається й не має анімацій, чари її не сповільнюють.
func _process(_delta: float) -> void:
	pass

func apply_slow(_factor: float, _seconds: float) -> void:
	pass

func freeze(_seconds: float) -> void:
	pass

func stun(_seconds: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if _fuse < 0.0 or _dying:
		return
	_fuse -= delta
	if _telegraph != null:
		_telegraph.set_instance_shader_parameter(&"progress", 1.0 - maxf(_fuse, 0.0) / _fuse_total)
	if _fuse <= 0.0:
		_blast()

func _blast() -> void:
	_dying = true
	_fuse = -1.0
	remove_from_group(&"enemies")
	collision_layer = 0
	_hide_telegraph()
	var parent := get_parent()
	var center := global_position
	CombatVfx.shockwave(parent, center, BLAST_RADIUS, BLAST_COLOR, 0.4)
	CombatVfx.impact(parent, center + Vector3.UP * 0.7, BLAST_COLOR, true)
	CombatVfx.impact(parent, center + Vector3.UP * 1.3, Color(1.0, 0.85, 0.4), true)
	AudioManager.play(&"explosion")
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.22)
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy3D
		if enemy == null or not enemy.is_alive():
			continue
		var offset := enemy.global_position - center
		offset.y = 0.0
		if offset.length() > BLAST_RADIUS:
			continue
		if enemy is ExplosiveBarrel:
			(enemy as ExplosiveBarrel).ignite(CHAIN_FUSE)
		else:
			enemy.take_damage(blast_damage, offset.normalized() * BLAST_KNOCKBACK, false, true)
	if _player != null:
		var to_hero := _player.global_position - center
		to_hero.y = 0.0
		if to_hero.length() <= BLAST_RADIUS * HERO_BLAST_SHARE:
			_player.take_damage(hero_damage)
	queue_free()
