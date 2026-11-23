extends EnemyAbility

## ПРОВАЛЛЯ (Ярл Вічної Зими). Ярл б'є сокирою об кригу — довкола героя
## (і під ним) тріщать count плит (warn секунд світяться тріщини), а тоді
## провалюються в чорну воду на time секунд. Хто в ополонці — шкода,
## героя викидає на край, де він стояв востаннє, і він на мить
## задубілий. Поки ополонки відкриті, зала тісніша.
## Налаштування: count, size (м сторона плити), near/far, warn, time, stun, damage.

const COLOR := Color(0.55, 0.8, 1.0, 0.85)
const WATER := Color(0.02, 0.06, 0.1, 0.95)

var _holes: Array = []
var _warn_left := 0.0
var _open_left := 0.0
var _safe := Vector3.INF

func _init() -> void:
	id = "crack_floor"
	cooldown = 17.0

func try_use(_distance: float) -> bool:
	if _warn_left > 0.0 or _open_left > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_clear()
	CombatVfx.ground_hit(world(), enemy.global_position + enemy.model_forward() * 1.5, 1.6)
	var size := float(config.get("size", 2.2))
	var center := Vector3(hero.global_position.x, DungeonBuilder.FLOOR_TOP, hero.global_position.z)
	var spots: Array = [center]
	var count := int(config.get("count", 5))
	var tries := 0
	while spots.size() < count and tries < 60:
		tries += 1
		var angle := randf() * TAU
		var spot: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(float(config.get("near", 2.4)), float(config.get("far", 5.5)))
		var free := true
		for other: Vector3 in spots:
			if other.distance_to(spot) < size * 1.05:
				free = false
				break
		if free:
			spots.append(spot)
	for spot: Vector3 in spots:
		var mark := CombatVfx.make_line_telegraph(COLOR, size, size, "cracks", false)
		world().add_child(mark)
		mark.global_position = spot + Vector3.UP * 0.05
		_holes.append({"spot": spot, "mark": mark, "water": null})
	_warn_left = float(config.get("warn", 1.3))
	_safe = Vector3.INF

func tick(delta: float) -> void:
	super.tick(delta)
	var hero := player()
	if _warn_left > 0.0:
		_warn_left -= delta
		var warn := float(config.get("warn", 1.3))
		for hole: Dictionary in _holes:
			if is_instance_valid(hole.mark):
				CombatVfx.set_param(hole.mark, &"progress", clampf(1.0 - _warn_left / warn, 0.0, 1.0))
		if hero != null and is_instance_valid(hero) and _in_hole(hero.global_position) < 0:
			_safe = hero.global_position
		if _warn_left <= 0.0:
			_open()
		return
	if _open_left <= 0.0:
		return
	_open_left -= delta
	if hero != null and is_instance_valid(hero):
		if _in_hole(hero.global_position) < 0:
			_safe = hero.global_position
		elif not (hero.has_method("is_swallowed") and hero.is_swallowed()):
			_fall(hero)
	if _open_left <= 0.0:
		_clear()

func _open() -> void:
	var size := float(config.get("size", 2.2))
	for hole: Dictionary in _holes:
		if is_instance_valid(hole.mark):
			hole.mark.queue_free()
		var water := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(size, 0.04, size)
		water.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = WATER
		mat.metallic = 0.6
		mat.roughness = 0.05
		water.material_override = mat
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world().add_child(water)
		water.global_position = hole.spot + Vector3.UP * 0.04
		hole.water = water
		CombatVfx.smoke_puff(world(), hole.spot + Vector3.UP * 0.3, Color(0.85, 0.95, 1.0), 1.2)
	_open_left = float(config.get("time", 6.0))

func _in_hole(point: Vector3) -> int:
	var half := float(config.get("size", 2.2)) * 0.5 - 0.15
	for i in _holes.size():
		var spot: Vector3 = _holes[i].spot
		if absf(point.x - spot.x) <= half and absf(point.z - spot.z) <= half:
			return i
	return -1

func _fall(hero: Node3D) -> void:
	CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.3, COLOR, true)
	hero.take_damage(damage())
	var back := _safe
	if back == Vector3.INF:
		back = enemy.global_position + enemy.model_forward() * 2.0
	hero.global_position = Vector3(back.x, hero.global_position.y, back.z)
	if hero.has_method("stun"):
		hero.stun(float(config.get("stun", 0.7)))

func on_death() -> void:
	_clear()

func _clear() -> void:
	_warn_left = 0.0
	_open_left = 0.0
	for hole: Dictionary in _holes:
		if is_instance_valid(hole.mark):
			hole.mark.queue_free()
		if hole.water != null and is_instance_valid(hole.water):
			hole.water.queue_free()
	_holes.clear()
