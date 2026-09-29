extends EnemyAbility

## ПАВУТИНА: павук плює липким згустком. Влучив — герой на кілька секунд
## сповільнюється (під ним біле коло). Згусток видно й від нього можна
## ухилитись. "count" — скільки згустків віялом, "slow" — наскільки
## сповільнює (0.5 — удвічі), "slow_time" — скільки секунд.

const WINDUP := 0.55
const MAX_DISTANCE := 13.0
const SPEED := 9.0
const COLOR := Color(0.92, 0.92, 1.0)

func _init() -> void:
	id = "web"
	cooldown = 5.0

func try_use(distance: float) -> bool:
	if distance > MAX_DISTANCE or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, WINDUP, Color(COLOR, 0.7), 1.0)
	return true

func resolve() -> void:
	var hero := player()
	var origin := enemy.global_position + Vector3.UP * enemy.target_height * 0.6
	var direction := hero.global_position + Vector3.UP - origin
	var count := int(config.get("count", 1))
	var slow := float(config.get("slow", 0.5))
	var slow_time := float(config.get("slow_time", 2.5))
	for i in count:
		var angle := 0.0 if count == 1 else lerpf(-0.45, 0.45, float(i) / float(count - 1))
		enemy.spawn_shot(origin, direction.rotated(Vector3.UP, angle), COLOR, SPEED, damage() * 0.5,
			func(target: Node3D) -> void:
				if target.has_method("apply_slow"):
					target.apply_slow(slow, slow_time))
