extends Node2D

## Замах ближнього бою (сокира, коса): б'є всіх у секторі перед героєм
## один раз у момент удару, далі лише домальовує сектор, що згасає.
## Живе частку секунди й видаляється — пул тут зайвий, бо ударів
## мало (один на кулдаун), на відміну від снарядів.

const SWING_TIME := 0.22

var _radius := 110.0
var _half_angle := 1.0
var _aim := Vector2.RIGHT
var _color := Color(1, 0.8, 0.3)
var _elapsed := 0.0

## damage вже з бонусами героя; aim — напрямок удару.
func strike(at_position: Vector2, aim: Vector2, def: WeaponDef, damage: float) -> int:
	global_position = at_position
	_aim = aim
	_radius = def.melee_range
	_half_angle = deg_to_rad(def.melee_arc_deg) * 0.5
	_color = def.color
	var enemies := CombatQuery.enemies_in_cone(get_world_2d(), at_position, def.melee_range, aim, def.melee_arc_deg)
	return CombatQuery.hit_all(enemies, damage, def.status, def.status_power, def.status_duration)

func _process(delta: float) -> void:
	_elapsed += delta
	# Замах іде разом з героєм, інакше сектор лишався б позаду.
	if get_parent() is Node2D:
		global_position = (get_parent() as Node2D).global_position
	queue_redraw()
	if _elapsed >= SWING_TIME:
		queue_free()

func _draw() -> void:
	var progress := clampf(_elapsed / SWING_TIME, 0.0, 1.0)
	var color := _color
	color.a = 0.6 * (1.0 - progress)
	var start_angle := _aim.angle() - _half_angle
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 16
	for i in steps + 1:
		var angle := start_angle + (_half_angle * 2.0) * (float(i) / steps)
		points.append(Vector2(cos(angle), sin(angle)) * _radius)
	draw_colored_polygon(points, color)
