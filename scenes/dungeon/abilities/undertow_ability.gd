extends EnemyAbility

## ТЕЧІЯ (Королева Трясовини). Через залу пролягають два зустрічні
## потоки (стрілки на підлозі, warn секунд попередження), один — просто
## під героєм. time секунд потік зносить того, хто в ньому (push м/с,
## вибратись убік можна), а в кінці кожного потоку — колючі хащі: хто
## туди доплив, щоevery секунд колеться.
## Налаштування: length, width, gap, push, warn, time, every, damage.

const COLOR := Color(0.35, 0.85, 0.75, 0.85)
const BRAMBLE := Color(0.75, 0.2, 0.25, 0.8)
const BUSH_SCENE := preload("res://scenes/dungeon/hazards/thorn_bush.tscn")

var _streams: Array = []
var _warn_left := 0.0
var _flow_left := 0.0
var _prick_left := 0.0

func _init() -> void:
	id = "undertow"
	cooldown = 15.0

func try_use(_distance: float) -> bool:
	if _warn_left > 0.0 or _flow_left > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.7)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_clear()
	var yaw := randf() * TAU
	var direction := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-direction.z, 0.0, direction.x)
	var length := float(config.get("length", 14.0))
	var width := float(config.get("width", 2.6))
	var center := Vector3(hero.global_position.x, DungeonBuilder.FLOOR_TOP, hero.global_position.z)
	for k in 2:
		var flow := direction if k == 0 else -direction
		var middle := center + side * float(config.get("gap", 4.0)) * k
		# Потік: смуга брижастої води, що тече в бік flow (шейдер), і піна.
		var water := BossFx.water_material(Color(0.05, 0.2, 0.18, 0.75), Color(0.3, 0.6, 0.5, 0.75),
			Vector2(flow.x, flow.z) * 2.5, 1.4)
		water.set_shader_parameter(&"alpha", 0.0)
		var line := BossFx.floor_plane(water, Vector2(width, length))
		world().add_child(line)
		var foam := Fx.make_particles("smoke_04", Color(0.85, 0.95, 0.9, 0.45), 14, length / 3.2, 0.6)
		foam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		foam.emission_box_extents = Vector3(width * 0.4, 0.05, 0.3)
		foam.direction = Vector3(0, 0, 1)
		foam.spread = 4.0
		foam.initial_velocity_min = 3.2
		foam.initial_velocity_max = 3.2
		foam.gravity = Vector3.ZERO
		foam.local_coords = false
		line.add_sibling(foam)
		foam.global_position = middle - flow * length * 0.5 + Vector3.UP * 0.12
		foam.rotation.y = atan2(flow.x, flow.z)
		line.set_meta("foam", foam)
		line.global_position = middle + Vector3.UP * 0.05
		line.rotation.y = atan2(flow.x, flow.z)
		var end := middle + flow * (length * 0.5 + 0.6)
		var thicket := Node3D.new()
		world().add_child(thicket)
		thicket.global_position = end
		for j in 3:
			var bush := BUSH_SCENE.instantiate() as Node3D
			thicket.add_child(bush)
			bush.position = side * (j - 1) * width * 0.35
			bush.scale = Vector3.ONE * 0.8
		var zone := CombatVfx.make_telegraph(BRAMBLE, width * 0.6, PI, false)
		thicket.add_child(zone)
		zone.position.y = 0.05
		_streams.append({"line": line, "middle": middle, "flow": flow, "end": end, "thicket": thicket, "zone": zone})
	_warn_left = float(config.get("warn", 1.0))

func tick(delta: float) -> void:
	super.tick(delta)
	if _warn_left > 0.0:
		_warn_left -= delta
		var warn := float(config.get("warn", 1.0))
		for stream: Dictionary in _streams:
			if is_instance_valid(stream.line):
				((stream.line as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(&"alpha", clampf(1.0 - _warn_left / warn, 0.0, 1.0))
			if is_instance_valid(stream.zone):
				CombatVfx.set_param(stream.zone, &"progress", clampf(1.0 - _warn_left / warn, 0.0, 1.0))
		if _warn_left <= 0.0:
			_flow_left = float(config.get("time", 5.0))
		return
	if _flow_left <= 0.0:
		return
	_flow_left -= delta
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		_clear()
		return
	var length := float(config.get("length", 14.0))
	var width := float(config.get("width", 2.6))
	_prick_left -= delta
	for stream: Dictionary in _streams:
		var offset: Vector3 = hero.global_position - stream.middle
		offset.y = 0.0
		var along: float = offset.dot(stream.flow)
		var across: float = (offset - stream.flow * along).length()
		if absf(along) <= length * 0.5 and across <= width * 0.5 and hero.has_method("apply_pull"):
			hero.apply_pull(stream.flow * float(config.get("push", 3.2)))
		var to_end: Vector3 = hero.global_position - stream.end
		to_end.y = 0.0
		if to_end.length() <= width * 0.6 and _prick_left <= 0.0:
			_prick_left = float(config.get("every", 0.6))
			if hero.take_damage(damage()):
				CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.6, BRAMBLE, false)
	if _flow_left <= 0.0:
		_clear()

func on_death() -> void:
	_clear()

func _clear() -> void:
	_warn_left = 0.0
	_flow_left = 0.0
	for stream: Dictionary in _streams:
		if is_instance_valid(stream.line):
			var foam: Node = stream.line.get_meta("foam", null)
			if foam != null and is_instance_valid(foam):
				foam.queue_free()
			stream.line.queue_free()
		if is_instance_valid(stream.thicket):
			stream.thicket.queue_free()
	_streams.clear()
