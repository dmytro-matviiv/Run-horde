extends EnemyAbility

## КИДОК (Кам'яний титан). Титан хапає героя (коло під ним, windup) і
## шпурляє геть від себе (power м/с). Влетів у стіну — удар об камінь
## (damage) і оглушення на stun секунд. Тримайся посеред зали, коли
## титан поруч, або вискакуй з кола перекатом.
## Налаштування: reach, windup, power, stun, damage.

const COLOR := Color(0.75, 0.75, 0.7)

var _flight_left := 0.0

func _init() -> void:
	id = "hurl"
	cooldown = 10.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("reach", 2.4)):
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), COLOR, float(config.get("reach", 2.4)))
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - enemy.global_position
	offset.y = 0.0
	if offset.length() > float(config.get("reach", 2.4)) + 0.3:
		return
	if not hero.take_damage(damage() * 0.4):
		return
	var away := offset.normalized() if offset.length() > 0.1 else enemy.model_forward()
	away = away.rotated(Vector3.UP, randf_range(-0.3, 0.3))
	if hero.has_method("knock_down"):
		hero.knock_down(away * float(config.get("power", 16.0)), 1.0)
	_flight_left = 1.0
	CombatVfx.ground_hit(world(), enemy.global_position, 1.4)

func tick(delta: float) -> void:
	super.tick(delta)
	if _flight_left <= 0.0:
		return
	_flight_left -= delta
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		_flight_left = 0.0
		return
	if hero is CharacterBody3D and (hero as CharacterBody3D).is_on_wall():
		_flight_left = 0.0
		CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
		CombatVfx.smoke_puff(world(), hero.global_position + Vector3.UP, Color(0.6, 0.6, 0.55), 1.2)
		hero.take_damage(damage())
		if hero.has_method("stun"):
			hero.stun(float(config.get("stun", 1.3)))
