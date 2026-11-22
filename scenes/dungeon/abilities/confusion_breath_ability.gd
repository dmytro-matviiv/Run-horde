extends EnemyAbility

## ПОДИХ ПЛУТАНИНИ (Малий дракон Безодні). Конус фіолетового туману
## (range м, кут arc): хто в ньому — time секунд керування навиворіт
## (Player3D.confuse). Вліво — вправо, вперед — назад.

const COLOR := Color(0.8, 0.35, 1.0, 0.85)

var _forward := Vector3.FORWARD

func _init() -> void:
	id = "confusion_breath"
	cooldown = 10.0
	instant = true

func try_use(distance: float) -> bool:
	if distance > float(config.get("range", 6.0)) - 0.5 or not enemy.sees_player():
		return false
	start_cooldown()
	var to := player().global_position - enemy.global_position
	to.y = 0.0
	_forward = to.normalized() if to.length() > 0.1 else enemy.model_forward()
	enemy.face_point(player().global_position)
	enemy.begin_special(id, float(config.get("windup", 0.7)), COLOR, float(config.get("range", 6.0)))
	return true

func resolve() -> void:
	var hero := player()
	var reach := float(config.get("range", 6.0))
	var half := deg_to_rad(float(config.get("arc", 50.0)))
	for i in 6:
		var spot := enemy.global_position + _forward.rotated(Vector3.UP, randf_range(-half, half)) * randf_range(1.0, reach)
		CombatVfx.smoke_puff(world(), spot + Vector3.UP * 0.8, COLOR, 1.4)
	if hero == null or not is_instance_valid(hero):
		return
	var to := hero.global_position - enemy.global_position
	to.y = 0.0
	if to.length() <= reach and _forward.angle_to(to.normalized()) <= half and hero.has_method("confuse"):
		if hero.take_damage(damage() * float(config.get("damage_share", 0.4))):
			hero.confuse(float(config.get("time", 3.0)))
