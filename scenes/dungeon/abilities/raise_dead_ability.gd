extends EnemyAbility

## ПІДНЯТИ МЕРЦІВ: некромант здіймає руки, під ним зеленіє коло — і з
## підлоги довкола вилазять мерці ("summon" в описі — хто саме, "count" —
## скільки за раз, "max" — скільки може бути живими одночасно). Поки
## некромант живий, мерці прибуватимуть: його треба вбити першим.

const WINDUP := 1.0
const COLOR := Color(0.45, 1.0, 0.45, 0.9)

func _init() -> void:
	id = "raise_dead"
	cooldown = 8.0

func try_use(distance: float) -> bool:
	if distance > 16.0 or config.get("summon", {}).is_empty():
		return false
	if enemy.summons_alive >= int(config.get("max", 4)):
		return false
	start_cooldown()
	enemy.begin_special(id, WINDUP, COLOR, 2.5)
	return true

func resolve() -> void:
	var count := int(config.get("count", 2))
	CombatVfx.shockwave(world(), enemy.global_position, 3.0, COLOR, 0.5)
	for i in count:
		var angle := TAU * i / count + randf() * 0.6
		var spot := enemy.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 2.0
		enemy.spawn_requested.emit(spot, config.summon, enemy)
