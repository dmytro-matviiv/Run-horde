extends HeroSkill3D

## КРОВОТІК (Фенрір): на кілька секунд кожен укус відкриває рану —
## ворог кровоточить, втрачаючи здоров'я щосекунди. Прийом одразу
## кусає найближчого ворога.

const DURATION := 6.0
const BLEED_TIME := 4.0
const BLEED_PER_TICK := 0.35
const TICK := 0.5
const BITE_DAMAGE := 1.4

var _active_left := 0.0
## id ворога -> [ворог, лишилось секунд, до наступного тіку].
var _bleeding := {}

func _init() -> void:
	id = &"rend"
	title = "Кровотік"
	description = "Шість секунд кожен укус відкриває рану: ворог кровоточить і щосекунди втрачає здоров'я."
	color = Color(0.9, 0.2, 0.2)
	icon_kind = "venom"
	cooldown = 10.0

func _use(player: Node) -> bool:
	_active_left = DURATION
	var target: Node = player.get("_target")
	if is_instance_valid(target) and target is Enemy3D:
		var enemy := target as Enemy3D
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		if offset.length() < 3.0:
			player.deal_damage(enemy, BITE_DAMAGE, offset.normalized() * 1.5, true, id)
			wound(enemy)
	CombatVfx.flash_model(player.model, color, 0.25)
	player.play_form_strike(true)
	return true

## Укус під час Кровотоку — нова рана (Player3D кличе на кожен укус).
func wound(enemy: Enemy3D) -> void:
	if _active_left <= 0.0 or not is_instance_valid(enemy):
		return
	_bleeding[enemy.get_instance_id()] = [enemy, BLEED_TIME, TICK]

func is_active() -> bool:
	return _active_left > 0.0

func _update(player: Node, delta: float) -> void:
	_active_left = maxf(_active_left - delta, 0.0)
	for key: int in _bleeding.keys():
		var entry: Array = _bleeding[key]
		if not is_instance_valid(entry[0]):
			_bleeding.erase(key)
			continue
		var enemy: Enemy3D = entry[0]
		if not enemy.is_alive():
			_bleeding.erase(key)
			continue
		entry[1] = float(entry[1]) - delta
		entry[2] = float(entry[2]) - delta
		if float(entry[2]) <= 0.0:
			entry[2] = TICK
			player.deal_damage(enemy, BLEED_PER_TICK, Vector3.ZERO, false, id)
			Fx.puff(player.get_parent(), enemy.global_position + Vector3.UP * enemy.target_height * 0.5, Color(0.7, 0.05, 0.05), 0.35, 0.0)
		if float(entry[1]) <= 0.0:
			_bleeding.erase(key)
