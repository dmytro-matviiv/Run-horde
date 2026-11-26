extends EnemyAbility

## КАРА З НЕБА (Демон-кат). Кат відхиляється назад, заносячи сокиру над
## головою (windup), — на місці героя з'являється тьмяне коло. Тоді він
## стрибає дугою й рубає з льоту: хто в колі — удар; сокира розколює
## підлогу, і вперед на length м біжить лавова тріщина, що пече burn
## секунд. Відкотись убік від кола і не стій на тріщині.
## Налаштування: min, max, windup, flight, radius, length, burn, damage.

const COLOR := Color(1.0, 0.42, 0.1)

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _fly_left := 0.0
var _mark: MeshInstance3D
var _crack: MeshInstance3D
var _crack_from := Vector3.ZERO
var _crack_dir := Vector3.FORWARD
var _burn_left := 0.0
var _tick_left := 0.0

func _init() -> void:
	id = "cleave_leap"
	cooldown = 8.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 3.0)) or distance > float(config.get("max", 9.0)) or _fly_left > 0.0:
		return false
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.7))
	_from = enemy.global_position
	_to = hero.global_position
	_to.y = _from.y
	enemy.face_point(_to)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	BossFx.gesture(enemy.get("_model") as Node3D, 26.0, 0.08, windup, 0.3)
	_mark = BossFx.floor_disc(BossFx.lava_material(0.15, 0.45), float(config.get("radius", 1.7)))
	world().add_child(_mark)
	_mark.global_position = Vector3(_to.x, DungeonBuilder.FLOOR_TOP + 0.04, _to.z)
	return true

func resolve() -> void:
	_fly_left = float(config.get("flight", 0.5))
	var trail := CombatVfx.make_trail(COLOR, 0.4)
	enemy.add_child(trail)
	trail.position = Vector3.UP * 1.2
	enemy.get_tree().create_timer(_fly_left + 0.3).timeout.connect(trail.queue_free)

func tick(delta: float) -> void:
	super.tick(delta)
	if _fly_left > 0.0:
		_fly_left -= delta
		var flight := float(config.get("flight", 0.5))
		var t := clampf(1.0 - _fly_left / flight, 0.0, 1.0)
		var point := _from.lerp(_to, t) + Vector3.UP * sin(t * PI) * 2.6
		enemy.teleport_to(point)
		if _fly_left <= 0.0:
			_land()
	elif _mark != null and String(enemy.get("_special")) != id:
		# Замах збили — коло гасне.
		_mark.queue_free()
		_mark = null
	if _burn_left > 0.0:
		_burn_left -= delta
		_tick_left -= delta
		var hero := player()
		if hero != null and is_instance_valid(hero) and _tick_left <= 0.0:
			var off := hero.global_position - _crack_from
			off.y = 0.0
			var along := off.dot(_crack_dir)
			if along > 0.0 and along < float(config.get("length", 5.0)) and (off - _crack_dir * along).length() < 0.55:
				_tick_left = 0.5
				if hero.take_damage(damage() * 0.3):
					CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.5, COLOR, false)
		if _burn_left <= 0.0 and _crack != null and is_instance_valid(_crack):
			var node := _crack
			var tween := node.create_tween()
			tween.tween_method(func(v: float) -> void: BossFx.set_heat(node, v, v), 1.0, 0.0, 0.6)
			tween.tween_callback(node.queue_free)
			_crack = null

func _land() -> void:
	var spot := Vector3(_to.x, DungeonBuilder.FLOOR_TOP, _to.z)
	enemy.teleport_to(Vector3(_to.x, _from.y, _to.z))
	if _mark != null and is_instance_valid(_mark):
		_mark.queue_free()
	_mark = null
	CombatVfx.ground_hit(world(), spot, 1.5)
	Fx.flipbook(world(), spot + Vector3.UP * 0.1, "fire_ring", 3.4, COLOR, 0.5, true, false, true, 0.5)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.15)
	var hero := player()
	if hero != null and is_instance_valid(hero):
		var off := hero.global_position - spot
		off.y = 0.0
		if off.length() <= float(config.get("radius", 1.7)) and hero.take_damage(damage()):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
	# Тріщина лави вперед від місця удару.
	_crack_dir = (_to - _from)
	_crack_dir.y = 0.0
	_crack_dir = _crack_dir.normalized() if _crack_dir.length() > 0.1 else Vector3.FORWARD
	_crack_from = spot
	var length := float(config.get("length", 5.0))
	if _crack != null and is_instance_valid(_crack):
		_crack.queue_free()
	_crack = BossFx.lava_strip(length, 0.9)
	world().add_child(_crack)
	_crack.global_position = spot + Vector3.UP * 0.05 + _crack_dir * length * 0.5
	_crack.rotation.y = atan2(_crack_dir.x, _crack_dir.z)
	BossFx.set_heat(_crack, 1.0, 1.0)
	_burn_left = float(config.get("burn", 3.0))
	_tick_left = 0.2

func is_busy() -> bool:
	return _fly_left > 0.0

func on_death() -> void:
	_fly_left = 0.0
	for node: Variant in [_mark, _crack]:
		if node != null and is_instance_valid(node):
			(node as Node).queue_free()
	_mark = null
	_crack = null
