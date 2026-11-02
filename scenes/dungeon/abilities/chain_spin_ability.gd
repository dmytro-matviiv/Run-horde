extends EnemyAbility

## ОБЕРТАННЯ ЛАНЦЮГОМ (Хранитель Склепів): герой близько — бос розкручує
## ланцюг із ключами довкола себе. Червоне коло radius показує, куди
## дістає; поки крутить (spin секунд), кожні TICK секунд б'є всіх у колі.
## Близько не підходь — відійди й зачекай.

const COLOR := Color(1.0, 0.3, 0.2, 0.85)
const TICK := 0.45
const WINDUP := 0.6

var _busy := false
var _time_left := 0.0
var _tick_left := 0.0
var _ring: MeshInstance3D

func _init() -> void:
	id = "chain_spin"
	cooldown = 9.0

func is_busy() -> bool:
	return _busy

func try_use(distance: float) -> bool:
	if distance > float(config.get("trigger", 4.0)):
		return false
	start_cooldown()
	enemy.begin_special(id, WINDUP, COLOR, float(config.get("radius", 3.2)))
	return true

func resolve() -> void:
	_busy = true
	_time_left = float(config.get("spin", 2.2))
	_tick_left = 0.1
	var radius := float(config.get("radius", 3.2))
	_ring = CombatVfx.make_telegraph(COLOR, radius, PI, true)
	CombatVfx.set_param(_ring, &"progress", 1.0)
	enemy.add_child(_ring)
	_ring.position = Vector3(0, 0.05, 0)
	enemy.play_loop("Spin")

func tick(delta: float) -> void:
	super.tick(delta)
	if not _busy:
		return
	_time_left -= delta
	enemy.play_loop("Spin")
	if _ring != null:
		_ring.rotation.y += delta * 9.0
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = TICK
		var radius := float(config.get("radius", 3.2))
		CombatVfx.shockwave(world(), enemy.global_position, radius, Color(0.85, 0.8, 0.7, 0.6), 0.3)
		var hero := player()
		if hero != null and is_instance_valid(hero):
			var offset := hero.global_position - enemy.global_position
			offset.y = 0.0
			if offset.length() <= radius:
				hero.take_damage(damage())
	if _time_left <= 0.0:
		_stop()

func on_death() -> void:
	_stop()

func _stop() -> void:
	_busy = false
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
