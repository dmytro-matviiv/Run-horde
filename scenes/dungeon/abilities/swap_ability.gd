extends EnemyAbility

## ОБМІН МІСЦЯМИ (Демон-перевертень, Безодня Рун). Над обома спалахують
## руни (windup) — і демон з героєм міняються місцями. Героя закидає туди,
## де стояв демон (часто — серед інших ворогів), а демон одразу б'є.
## Налаштування: min, max (відстань), windup.

const COLOR := Color(0.35, 0.9, 1.0)

var _hero_mark: MeshInstance3D

func _init() -> void:
	id = "swap"
	cooldown = 9.0
	instant = true

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 4.0)) or distance > float(config.get("max", 11.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	_hero_mark = CombatVfx.make_telegraph(Color(COLOR, 0.8), 0.9, PI, false)
	world().add_child(_hero_mark)
	_hero_mark.global_position = player().global_position + Vector3.UP * 0.05
	enemy.begin_special(id, float(config.get("windup", 0.8)), COLOR, 0.9)
	return true

func resolve() -> void:
	if _hero_mark != null and is_instance_valid(_hero_mark):
		_hero_mark.queue_free()
	_hero_mark = null
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var a := enemy.global_position
	var b := hero.global_position
	CombatVfx.shockwave(world(), a, 1.4, COLOR, 0.35)
	CombatVfx.shockwave(world(), b, 1.4, COLOR, 0.35)
	hero.global_position = Vector3(a.x, b.y, a.z)
	enemy.global_position = Vector3(b.x, a.y, b.z)
	enemy.face_point(hero.global_position)
	CombatVfx.lightning(world(), [a + Vector3.UP, b + Vector3.UP], COLOR, 0.2)

func on_death() -> void:
	if _hero_mark != null and is_instance_valid(_hero_mark):
		_hero_mark.queue_free()
