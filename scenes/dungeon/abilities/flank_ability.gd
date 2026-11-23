extends EnemyAbility

## УДАР У СПИНУ (Снігові вовки). Вовк, що вкусив героя ЗЗАДУ (зі спини,
## поза його поглядом), б'є в factor разів сильніше. Зграя кружляє й
## заходить ззаду — не підставляй спину, тримай вовків перед собою.
## Налаштування: factor, angle (градусів від спини, що вважаються "ззаду").

const COLOR := Color(0.6, 0.85, 1.0)

var _base := -1.0

func _init() -> void:
	id = "flank"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	var hero := player()
	if hero == null or not is_instance_valid(hero) or not hero.has_method("facing_vector"):
		return
	if _base < 0.0:
		_base = enemy.damage
	# Шкода перед кожним укусом — за тим, звідки вовк зараз.
	var from := enemy.global_position - hero.global_position
	from.y = 0.0
	var behind := false
	if from.length() > 0.05:
		var facing: Vector3 = hero.facing_vector()
		facing.y = 0.0
		behind = facing.normalized().angle_to(from.normalized()) >= PI - deg_to_rad(float(config.get("angle", 70.0)))
	enemy.damage = _base * (float(config.get("factor", 2.0)) if behind else 1.0)

func on_strike() -> void:
	if enemy.strike_landed and _base > 0.0 and enemy.damage > _base * 1.01:
		var hero := player()
		CombatVfx.impact(world(), hero.global_position + Vector3.UP * 1.1, COLOR, true)
