extends EnemyAbility

## ВІДСКОК (Мисливець, Спустошене Село). Герой підійшов ближче за near —
## мисливець відскакує назад (distance м за time с) і в стрибку стріляє.
## (Стріли мисливця летять на випередження — "lead" у "projectile".)

const COLOR := Color(0.78, 0.8, 0.86)

var _left_time := 0.0
var _away := Vector3.ZERO
var _shot := false

func _init() -> void:
	id = "disengage"
	# Не чекає перерви між звичайними ударами.
	instant = true
	cooldown = 5.0

func is_busy() -> bool:
	return _left_time > 0.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("near", 3.0)):
		return false
	start_cooldown()
	var from := enemy.global_position - player().global_position
	from.y = 0.0
	_away = from.normalized() if from.length() > 0.1 else -enemy.model_forward()
	_left_time = float(config.get("time", 0.35))
	_shot = false
	enemy.face_point(player().global_position)
	enemy.play_once(["Jump", "Weapon"])
	CombatVfx.smoke_puff(world(), enemy.global_position, Color(0.6, 0.55, 0.45, 0.6), 1.0)
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	if _left_time <= 0.0:
		return
	_left_time -= delta
	var speed := float(config.get("distance", 4.0)) / float(config.get("time", 0.35))
	enemy.velocity = Vector3(_away.x * speed, -2.0, _away.z * speed)
	enemy.move_and_slide()
	enemy.face_point(player().global_position)
	if not _shot and _left_time <= float(config.get("time", 0.35)) * 0.5:
		_shot = true
		var origin := enemy.global_position + Vector3.UP * enemy.target_height * 0.7
		var to := player().global_position + Vector3.UP - origin
		enemy.spawn_shot(origin, to, COLOR, 12.0, enemy.damage)
	if _left_time <= 0.0:
		enemy.velocity = Vector3.ZERO
