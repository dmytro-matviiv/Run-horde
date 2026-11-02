extends EnemyAbility

## КІСТЯНІ ШИПИ (Кістяний Володар, фаза 3): після кожного удару з землі по
## прямій до героя виривається ряд кістяних шипів — спершу смуга (tell с),
## тоді шипи. Стоїш на смузі — отримаєш.
##
## Налаштування: length, width, tell (с), damage.

const COLOR := Color(0.9, 0.85, 0.65, 0.9)
const BONE_SCENE := preload("res://assets/models/graveyard/bone.glb")

func _init() -> void:
	id = "bone_spikes"
	cooldown = 0.0

func on_strike() -> void:
	if not ready_to_use() or not enemy.is_alive():
		return
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var origin := enemy.global_position
	var direction := hero.global_position - origin
	direction.y = 0.0
	direction = direction.normalized() if direction.length() > 0.2 else enemy.facing_vector()
	var length := float(config.get("length", 9.0))
	var width := float(config.get("width", 1.3))
	var tell := float(config.get("tell", 0.55))
	var parent := world()
	var hit_damage := damage()
	var line := CombatVfx.make_line_telegraph(COLOR, length, width, "flames", true)
	parent.add_child(line)
	line.global_position = Vector3(origin.x, DungeonBuilder.FLOOR_TOP + 0.05, origin.z) + direction * length * 0.5
	line.rotation.y = atan2(direction.x, direction.z)
	var tween := line.create_tween()
	tween.tween_method(func(value: float) -> void:
		CombatVfx.set_param(line, &"progress", value), 0.0, 1.0, tell)
	tween.tween_callback(func() -> void:
		line.queue_free()
		var steps := int(length / 1.1)
		for k in steps:
			var spot := origin + direction * (1.0 + k * 1.1)
			parent.get_tree().create_timer(0.03 * k, false).timeout.connect(_spike.bind(parent, spot))
		if hero == null or not is_instance_valid(hero):
			return
		var offset := hero.global_position - origin
		offset.y = 0.0
		var along := offset.dot(direction)
		if along > 0.0 and along < length and (offset - direction * along).length() <= width * 0.5 + 0.3:
			hero.take_damage(hit_damage))

## Кістка сторч виривається з підлоги — і за мить ховається.
static func _spike(parent: Node, spot: Vector3) -> void:
	if not is_instance_valid(parent):
		return
	var spike: Node3D = BONE_SCENE.instantiate()
	parent.add_child(spike)
	spike.global_position = Vector3(spot.x, DungeonBuilder.FLOOR_TOP, spot.z)
	spike.rotation.y = randf() * TAU
	spike.rotate_object_local(Vector3.FORWARD, deg_to_rad(80.0))
	spike.scale = Vector3.ONE * 0.1
	CombatVfx.impact_decal(parent, spot, 0.6, COLOR, 0.4)
	var rise := spike.create_tween()
	rise.tween_property(spike, "scale", Vector3.ONE * 2.4, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_interval(0.45)
	rise.tween_property(spike, "scale", Vector3.ONE * 0.1, 0.2)
	rise.tween_callback(spike.queue_free)
