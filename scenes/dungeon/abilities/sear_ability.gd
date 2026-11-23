extends EnemyAbility

## ОПІК (Пекельний пес). Укус, що влучив, пече рану: time секунд героя
## ніщо не лікує — ні зілля, ні відновлення, ні вампіризм, ні сфери.
## Зграя псів не дає перепочити.

func _init() -> void:
	id = "sear"
	cooldown = 0.0

func on_strike() -> void:
	if not enemy.strike_landed:
		return
	var hero := player()
	if hero != null and is_instance_valid(hero) and hero.has_method("sear"):
		hero.sear(float(config.get("time", 5.0)))
