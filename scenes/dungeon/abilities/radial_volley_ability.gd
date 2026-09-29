extends EnemyAbility

## КОЛО СНАРЯДІВ (бос): навсібіч летить коло снарядів, і в ньому завжди є
## прохід (кілька пропущених поспіль) — шукай його. У нестямі за першим
## колом летить друге, зсунуте на пів кроку.

const WINDUP := 0.8
const SPEED := 8.0
const GAP := 3

func _init() -> void:
	id = "radial_volley"
	cooldown = 6.0

func try_use(distance: float) -> bool:
	if distance > 16.0:
		return false
	start_cooldown()
	enemy.begin_special(id, WINDUP, Color(_color(), 0.85), 2.4)
	return true

func resolve() -> void:
	_fire(0.0)
	if enemy.phases != null and enemy.phases.phase >= 3:
		var count := int(config.get("count", 16))
		enemy.get_tree().create_timer(0.5, false).timeout.connect(func() -> void:
			if is_instance_valid(enemy) and enemy.is_alive():
				_fire(PI / count))

func _fire(offset: float) -> void:
	var count := int(config.get("count", 16))
	var origin := enemy.global_position + Vector3.UP * 1.0
	var gap_start := randi() % count
	for i in count:
		# Прохід для втечі: GAP снарядів поспіль не вилітають.
		if (i - gap_start + count) % count < GAP:
			continue
		var direction := Vector3.FORWARD.rotated(Vector3.UP, offset + TAU * i / count)
		enemy.spawn_shot(origin, direction, _color(), float(config.get("speed", SPEED)), damage() * 0.8)

func _color() -> Color:
	return config.get("color", Color(0.75, 0.35, 1.0))
