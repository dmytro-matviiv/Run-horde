extends EnemyAbility

## РУННІ ХВИЛІ (Володар Рун). Володар б'є посохом об підлогу, і від нього
## одна за одною біжать count кілець рун. У кожному кільці — прохід (gap
## градусів), що світиться золотом, і щоразу в іншому місці. Кільце
## пройшло крізь героя не в проході — удар. Перекат крізь кільце теж
## рятує. Відбігти далеко не вийде: хвилі доходять до стін зали.
## Налаштування: count, interval, speed, reach, gap, damage.

const COLOR := Color(0.55, 0.3, 1.0)
const GAP_COLOR := Color(1.0, 0.8, 0.35)
const RUNES := 26

var _rings: Array = []
var _queue := 0
var _gap_left := 0.0
var _center := Vector3.ZERO

func _init() -> void:
	id = "rune_waves"
	cooldown = 12.0

func try_use(_distance: float) -> bool:
	if _queue > 0 or not _rings.is_empty():
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.9))
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	BossFx.hero_rune_mark(player(), COLOR, windup)
	return true

func resolve() -> void:
	_center = enemy.global_position
	_center.y = DungeonBuilder.FLOOR_TOP + 0.3
	_queue = int(config.get("count", 3))
	_gap_left = 0.0
	CombatVfx.shockwave(world(), _center, 2.5, COLOR, 0.3)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.12)

func tick(delta: float) -> void:
	super.tick(delta)
	if _queue > 0:
		_gap_left -= delta
		if _gap_left <= 0.0:
			_gap_left = float(config.get("interval", 1.1))
			_queue -= 1
			_spawn_ring()
	var hero := player()
	var speed := float(config.get("speed", 6.5))
	var reach := float(config.get("reach", 16.0))
	for i in range(_rings.size() - 1, -1, -1):
		var ring: Dictionary = _rings[i]
		var before := float(ring.radius)
		ring.radius = before + speed * delta
		_place(ring)
		if hero != null and is_instance_valid(hero) and not ring.hit:
			var off: Vector3 = hero.global_position - _center
			off.y = 0.0
			var d := off.length()
			if d > before - 0.3 and d <= float(ring.radius) + 0.3:
				var angle := atan2(off.z, off.x)
				if absf(angle_difference(angle, float(ring.gap_at))) > float(ring.half_gap):
					ring.hit = true
					if hero.take_damage(damage()):
						CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.8, COLOR, true)
		if float(ring.radius) >= reach:
			(ring.node as Node3D).queue_free()
			_rings.remove_at(i)

func _spawn_ring() -> void:
	var holder := Node3D.new()
	world().add_child(holder)
	holder.global_position = _center
	var half_gap := deg_to_rad(float(config.get("gap", 55.0))) * 0.5
	var gap_at := randf() * TAU
	# Прохід не просто навмання: хоча б раз — у бік, протилежний героєві
	# (треба оббігти Володаря), інакше — поруч із героєм.
	var hero := player()
	if hero != null and is_instance_valid(hero):
		var off: Vector3 = hero.global_position - _center
		var hero_angle := atan2(off.z, off.x)
		gap_at = hero_angle + randf_range(0.6, 1.6) * (1.0 if randf() < 0.5 else -1.0)
	var proto := Fx.make_sprite("magic_03", Color(COLOR, 0.9), true, true)
	var gold := Fx.make_sprite("spark_05", Color(GAP_COLOR, 0.9), true, true)
	var runes: Array = []
	for k in RUNES:
		var angle := TAU * k / RUNES
		var in_gap := absf(angle_difference(angle, gap_at)) <= half_gap
		var sprite: MeshInstance3D = (gold if in_gap else proto).duplicate()
		holder.add_child(sprite)
		runes.append({"node": sprite, "angle": angle, "gap": in_gap})
	proto.free()
	gold.free()
	var ring := {"node": holder, "runes": runes, "radius": 1.2, "gap_at": gap_at, "half_gap": half_gap, "hit": false}
	_place(ring)
	_rings.append(ring)

func _place(ring: Dictionary) -> void:
	var radius := float(ring.radius)
	for r: Dictionary in ring.runes:
		var node: Node3D = r.node
		var angle := float(r.angle)
		# Знаки ростуть разом із кільцем, щоб воно не рідшало біля стін.
		node.scale = Vector3.ONE * (0.5 if bool(r.gap) else maxf(0.95, radius * 0.22))
		node.position = Vector3(cos(angle) * radius, -0.26, sin(angle) * radius)
		node.rotation.y = -angle

func on_death() -> void:
	_queue = 0
	for ring: Dictionary in _rings:
		if is_instance_valid(ring.node):
			(ring.node as Node).queue_free()
	_rings.clear()
