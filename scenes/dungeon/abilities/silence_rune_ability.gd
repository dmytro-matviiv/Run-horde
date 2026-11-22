extends EnemyAbility

## КОЛО МОВЧАННЯ (Рунний писар, Безодня Рун). Писар виводить на підлозі
## під героєм рунне коло (radius), що горить time секунд. Хто в ньому —
## мовчить: здібності не застосовуються (Player3D.silence). Вийди з кола —
## і за мить знову можеш.

const COLOR := Color(0.35, 0.9, 1.0, 0.85)

var _center := Vector3.ZERO
var _left_time := 0.0
var _circle: MeshInstance3D

func _init() -> void:
	id = "silence_rune"
	cooldown = 10.0
	instant = true

func try_use(distance: float) -> bool:
	if _left_time > 0.0 or distance > float(config.get("max", 12.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.6)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_center = hero.global_position
	_center.y = DungeonBuilder.FLOOR_TOP
	_left_time = float(config.get("time", 5.0))
	_circle = CombatVfx.make_telegraph(COLOR, float(config.get("radius", 2.6)), PI, true)
	world().add_child(_circle)
	_circle.global_position = _center + Vector3.UP * 0.05
	CombatVfx.set_param(_circle, &"progress", 1.0)
	CombatVfx.shockwave(world(), _center, float(config.get("radius", 2.6)), COLOR, 0.35)

func tick(delta: float) -> void:
	super.tick(delta)
	if _left_time <= 0.0:
		return
	_left_time -= delta
	var hero := player()
	if hero != null and is_instance_valid(hero) and hero.has_method("silence"):
		var offset := hero.global_position - _center
		offset.y = 0.0
		if offset.length() <= float(config.get("radius", 2.6)):
			hero.silence(0.3)
	if _circle != null and is_instance_valid(_circle):
		_circle.rotation.y += delta * 0.8
	if _left_time <= 0.0:
		_clear()

func on_death() -> void:
	_left_time = 0.0
	_clear()

func _clear() -> void:
	if _circle != null and is_instance_valid(_circle):
		_circle.queue_free()
	_circle = null
