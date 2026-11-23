extends EnemyAbility

## ТАБУ (Жрець Забутих). Жрець вимовляє заборону: time секунд над героєм
## напис «НЕ УХИЛЯЙСЯ». Перекотився за цей час — кара: damage і
## оглушення на stun секунд. Від ударів доводиться відходити кроком.
## Налаштування: min, max, windup, time, stun, damage.

const COLOR := Color(1.0, 0.85, 0.4)

var _until := 0

func _init() -> void:
	id = "taboo"
	cooldown = 12.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 2.5)) or distance > float(config.get("max", 11.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero) or not hero.has_method("set_taboo"):
		return
	var time := float(config.get("time", 5.0))
	hero.set_taboo(time)
	_until = Time.get_ticks_msec() + int(time * 1000.0)
	if not hero.taboo_broken.is_connected(_punish):
		hero.taboo_broken.connect(_punish)
	CombatVfx.lightning(world(), [enemy.global_position + Vector3.UP * enemy.target_height * 0.8, hero.global_position + Vector3.UP * 1.8], COLOR, 0.25)

func _punish() -> void:
	if Time.get_ticks_msec() > _until or enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	_until = 0
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	CombatVfx.lightning(world(), [hero.global_position + Vector3.UP * 6.0, hero.global_position + Vector3.UP * 0.5], COLOR, 0.3)
	CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
	if hero.has_method("stun"):
		hero.stun(float(config.get("stun", 1.2)))
	hero.set("_invulnerable_left", 0.0)
	hero.take_damage(damage())

func on_death() -> void:
	var hero := player()
	if hero != null and is_instance_valid(hero) and hero.has_signal("taboo_broken") and hero.taboo_broken.is_connected(_punish):
		hero.taboo_broken.disconnect(_punish)
