extends EnemyAbility

## ПОВІНЬ (Королева Трясовини). Довкола героя спливають латаття (pads),
## а за warn секунд залу заливає трясовина на time секунд: хто у воді —
## щоevery секунд шкода й в'язне (slow). Рятують лише латаття, та під
## вагою героя кожне тоне за sink секунд — доводиться перестрибувати з
## одного на інше.
## Налаштування: pads, pad_radius, near/far (м від героя), area, warn,
## time, sink, every, slow, damage.

const WATER := Color(0.12, 0.38, 0.32, 0.55)
const PAD := Color(0.3, 0.62, 0.25)

var _water: MeshInstance3D
var _water_mat: StandardMaterial3D
var _pads: Array = []
var _warn_left := 0.0
var _flood_left := 0.0
var _hurt_left := 0.0

func _init() -> void:
	id = "flood"
	cooldown = 20.0

func try_use(_distance: float) -> bool:
	if _warn_left > 0.0 or _flood_left > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.9)), Color(WATER, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_clear()
	var center := Vector3(hero.global_position.x, DungeonBuilder.FLOOR_TOP, hero.global_position.z)
	var area := float(config.get("area", 13.0))
	_water = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = area
	disc.bottom_radius = area
	disc.height = 0.04
	disc.radial_segments = 28
	disc.rings = 1
	_water.mesh = disc
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(WATER, 0.0)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.roughness = 0.1
	_water_mat.metallic = 0.3
	_water_mat.emission_enabled = true
	_water_mat.emission = Color(0.05, 0.2, 0.16)
	_water.material_override = _water_mat
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world().add_child(_water)
	_water.global_position = center + Vector3.UP * 0.02
	var count := int(config.get("pads", 5))
	var radius := float(config.get("pad_radius", 1.1))
	var start := randf() * TAU
	for i in count:
		var angle := start + TAU * i / count + randf_range(-0.25, 0.25)
		var spot := center + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(float(config.get("near", 2.2)), float(config.get("far", 5.0)))
		var pad := MeshInstance3D.new()
		var leaf := CylinderMesh.new()
		leaf.top_radius = radius
		leaf.bottom_radius = radius * 0.95
		leaf.height = 0.08
		leaf.radial_segments = 14
		leaf.rings = 1
		pad.mesh = leaf
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PAD
		mat.emission_enabled = true
		mat.emission = PAD * 0.25
		pad.material_override = mat
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world().add_child(pad)
		pad.global_position = spot + Vector3.UP * 0.1
		_pads.append({"node": pad, "spot": spot, "weight": 0.0, "mat": mat})
	_warn_left = float(config.get("warn", 1.6))

func tick(delta: float) -> void:
	super.tick(delta)
	if _warn_left > 0.0:
		_warn_left -= delta
		var warn := float(config.get("warn", 1.6))
		if _water_mat != null:
			_water_mat.albedo_color.a = WATER.a * clampf(1.0 - _warn_left / warn, 0.0, 1.0)
			_water.global_position.y = DungeonBuilder.FLOOR_TOP + 0.02 + 0.1 * clampf(1.0 - _warn_left / warn, 0.0, 1.0)
		if _warn_left <= 0.0:
			_flood_left = float(config.get("time", 7.0))
			_hurt_left = 0.0
		return
	if _flood_left <= 0.0:
		return
	_flood_left -= delta
	var hero := player()
	if hero == null or not is_instance_valid(hero) or _water == null:
		_clear()
		return
	var on_pad := false
	var radius := float(config.get("pad_radius", 1.1))
	var sink := float(config.get("sink", 1.8))
	for i in range(_pads.size() - 1, -1, -1):
		var pad: Dictionary = _pads[i]
		var offset: Vector3 = hero.global_position - pad.spot
		offset.y = 0.0
		if offset.length() > radius:
			continue
		on_pad = true
		pad.weight += delta
		(pad.mat as StandardMaterial3D).albedo_color = PAD.lerp(Color(0.55, 0.45, 0.15), clampf(pad.weight / sink, 0.0, 1.0))
		(pad.node as Node3D).global_position.y = DungeonBuilder.FLOOR_TOP + 0.1 - 0.12 * clampf(pad.weight / sink, 0.0, 1.0)
		if pad.weight >= sink:
			_sink(i)
	var flat := hero.global_position - _water.global_position
	flat.y = 0.0
	if not on_pad and flat.length() <= float(config.get("area", 13.0)):
		_hurt_left -= delta
		if _hurt_left <= 0.0:
			_hurt_left = float(config.get("every", 0.5))
			if hero.take_damage(damage()):
				CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.4, Color(0.3, 0.8, 0.6), false)
			if hero.has_method("apply_slow"):
				hero.apply_slow(float(config.get("slow", 0.6)), 0.6)
	if _flood_left <= 0.0:
		_clear()

func _sink(index: int) -> void:
	var pad: Dictionary = _pads[index]
	_pads.remove_at(index)
	var node: Node3D = pad.node
	CombatVfx.smoke_puff(world(), node.global_position, Color(0.3, 0.6, 0.5), 0.8)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3(0.1, 1.0, 0.1), 0.25)
	tween.tween_callback(node.queue_free)

func on_death() -> void:
	_clear()

func _clear() -> void:
	_warn_left = 0.0
	_flood_left = 0.0
	for pad: Dictionary in _pads:
		if is_instance_valid(pad.node):
			pad.node.queue_free()
	_pads.clear()
	if _water != null and is_instance_valid(_water):
		var water := _water
		var tween := water.create_tween()
		tween.tween_property(_water_mat, "albedo_color:a", 0.0, 0.5)
		tween.tween_callback(water.queue_free)
	_water = null
	_water_mat = null
