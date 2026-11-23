extends EnemyAbility

## КОНТРАТАКА (Ватажок розбійників). Ватажок стає в стійку (time с):
## тесак перед собою, над ним блищить. Удар героя в цю мить шкоди не
## завдає — і Ватажок одразу б'є у відповідь (damage), якщо герой ближче
## за reach. Перечекай стійку — і тоді бий.

const COLOR := Color(1.0, 0.9, 0.55)

var _left_time := 0.0
var _countered := false
var _glint: MeshInstance3D

func _init() -> void:
	id = "riposte"
	cooldown = 12.0

func is_busy() -> bool:
	return _left_time > 0.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("near", 5.0)):
		return false
	start_cooldown()
	_left_time = float(config.get("time", 1.8))
	_countered = false
	enemy.hold_still(_left_time)
	enemy.face_player(100.0)
	enemy.play_loop("Block")
	# Зблиск на клинку: Ватажок у стійці, вдариш — відповість.
	_glint = BossFx.glint(Color(COLOR, 0.95))
	enemy.add_child(_glint)
	_glint.position = Vector3.UP * enemy.target_height * 0.62 + enemy.model_forward() * 0.6
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	if _left_time <= 0.0:
		return
	_left_time -= delta
	enemy.velocity = Vector3.ZERO
	if _left_time <= 0.0:
		_clear()

func filter_damage(amount: float, _heavy: bool) -> float:
	if _left_time <= 0.0:
		return amount
	CombatVfx.impact(world(), enemy.global_position + Vector3.UP * enemy.target_height * 0.6, COLOR, true)
	if not _countered:
		_countered = true
		var hero := player()
		if hero != null and is_instance_valid(hero):
			var offset := hero.global_position - enemy.global_position
			offset.y = 0.0
			enemy.play_once(["Weapon"])
			if offset.length() <= float(config.get("reach", 4.5)):
				hero.take_damage(damage())
				CombatVfx.slash(world(), enemy.global_position + Vector3.UP * 1.2, atan2(offset.x, offset.z), 3.0, 120.0, COLOR)
		_left_time = minf(_left_time, 0.35)
	return 0.0

func on_death() -> void:
	_left_time = 0.0
	_clear()

func _clear() -> void:
	if _glint != null and is_instance_valid(_glint):
		_glint.queue_free()
	_glint = null
