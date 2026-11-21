extends EnemyAbility

## МАГНІТ ГОРНА (Володар Горна). Бос розкидає руки — і time секунд тягне
## усе залізне (героя) до себе, а довкола нього палає кільце горна
## (radius): хто дав себе затягти — горить. Тікати від нього, поки тягне.
## Налаштування: time, pull (м/с), radius, damage (частка за тік вогню).

const COLOR := Color(1.0, 0.4, 0.1)

var _left_time := 0.0
var _sparks: CPUParticles3D

func _init() -> void:
	id = "magnet"
	cooldown = 15.0

func is_busy() -> bool:
	return _left_time > 0.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("radius", 2.6)) + 2.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.7)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var time := float(config.get("time", 3.0))
	_left_time = time
	enemy.hold_still(time)
	enemy.play_loop("Cast")
	var radius := float(config.get("radius", 2.6))
	HazardPool.spawn(world(), Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP, enemy.global_position.z),
		player(), radius, damage() * float(config.get("tick", 0.25)), time + 0.5, COLOR)
	_sparks = CombatVfx.make_motes(Color(1.0, 0.6, 0.2), 24, 6.0, 0.4, 0.12)
	world().add_child(_sparks)
	_sparks.global_position = enemy.global_position + Vector3.UP * 0.8

func tick(delta: float) -> void:
	super.tick(delta)
	if _left_time <= 0.0:
		return
	_left_time -= delta
	var hero := player()
	if hero != null and is_instance_valid(hero) and hero.has_method("apply_pull"):
		var to := enemy.global_position - hero.global_position
		to.y = 0.0
		if to.length() > 0.6:
			hero.apply_pull(to.normalized() * float(config.get("pull", 3.0)))
	if _left_time <= 0.0:
		_finish()

func on_death() -> void:
	_left_time = 0.0
	_finish()

func _finish() -> void:
	if _sparks != null and is_instance_valid(_sparks):
		_sparks.emitting = false
		_sparks.get_tree().create_timer(1.0).timeout.connect(_sparks.queue_free)
	_sparks = null
