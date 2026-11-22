extends EnemyAbility

## КЛЮЮТЬ В ОЧІ (Ворони, Спустошене Село). Дзьоб, що влучив, засліплює:
## край екрана темніє (amount за удар), темрява тримається time секунд
## після останнього удару й поволі розсіюється. Зграя — майже ніч.

func _init() -> void:
	id = "blind_peck"
	cooldown = 0.0

func on_strike() -> void:
	if not enemy.strike_landed:
		return
	var hero := player()
	if hero != null and is_instance_valid(hero) and hero.has_method("blind"):
		hero.blind(float(config.get("amount", 0.22)), float(config.get("time", 3.0)))
