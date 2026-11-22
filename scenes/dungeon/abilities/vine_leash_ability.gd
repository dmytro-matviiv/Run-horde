extends EnemyAbility

## ЛОЗА-ПРИВ'ЯЗЬ (Корч-душитель, Потонулі Сади). Корч кидає лозу (летить,
## від неї можна ухилитись). Влучила — у підлогу під героєм вганяється
## кілок, і лоза тримає героя: time секунд не відійти далі radius метрів
## від кілка — ні бігом, ні перекатом. Не корінь: битись і крутитись на
## прив'язі можна, а от утекти від корча — ні.
## Налаштування: min, max, windup, radius, time, speed, damage.

const COLOR := Color(0.45, 0.8, 0.25)

func _init() -> void:
	id = "vine_leash"
	cooldown = 10.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 2.5)) or distance > float(config.get("max", 9.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.7)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var origin := enemy.global_position + Vector3.UP * enemy.target_height * 0.6
	var to := hero.global_position + Vector3.UP - origin
	var radius := float(config.get("radius", 2.5))
	var time := float(config.get("time", 4.0))
	var parent := world()
	enemy.spawn_shot(origin, to, COLOR, float(config.get("speed", 12.0)), damage(), func(target: Node3D) -> void:
		if not target.has_method("leash"):
			return
		var anchor := Vector3(target.global_position.x, DungeonBuilder.FLOOR_TOP, target.global_position.z)
		target.leash(anchor, radius, time)
		_stake(parent, anchor, radius, time))

## Кілок і коло прив'язі на підлозі — видно, куди не вийти.
static func _stake(parent: Node, anchor: Vector3, radius: float, time: float) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = anchor
	var ring := CombatVfx.make_ground_marker(Color(COLOR, 0.45), radius)
	CombatVfx.set_param(ring, &"progress", 1.0)
	ring.position.y = 0.05
	root.add_child(ring)
	var stake := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.16
	cone.height = 0.6
	cone.radial_segments = 6
	cone.rings = 1
	stake.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.22, 0.12)
	stake.material_override = mat
	stake.position.y = 0.3
	root.add_child(stake)
	CombatVfx.ground_hit(parent, anchor, 0.6)
	var tween := root.create_tween()
	tween.tween_interval(time)
	tween.tween_callback(root.queue_free)
