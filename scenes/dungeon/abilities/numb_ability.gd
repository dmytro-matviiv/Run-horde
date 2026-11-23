extends EnemyAbility

## ОБМОРОЖЕННЯ (Шаман Півночі). Його крижані кулі, що влучили, морозять
## руки героя: перезарядка всіх здібностей довшає на seconds, а перекату
## — на половину. Кілька влучань поспіль — і здібностей не дочекатись.
## Налаштування: seconds, cap.

func _init() -> void:
	id = "numb"
	cooldown = 0.0

func on_shot_hit(target: Node3D) -> void:
	if target.has_method("numb"):
		target.numb(float(config.get("seconds", 2.5)), float(config.get("cap", 8.0)))
