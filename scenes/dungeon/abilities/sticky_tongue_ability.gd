extends EnemyAbility

## ЛИПКИЙ ЯЗИК (Жаба-язикатка, Потонулі Сади). Здалеку жаба прицілюється
## (рожева смуга на підлозі) і вистрілює язиком по прямій. Влучила —
## язик прилипає до зброї: time секунд удари героя слабші (factor).
## Від язика відходять убік, поки смуга ще блідне.
## Налаштування: min, max (відстань), windup, factor, time, damage.

const COLOR := Color(1.0, 0.45, 0.6, 0.85)
const WIDTH := 0.9

var _line: MeshInstance3D
var _direction := Vector3.FORWARD
var _windup := 0.5
var _aim_left := 0.0

func _init() -> void:
	id = "sticky_tongue"
	cooldown = 7.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 2.0)) or distance > float(config.get("max", 6.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	var hero := player()
	_direction = hero.global_position - enemy.global_position
	_direction.y = 0.0
	_direction = _direction.normalized()
	var length := float(config.get("max", 6.0)) + 0.5
	_line = CombatVfx.make_line_telegraph(COLOR, length, WIDTH, "chevrons", false)
	world().add_child(_line)
	_line.global_position = Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP + 0.05, enemy.global_position.z) + _direction * length * 0.5
	_line.rotation.y = atan2(_direction.x, _direction.z)
	_windup = float(config.get("windup", 0.5))
	_aim_left = _windup
	enemy.face_point(hero.global_position)
	enemy.begin_special(id, _windup, Color(COLOR, 0.0), 0.1)
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	if _line != null:
		_aim_left -= delta
		if is_instance_valid(_line):
			CombatVfx.set_param(_line, &"progress", clampf(1.0 - _aim_left / _windup, 0.0, 1.0))
		# Жабу збили з замаху (оглушили) — смуга не висить вічно.
		if _aim_left < -0.8:
			_clear_line()

func resolve() -> void:
	_clear_line()
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var length := float(config.get("max", 6.0)) + 0.5
	var offset := hero.global_position - enemy.global_position
	offset.y = 0.0
	var along := offset.dot(_direction)
	var side := (offset - _direction * along).length()
	var reach := length
	if along > 0.0 and along <= length and side <= WIDTH * 0.5 + 0.35:
		reach = along
		if hero.take_damage(damage()):
			if hero.has_method("weaken"):
				hero.weaken(float(config.get("factor", 0.65)), float(config.get("time", 4.0)))
			CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, false)
	_lash(reach)

## Сам язик: рожевий брусок вилітає з пащі й одразу втягується.
func _lash(reach: float) -> void:
	var tongue := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.12, 1.0)
	tongue.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.4, 0.55)
	mat.roughness = 0.3
	tongue.material_override = mat
	tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world().add_child(tongue)
	var mouth := enemy.global_position + Vector3.UP * enemy.target_height * 0.45 + _direction * 0.4
	var tip := mouth + _direction * reach
	tongue.look_at_from_position(mouth, tip, Vector3.UP)
	var grow := func(t: float) -> void:
		if not is_instance_valid(tongue):
			return
		var length := maxf(reach * t, 0.05)
		tongue.global_position = mouth + _direction * length * 0.5
		tongue.scale = Vector3(1.0, 1.0, length)
	var tween := tongue.create_tween()
	tween.tween_method(grow, 0.05, 1.0, 0.09)
	tween.tween_method(grow, 1.0, 0.05, 0.22)
	tween.tween_callback(tongue.queue_free)

func on_death() -> void:
	_clear_line()

func _clear_line() -> void:
	_aim_left = 0.0
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	_line = null
