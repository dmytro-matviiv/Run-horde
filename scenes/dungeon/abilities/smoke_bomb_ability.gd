extends EnemyAbility

## ДИМОВА ЗАВІСА (Димар, Спустошене Село). Кидає димову бомбу туди, де
## найбільше своїх (або під себе): хмара radius на time секунд. Вороги в
## диму не обираються ціллю (Enemy3D.smoke_until) — лише зачепити ударом
## по площі чи дочекатись, поки вийдуть.

const COLOR := Color(0.55, 0.55, 0.55, 0.75)

var _cloud: Node3D
var _center := Vector3.ZERO
var _left_time := 0.0

func _init() -> void:
	id = "smoke_bomb"
	# Не чекає перерви між звичайними ударами.
	instant = true
	cooldown = 12.0

func try_use(distance: float) -> bool:
	if _left_time > 0.0 or distance > float(config.get("max", 10.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.5)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	# Центр — серед найбільшої купки своїх поруч (або сам Димар).
	_center = enemy.global_position
	var best := 0
	var mates: Array = []
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other != null and other.is_alive() and other.global_position.distance_to(enemy.global_position) <= 7.0:
			mates.append(other)
	for a: Enemy3D in mates:
		# Себе ховає, лише коли поруч нікого (він і сам у бою не головний).
		if a == enemy and mates.size() > 1:
			continue
		var near := 0
		for b: Enemy3D in mates:
			if b.global_position.distance_to(a.global_position) < 3.0:
				near += 1
		if near > best or best == 0:
			best = near
			_center = a.global_position
	_center.y = DungeonBuilder.FLOOR_TOP
	_left_time = float(config.get("time", 6.0))
	_cloud = Node3D.new()
	world().add_child(_cloud)
	_cloud.global_position = _center
	var radius := float(config.get("radius", 3.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.52, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 7:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius * 0.45
		sphere.height = radius * 0.6
		sphere.radial_segments = 10
		sphere.rings = 5
		puff.mesh = sphere
		puff.material_override = mat
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * i / 7.0
		puff.position = Vector3(cos(angle), 0.0, sin(angle)) * radius * (0.0 if i == 0 else 0.5) + Vector3.UP * 0.7
		_cloud.add_child(puff)
	CombatVfx.smoke_puff(world(), _center + Vector3.UP, COLOR, radius)

func tick(delta: float) -> void:
	super.tick(delta)
	if _left_time <= 0.0:
		return
	_left_time -= delta
	var radius := float(config.get("radius", 3.0))
	var until := Time.get_ticks_msec() + 250
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or not other.is_alive() or other.kind == Enemy3D.Kind.BOSS:
			continue
		var offset := other.global_position - _center
		offset.y = 0.0
		if offset.length() <= radius:
			other.smoke_until = until
	if _cloud != null and is_instance_valid(_cloud):
		_cloud.scale = Vector3.ONE * clampf(_left_time / 0.6, 0.05, 1.0)
	if _left_time <= 0.0:
		_clear()

func on_death() -> void:
	_left_time = 0.0
	_clear()

func _clear() -> void:
	if _cloud != null and is_instance_valid(_cloud):
		_cloud.queue_free()
	_cloud = null
