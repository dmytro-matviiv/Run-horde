extends EnemyAbility

## СИСУНИ МАНИ (Імпи Безодні). Укус, що влучив, висмоктує amount мани —
## синя іскорка летить з героя в імпа. Рій імпів лишає без здібностей.

const COLOR := Color(0.35, 0.6, 1.0)

func _init() -> void:
	id = "mana_bite"
	cooldown = 0.0

func on_strike() -> void:
	if not enemy.strike_landed:
		return
	var hero := player()
	if hero == null or not is_instance_valid(hero) or not hero.has_method("drain_mana"):
		return
	if float(hero.drain_mana(float(config.get("amount", 8.0)))) > 0.0:
		CombatVfx.glow_orb(world(), hero.global_position + Vector3.UP, enemy, enemy.target_height * 0.5, COLOR, 0.3)
