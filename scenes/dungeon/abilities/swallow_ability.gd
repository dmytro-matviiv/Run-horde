extends EnemyAbility

## ПОГЛИНАННЯ (Королева Трясовини). Королева роззявляє пащу перед собою
## (червоний сектор, windup). Не встиг відскочити — герой проковтнутий:
## його не видно, ні кроку, ні перекату, щоevery секунд перетравлення
## (digest). Але зсередини б'ється в inside разів сильніше: вибив
## break (частку здоров'я Королеви) — вона випльовує героя й на stun
## секунд захлинається. Ні — за time секунд випльовує сама.
## Налаштування: reach, arc, windup, time, every, digest, inside, break, stun.

const COLOR := Color(0.85, 0.2, 0.35)

var _inside_left := 0.0
var _digest_left := 0.0
var _dealt := 0.0
var _mark: MeshInstance3D

func _init() -> void:
	id = "swallow"
	cooldown = 16.0

func try_use(distance: float) -> bool:
	if _inside_left > 0.0 or distance > float(config.get("reach", 3.6)) - 0.4:
		return false
	start_cooldown()
	enemy.face_point(player().global_position)
	var reach := float(config.get("reach", 3.6))
	_mark = CombatVfx.make_telegraph(Color(COLOR, 0.7), reach, deg_to_rad(float(config.get("arc", 70.0))) * 0.5, false)
	enemy.add_child(_mark)
	_mark.position = Vector3.UP * 0.06
	_mark.rotation.y = enemy.facing_angle() - enemy.rotation.y
	enemy.begin_special(id, float(config.get("windup", 1.0)), Color(COLOR, 0.0), 0.1)
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	if _mark != null and is_instance_valid(_mark):
		var progress := float(_mark.get_meta("p", 0.0)) + delta / float(config.get("windup", 1.0))
		_mark.set_meta("p", progress)
		CombatVfx.set_param(_mark, &"progress", clampf(progress, 0.0, 1.0))
		if progress > 1.8:
			_clear_mark()
	if _inside_left <= 0.0:
		return
	_inside_left -= delta
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		_inside_left = 0.0
		return
	hero.global_position = _mouth()
	_digest_left -= delta
	if _digest_left <= 0.0:
		_digest_left = float(config.get("every", 0.6))
		hero.take_damage(damage() * float(config.get("digest", 0.3)))
	if _inside_left <= 0.0:
		_spit(false)

func resolve() -> void:
	_clear_mark()
	var hero := player()
	if hero == null or not is_instance_valid(hero) or not hero.has_method("set_swallowed"):
		return
	var offset := hero.global_position - enemy.global_position
	offset.y = 0.0
	var forward := enemy.model_forward()
	var half := deg_to_rad(float(config.get("arc", 70.0))) * 0.5
	if offset.length() > float(config.get("reach", 3.6)) or (offset.length() > 0.5 and forward.angle_to(offset.normalized()) > half):
		CombatVfx.ground_hit(world(), enemy.global_position + forward * 2.0, 1.2)
		return
	# Перекат у мить змикання щелеп рятує (як від удару).
	if not hero.take_damage(damage() * 0.5):
		return
	hero.set_swallowed(true)
	hero.root(float(config.get("time", 3.5)) + 0.2)
	_inside_left = float(config.get("time", 3.5))
	_digest_left = float(config.get("every", 0.6))
	_dealt = 0.0
	hero.global_position = _mouth()
	CombatVfx.impact(world(), _mouth() + Vector3.UP, COLOR, true)

func is_busy() -> bool:
	return _inside_left > 0.0

func filter_damage(amount: float, _heavy: bool) -> float:
	if _inside_left <= 0.0:
		return amount
	var boosted := amount * float(config.get("inside", 2.5))
	_dealt += boosted
	if _dealt >= enemy.max_hp * float(config.get("break", 0.04)):
		_spit.call_deferred(true)
	return boosted

func _mouth() -> Vector3:
	var spot := enemy.global_position + enemy.model_forward() * (enemy.target_height * 0.22 + 0.6)
	return Vector3(spot.x, player().global_position.y, spot.z)

func _spit(broke_free: bool) -> void:
	if _inside_left <= 0.0 and broke_free:
		return
	_inside_left = 0.0
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	hero.set_swallowed(false)
	hero.set("_rooted_left", 0.0)
	var push := enemy.model_forward() * 7.0
	if hero.has_method("knock_down"):
		hero.knock_down(push, 0.45)
	CombatVfx.smoke_puff(world(), hero.global_position + Vector3.UP, Color(0.4, 0.7, 0.4), 1.2)
	if broke_free:
		CombatVfx.shockwave(world(), enemy.global_position, 3.0, Color(0.5, 1.0, 0.6), 0.4)
		enemy.stun_for(float(config.get("stun", 2.0)))

func on_death() -> void:
	_clear_mark()
	if _inside_left > 0.0:
		_spit(false)

func _clear_mark() -> void:
	if _mark != null and is_instance_valid(_mark):
		_mark.queue_free()
	_mark = null
