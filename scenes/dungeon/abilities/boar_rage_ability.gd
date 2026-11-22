extends EnemyAbility

## ЛЮТЬ ВЕПРА (Дикий вепр, Спустошене Село). Кожен удар по вепру лютить
## його: +speed швидкості й +power шкоди за шар (до stacks). Без ударів
## calm секунд — лють спадає. Довго колупати — погана ідея: бий сильно
## й швидко або оглуши.

const COLOR := Color(1.0, 0.25, 0.15)

var _stacks := 0
var _calm_left := 0.0
var _base_speed := -1.0
var _base_damage := -1.0

func _init() -> void:
	id = "boar_rage"
	cooldown = 0.0

func on_damaged() -> void:
	if _base_speed < 0.0:
		_base_speed = enemy.move_speed
		_base_damage = enemy.damage
	_stacks = mini(_stacks + 1, int(config.get("stacks", 6)))
	_calm_left = float(config.get("calm", 4.0))
	_apply()
	CombatVfx.flash_model(enemy, COLOR, 0.15)
	if _stacks == int(config.get("stacks", 6)):
		CombatVfx.shockwave(world(), enemy.global_position, 1.6, COLOR, 0.3)

func tick(delta: float) -> void:
	super.tick(delta)
	if _stacks <= 0:
		return
	_calm_left -= delta
	if _calm_left <= 0.0:
		_stacks = 0
		_apply()

func _apply() -> void:
	if _base_speed < 0.0:
		return
	enemy.move_speed = _base_speed * (1.0 + float(config.get("speed", 0.08)) * _stacks)
	enemy.damage = _base_damage * (1.0 + float(config.get("power", 0.1)) * _stacks)
