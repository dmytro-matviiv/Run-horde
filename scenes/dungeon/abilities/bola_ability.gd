extends EnemyAbility

## БОЛАС (Ватажок розбійників). Розкрутив над головою три камені на
## мотузках — і кинув (летить туди, де герой зараз). Влучив — ноги
## сплутано: time секунд без перекату й повільніше (slow). Від боласу
## тікають кроком убік ще до кидка.

const COLOR := Color(0.7, 0.55, 0.35)

func _init() -> void:
	id = "bola"
	cooldown = 9.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 3.5)) or distance > float(config.get("max", 12.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.7)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var origin := enemy.global_position + Vector3.UP * enemy.target_height * 0.7
	var to := hero.global_position + Vector3.UP - origin
	var time := float(config.get("time", 3.0))
	var slow := float(config.get("slow", 0.7))
	var shot := enemy.spawn_shot(origin, to, COLOR, float(config.get("speed", 13.0)), damage(), func(target: Node3D) -> void:
		if target.has_method("tangle"):
			target.tangle(time, slow))
	shot.set_model(BossFx.bola())
