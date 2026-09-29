extends EnemyAbility

## КІЛЬЦЕ (бос): удар об землю, і по підлозі розбігається кільце ударної
## хвилі (HazardRing). У нестямі (фаза 3) — два кільця одне за одним.

const WINDUP := 0.9
const COLOR := Color(1.0, 0.55, 0.15)

func _init() -> void:
	id = "ring_slam"
	cooldown = 7.0

func try_use(distance: float) -> bool:
	if distance > 14.0:
		return false
	start_cooldown()
	enemy.begin_special(id, WINDUP, Color(_color(), 0.85), 3.0)
	return true

func resolve() -> void:
	var rings := 2 if enemy.phases != null and enemy.phases.phase >= 3 else 1
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.2)
	for i in rings:
		if i == 0:
			_spawn_ring()
		else:
			enemy.get_tree().create_timer(0.55, false).timeout.connect(_spawn_ring)

func _spawn_ring() -> void:
	if not is_instance_valid(enemy) or not enemy.is_alive():
		return
	HazardRing.spawn(world(), enemy.global_position, player(), float(config.get("radius", 12.0)),
		float(config.get("speed", 8.0)), damage() * 1.2, _color())

func _color() -> Color:
	return config.get("color", COLOR)
