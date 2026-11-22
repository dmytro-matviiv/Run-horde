extends EnemyAbility

## ЛИНЬКА (Мулистий рак, Потонулі Сади). Коли здоров'я впало нижче за
## at — рак скидає панцир. Порожній панцир лишається стояти (приманка:
## його легко сплутати з раком і довбати даремно), а сам рак — м'який і
## швидкий: speed разів швидший, але б'ють його в soft разів сильніше.
## Раз за життя. Налаштування: at, speed, soft, shell_hp (частка hp з
## опису), shell_life.

const COLOR := Color(0.85, 0.55, 0.4)

var _molted := false

func _init() -> void:
	id = "molt"
	cooldown = 0.0

func on_damaged() -> void:
	if _molted or enemy.current_hp > enemy.max_hp * float(config.get("at", 0.5)):
		return
	_molted = true
	var spot := enemy.global_position
	var definition: Dictionary = enemy.definition
	enemy.spawn_requested.emit(spot, {
		"name": "Порожній панцир", "model": definition.model, "kind": "totem",
		"hp": float(definition.get("hp", 100.0)) * float(config.get("shell_hp", 0.45)), "damage": 0.0,
		"speed": 0.0, "height": float(definition.get("height", 1.4)), "xp": 0, "no_elite": true, "no_loot": true,
		"tint": Color(0.45, 0.42, 0.38), "lifetime": float(config.get("shell_life", 14.0)),
		"face_yaw": enemy.facing_angle(),
	}, null)
	# Рак вистрибує з панцира вбік.
	var side := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	enemy.global_position = spot + side * 1.4
	enemy.move_speed *= float(config.get("speed", 1.6))
	Enemy3D.paint_model(enemy._model, Color(1.0, 0.62, 0.55), Color(0.35, 0.08, 0.06))
	enemy._model.scale *= 0.85
	CombatVfx.smoke_puff(world(), spot + Vector3.UP * 0.6, Color(0.45, 0.4, 0.3), 1.2)
	CombatVfx.shockwave(world(), spot, 1.6, COLOR, 0.3)

func filter_damage(amount: float, _heavy: bool) -> float:
	return amount * float(config.get("soft", 1.5)) if _molted else amount
