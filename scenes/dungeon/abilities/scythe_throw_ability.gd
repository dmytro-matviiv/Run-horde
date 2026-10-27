extends EnemyAbility

## КИДОК КОСИ (Кістяний Володар): замах — і коса летить бумерангом по
## прямій до героя й далі (смуга на підлозі), а тоді вертається до боса.
## Ранить і туди, і назад: ухилятись доводиться двічі. Поки коса летить,
## бос стоїть із порожньою рукою.
##
## Налаштування: min, range (м), windup, out (с польоту туди), width,
## hit_radius, damage, prop (модель коси).

const COLOR := Color(1.0, 0.35, 0.25, 0.85)
const HAND_HEIGHT := 1.3

var _line: MeshInstance3D
var _scythe: Node3D
var _dir := Vector3.FORWARD
var _from := Vector3.ZERO
var _length := 10.0
## Час польоту; < 0 — коса в руці.
var _time := -1.0
var _hit_out := false
var _hit_back := false

func _init() -> void:
	id = "scythe_throw"
	cooldown = 9.0

func is_busy() -> bool:
	return _time >= 0.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 4.5)) or distance > float(config.get("range", 12.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	_from = enemy.global_position
	var aim := player().global_position - _from
	aim.y = 0.0
	_dir = aim.normalized()
	_length = clampf(distance + 3.0, 6.0, float(config.get("range", 12.0)) + 3.0)
	# Об стіну коса не пролетить — смуга коротша.
	var query := PhysicsRayQueryParameters3D.create(_from + Vector3.UP, _from + Vector3.UP + _dir * _length, 1)
	var hit := enemy.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_length = maxf((hit.position as Vector3).distance_to(_from + Vector3.UP) - 0.6, 3.0)
	enemy.face_point(_from + _dir)
	var windup := float(config.get("windup", 0.6))
	_clear_line()
	_line = CombatVfx.make_line_telegraph(COLOR, _length, float(config.get("width", 1.6)), "chevrons", true)
	world().add_child(_line)
	_line.global_position = Vector3(_from.x, DungeonBuilder.FLOOR_TOP + 0.05, _from.z) + _dir * _length * 0.5
	_line.rotation.y = atan2(_dir.x, _dir.z)
	var line := _line
	line.create_tween().tween_method(func(value: float) -> void:
		if is_instance_valid(line):
			line.set_instance_shader_parameter(&"progress", value), 0.0, 1.0, windup)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_time = 0.0
	_hit_out = false
	_hit_back = false
	_scythe = Node3D.new()
	var model: Node3D = load(String(config.get("prop", "res://assets/models/props/bone_scythe.glb"))).instantiate()
	_scythe.add_child(model)
	# Коса летить пласко, крутиться довкола себе; розмір — як у руці боса.
	model.rotation.x = PI * 0.5
	var body: Node3D = enemy.get("_model")
	model.scale = body.scale if body != null else Vector3.ONE * 2.5
	world().add_child(_scythe)
	_scythe.global_position = _from + Vector3.UP * HAND_HEIGHT

func tick(delta: float) -> void:
	super.tick(delta)
	# Замах збили — смуга зникає.
	if _time < 0.0:
		if _line != null and String(enemy.get("_special")) != id:
			_clear_line()
		return
	_time += delta
	var out := float(config.get("out", 0.8))
	var t := _time / out
	var far := _from + _dir * _length
	var spot: Vector3
	if t <= 1.0:
		spot = _from.lerp(far, sin(t * PI * 0.5))
	else:
		var back := minf(t - 1.0, 1.0)
		spot = far.lerp(enemy.global_position, back * back)
	if _scythe != null and is_instance_valid(_scythe):
		_scythe.global_position = spot + Vector3.UP * HAND_HEIGHT
		_scythe.rotate_y(delta * 15.0)
	enemy.face_point(spot)
	var hero := player()
	if hero != null and is_instance_valid(hero):
		var offset := hero.global_position - spot
		offset.y = 0.0
		if offset.length() <= float(config.get("hit_radius", 1.2)):
			if t <= 1.0 and not _hit_out:
				_hit_out = hero.take_damage(damage())
			elif t > 1.0 and not _hit_back:
				_hit_back = hero.take_damage(damage())
	if t >= 2.0:
		_catch()

## Коса повернулась у руку.
func _catch() -> void:
	_time = -1.0
	if _scythe != null and is_instance_valid(_scythe):
		_scythe.queue_free()
	_scythe = null
	_clear_line()
	CombatVfx.impact(world(), enemy.global_position + Vector3.UP * HAND_HEIGHT, Color(0.8, 1.0, 0.75), false)

func on_death() -> void:
	_catch()

func _clear_line() -> void:
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	_line = null
