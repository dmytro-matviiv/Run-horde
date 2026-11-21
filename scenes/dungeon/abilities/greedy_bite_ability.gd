extends EnemyAbility

## ЖАДІБНИЙ УКУС (Мімік-скриня, Скарбниця Тіней). Кожен укус, що влучив,
## вириває частку золота з походу (share, щонайменше min) — монети летять
## у пащу скрині. Убив міміка — усе вкрадене висипається назад, з лишком
## (refund — множник).

const COLOR := Color(1.0, 0.85, 0.3)

var _stolen := 0

func _init() -> void:
	id = "greedy_bite"
	cooldown = 0.0

func on_strike() -> void:
	if not enemy.strike_landed:
		return
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var dungeon := hero.get_parent()
	if dungeon == null or not dungeon.has_method("steal_gold"):
		return
	var run_gold := int(dungeon.get("_run_gold"))
	var want := maxi(int(config.get("min", 5)), int(run_gold * float(config.get("share", 0.08))))
	var taken: int = dungeon.steal_gold(want)
	if taken <= 0:
		return
	_stolen += taken
	CombatVfx.glow_orb(world(), hero.global_position + Vector3.UP, enemy, enemy.target_height * 0.5, COLOR, 0.35)

func on_death() -> void:
	var hero := player()
	if _stolen <= 0 or hero == null or not is_instance_valid(hero):
		return
	var dungeon := hero.get_parent()
	if dungeon != null and dungeon.has_method("drop_gold"):
		dungeon.drop_gold(enemy.global_position, int(_stolen * float(config.get("refund", 2.0))))
		CombatVfx.shockwave(world(), enemy.global_position, 2.0, COLOR, 0.4)
	_stolen = 0
