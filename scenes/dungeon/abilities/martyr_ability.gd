extends EnemyAbility

## МУЧЕНИЦТВО (Безликі послушники). Послушник гине — його сила переходить
## до решти послушників поруч (range): кожен стає більшим, б'є на power
## сильніше й лікується на heal. Останній — найнебезпечніший. Бий їх
## рівномірно або вибивай гурт разом.
## Налаштування: range, power, heal, grow.

const COLOR := Color(0.95, 0.9, 0.75)

func _init() -> void:
	id = "martyr"
	cooldown = 0.0

func on_death() -> void:
	var reach := float(config.get("range", 12.0))
	for node in enemy.get_parent().get_children():
		var other := node as Enemy3D
		if other == null or other == enemy or not other.is_alive():
			continue
		if other.global_position.distance_to(enemy.global_position) > reach:
			continue
		var heir := false
		for ability in other.abilities:
			if ability.id == id:
				heir = true
				break
		if not heir:
			continue
		other.damage *= 1.0 + float(config.get("power", 0.3))
		other.heal(other.max_hp * float(config.get("heal", 0.25)))
		other._model.scale *= 1.0 + float(config.get("grow", 0.12))
		CombatVfx.glow_orb(world(), enemy.global_position + Vector3.UP, other, other.target_height * 0.6, COLOR, 0.4)
