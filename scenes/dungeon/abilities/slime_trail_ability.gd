extends EnemyAbility

## ЛИПКИЙ СЛІД (склепний слиз): де повз слиз, лишаються калюжі
## (slime_puddle.gd) — герой у калюжі сповільнюється. Калюжа ляже, щойно
## слиз відповз на spacing метрів від попередньої; одночасно від одного
## слизу — не більше max (і телефону легше, і зала не тоне в калюжах).
##
## Налаштування з опису: radius, slow (частка швидкості), time (с),
## spacing (м), max.

const PUDDLE_SCRIPT := preload("res://scenes/dungeon/hazards/slime_puddle.gd")

var _last := Vector3.INF
## Без типу: висохлі калюжі тут уже звільнені, а типізований масив
## на них сварився б.
var _puddles: Array = []

func _init() -> void:
	id = "slime_trail"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	var here := enemy.global_position
	if _last == Vector3.INF:
		_last = here
		return
	var moved := here - _last
	moved.y = 0.0
	if moved.length() < float(config.get("spacing", 1.6)):
		return
	_last = here
	_puddles = _puddles.filter(func(p) -> bool: return is_instance_valid(p))
	if _puddles.size() >= int(config.get("max", 4)):
		return
	var puddle := PUDDLE_SCRIPT.spawn(world(), here, player(), float(config.get("radius", 0.8)),
		float(config.get("slow", 0.7)), float(config.get("time", 3.0)))
	_puddles.append(puddle)
