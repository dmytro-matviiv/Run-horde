extends Node2D

## Вогнемет: живий конус полум'я перед героєм. На відміну від замаху
## він не б'є разово, а тікає шкодою кілька разів за час дії й увесь
## цей час повертається за напрямком стрільби — тож ворог, який
## пробіг крізь струмінь, отримає своє, навіть якщо з'явився пізніше.

const TICK_INTERVAL := 0.15

var _def: WeaponDef
var _damage := 0.0
var _aim := Vector2.RIGHT
var _duration_left := 0.0
var _tick_left := 0.0

func ignite(aim: Vector2, def: WeaponDef, damage: float) -> void:
	_def = def
	_damage = damage
	_aim = aim
	_duration_left = def.cone_duration
	_tick_left = 0.0
	queue_redraw()

## Напрямок оновлює WeaponModule, поки струмінь живий — полум'я
## "веде" за найближчим ворогом.
func set_aim(aim: Vector2) -> void:
	_aim = aim

func _process(delta: float) -> void:
	if _def == null:
		return
	if get_parent() is Node2D:
		global_position = (get_parent() as Node2D).global_position
	_duration_left -= delta
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = TICK_INTERVAL
		var enemies := CombatQuery.enemies_in_cone(get_world_2d(), global_position, _def.cone_range, _aim, _def.cone_angle_deg)
		CombatQuery.hit_all(enemies, _damage, _def.status, _def.status_power, _def.status_duration)
	queue_redraw()
	if _duration_left <= 0.0:
		queue_free()

func _draw() -> void:
	if _def == null:
		return
	var half_angle := deg_to_rad(_def.cone_angle_deg) * 0.5
	var start_angle := _aim.angle() - half_angle
	var color := _def.color
	color.a = 0.45 * clampf(_duration_left / maxf(_def.cone_duration, 0.01), 0.0, 1.0)
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 18
	for i in steps + 1:
		var angle := start_angle + half_angle * 2.0 * (float(i) / steps)
		points.append(Vector2(cos(angle), sin(angle)) * _def.cone_range)
	draw_colored_polygon(points, color)
