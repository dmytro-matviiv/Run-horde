extends EnemyAbility

## СКАРБИ-ПРИМАНКИ (Золотий Скупар). Бос гупає скіпетром — по залі
## з'являються count однакових скринь. Одна справжня: підійшов — лікує
## героя (heal — частка здоров'я) і сипле золото. Решта — міміки, що
## кусаються й крадуть золото. Яку відчиняти — вирішує гравець.
## Налаштування: count, mimic (опис міміка), heal, gold, spread (м).

const COLOR := Color(1.0, 0.82, 0.3)

func _init() -> void:
	id = "decoy_chests"
	cooldown = 20.0

func try_use(_distance: float) -> bool:
	if enemy.summons_alive > 0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var mimic: Dictionary = config.get("mimic", {})
	if mimic.is_empty():
		return
	var count := int(config.get("count", 3))
	var real := randi() % count
	var spread := float(config.get("spread", 4.5))
	var forward := enemy.model_forward()
	for i in count:
		var angle := (i - (count - 1) * 0.5) * 0.75
		var spot := enemy.global_position + forward.rotated(Vector3.UP, angle) * spread
		var chest := mimic.duplicate(true)
		chest.xp = 0
		chest.no_elite = true
		if i == real:
			chest.kind = "totem"
			chest.erase("abilities")
			chest.abilities = [{"id": "treasure", "heal": float(config.get("heal", 0.2)), "gold": int(config.get("gold", 40))}]
		enemy.spawn_requested.emit(spot, chest, enemy)
		CombatVfx.shockwave(world(), spot, 1.2, COLOR, 0.3)
