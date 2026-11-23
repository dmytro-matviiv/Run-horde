extends EnemyAbility

## ЗАМЕТ (Сніговий велетень). Велетень здіймає кулаки й гупає об землю
## (коло radius, windup). Не вискочив — героя по пояс замело: ні кроку,
## ні перекату, доки не відкопається. Рух джойстиком (чи клавішами)
## розгрібає сніг утричі швидше — тисни, а не чекай.
## Налаштування: trigger (м до героя), radius, windup, time, damage.

const COLOR := Color(0.85, 0.95, 1.0)

func _init() -> void:
	id = "snow_bury"
	cooldown = 9.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("trigger", 3.0)):
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 1.0)), COLOR, float(config.get("radius", 2.6)))
	return true

func resolve() -> void:
	var center := enemy.global_position
	CombatVfx.ground_hit(world(), center, float(config.get("radius", 2.6)))
	CombatVfx.smoke_puff(world(), center + Vector3.UP * 0.5, COLOR, 2.4)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - center
	offset.y = 0.0
	if offset.length() > float(config.get("radius", 2.6)) + 0.3:
		return
	if hero.take_damage(damage()) and hero.has_method("bury"):
		hero.bury(float(config.get("time", 3.0)))
