extends EnemyAbility

## ПРОМЕНІ (бос): довкола боса спалахують кілька променів і повільно
## обертаються (HazardBeams). Спершу вони бліді — попередження.

const WINDUP := 1.0

func _init() -> void:
	id = "beams"
	cooldown = 11.0

func try_use(distance: float) -> bool:
	if distance > 13.0:
		return false
	start_cooldown()
	enemy.begin_special(id, WINDUP, Color(_color(), 0.8), 3.2)
	return true

func resolve() -> void:
	var count := int(config.get("count", 3))
	if enemy.phases != null and enemy.phases.phase >= 3:
		count += 1
	HazardBeams.spawn(enemy, player(), count, float(config.get("length", 13.0)),
		float(config.get("time", 3.5)), float(config.get("turn", 1.1)), damage() * 0.6, _color())

func _color() -> Color:
	return config.get("color", Color(1.0, 0.25, 0.3))
