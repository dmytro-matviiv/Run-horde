extends EnemyAbility

## КОЛОВЕРТЬ ВОГНЮ (Владика Магми). Довкола Владики спалахують count
## вогняних куль і кружляють, розходячись спіраллю від inner до outer
## метрів за time секунд. Куля зачепила героя — шкода. Між кулями є
## проміжки: проскакуй у них або тримайся подалі.
## Налаштування: count, inner, outer, spin (рад/с), time, damage.

const COLOR := Color(1.0, 0.55, 0.15)

var _balls: Array = []
var _time_left := 0.0
var _angle := 0.0
var _hit_left := 0.0

func _init() -> void:
	id = "orbit_flames"
	cooldown = 14.0

func try_use(_distance: float) -> bool:
	if _time_left > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.6)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_clear()
	# Вогняні кулі: ядро з лави, полум'яний ореол і слід (BossFx.fireball).
	for i in int(config.get("count", 4)):
		var ball := BossFx.fireball(1.5)
		world().add_child(ball)
		ball.global_position = enemy.global_position + Vector3.UP
		_balls.append(ball)
	_time_left = float(config.get("time", 7.0))
	_angle = randf() * TAU

func tick(delta: float) -> void:
	super.tick(delta)
	if _time_left <= 0.0:
		return
	_time_left -= delta
	var time := float(config.get("time", 7.0))
	var t := clampf(1.0 - _time_left / time, 0.0, 1.0)
	var radius := lerpf(float(config.get("inner", 1.6)), float(config.get("outer", 7.0)), t)
	_angle += float(config.get("spin", 1.7)) * delta
	var hero := player()
	_hit_left -= delta
	var count := _balls.size()
	for i in count:
		var ball: Node3D = _balls[i]
		var a := _angle + TAU * i / count
		ball.global_position = enemy.global_position + Vector3(cos(a), 0.0, sin(a)) * radius + Vector3.UP * 1.0
		if hero != null and is_instance_valid(hero) and _hit_left <= 0.0:
			var off := hero.global_position + Vector3.UP - ball.global_position
			if off.length() <= 0.85:
				_hit_left = 0.6
				if hero.take_damage(damage()):
					CombatVfx.impact(world(), ball.global_position, COLOR, true)
	if _time_left <= 0.0:
		_clear()

func on_death() -> void:
	_clear()

func _clear() -> void:
	_time_left = 0.0
	for ball in _balls:
		if is_instance_valid(ball):
			CombatVfx.smoke_puff(world(), ball.global_position, Color(0.4, 0.3, 0.25), 0.6)
			ball.queue_free()
	_balls.clear()
