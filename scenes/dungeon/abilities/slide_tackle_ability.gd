extends EnemyAbility

## ПІДКАТ (Морозний таранник): при першій зустрічі, щойно побачив героя
## на відстані, розганяється й ковзає по льоду йому під ноги. Влучив, а
## герой не відкотився — збитий з ніг, підводиться за down секунд.
##
## Налаштування: min, max (відстань), speed, time (с ковзання), down (с),
## damage. Раз за життя ворога (cooldown за замовчуванням дуже довгий).

const COLOR := Color(0.75, 0.92, 1.0, 0.85)
const HIT_RADIUS := 1.3

var _busy := false
var _time_left := 0.0
var _direction := Vector3.ZERO
var _hit := false
var _line: MeshInstance3D

func _init() -> void:
	id = "slide_tackle"
	cooldown = 9999.0

func is_busy() -> bool:
	return _busy

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 3.0)) or distance > float(config.get("max", 9.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	var to_player := player().global_position - enemy.global_position
	to_player.y = 0.0
	_direction = to_player.normalized()
	var length := float(config.get("speed", 12.0)) * float(config.get("time", 0.7))
	_line = CombatVfx.make_line_telegraph(COLOR, length, 1.4, "chevrons")
	world().add_child(_line)
	_line.global_position = Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP + 0.05, enemy.global_position.z) + _direction * length * 0.5
	_line.rotation.y = atan2(_direction.x, _direction.z)
	enemy.face_point(enemy.global_position + _direction)
	enemy.begin_special(id, float(config.get("windup", 0.35)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_busy = true
	_hit = false
	_time_left = float(config.get("time", 0.7))
	enemy.play_once(["Slide", "Run"])

func tick(delta: float) -> void:
	super.tick(delta)
	if not _busy:
		return
	_time_left -= delta
	var speed := float(config.get("speed", 12.0)) * clampf(_time_left / 0.25, 0.3, 1.0)
	enemy.velocity = Vector3(_direction.x * speed, -2.0, _direction.z * speed)
	enemy.move_and_slide()
	var hero := player()
	if not _hit and hero != null and is_instance_valid(hero):
		var offset := hero.global_position - enemy.global_position
		offset.y = 0.0
		if offset.length() <= HIT_RADIUS:
			_hit = true
			if hero.take_damage(damage()) and hero.has_method("stun"):
				hero.stun(float(config.get("down", 2.0)))
				CombatVfx.shockwave(world(), hero.global_position, 1.4, COLOR, 0.3)
	if _time_left <= 0.0 or enemy.is_on_wall():
		_stop()

func on_death() -> void:
	_stop()

func _stop() -> void:
	_busy = false
	enemy.velocity = Vector3.ZERO
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	_line = null
