extends EnemyAbility

## СМОЛОСКИП (Розбійник-палій, Спустошене Село). Удар, що влучив,
## підпалює героя: горить (tick — частка шкоди палія щопів секунди)
## time секунд. Перекат по землі гасить вогонь одразу.

func _init() -> void:
	id = "ignite"
	cooldown = 0.0

func on_strike() -> void:
	if not enemy.strike_landed:
		return
	var hero := player()
	if hero != null and is_instance_valid(hero) and hero.has_method("ignite"):
		hero.ignite(enemy.damage * float(config.get("tick", 0.18)), float(config.get("time", 6.0)))
