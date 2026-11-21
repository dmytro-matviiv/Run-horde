extends EnemyAbility

## ЗОЛОТИЙ ПИЛ (Золота оса, Скарбниця Тіней). Кожне жало, що влучило,
## обсипає героя золотим пилом: шар — +6% до всієї шкоди, яку герой
## отримує (Player3D.add_gold_dust), до stacks шарів, тримається time с
## після останнього жала. Рій треба розбивати швидко, а не терпіти.

func _init() -> void:
	id = "gold_dust"
	cooldown = 0.0

func on_strike() -> void:
	if not enemy.strike_landed:
		return
	var hero := player()
	if hero != null and is_instance_valid(hero) and hero.has_method("add_gold_dust"):
		hero.add_gold_dust(int(config.get("stacks", 5)), float(config.get("time", 4.0)))
