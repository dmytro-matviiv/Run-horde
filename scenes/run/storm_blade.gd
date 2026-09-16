extends Node2D

## Клинок "Вихору Смерті" — суто візуальний: крутиться навколо героя.
## Шкоду завдає сам WeaponModule по всьому колу вихору (гілка
## orbit_storm), бо інакше вороги, які тиснуться впритул до героя,
## пролазили б під клинками й не отримували нічого.

var _origin: Node2D
var _orbit_radius := 70.0
var _angle := 0.0
var _angular_speed := 3.0
var _color := Color(0.85, 0.55, 0.15)

func setup(origin: Node2D, angle_offset: float, def: WeaponDef) -> void:
	_origin = origin
	_orbit_radius = def.orbit_radius
	_angular_speed = def.orbit_speed
	_angle = angle_offset
	_color = def.color
	_update_position()

func _process(delta: float) -> void:
	if _origin == null:
		return
	_angle += _angular_speed * delta
	_update_position()

func _update_position() -> void:
	global_position = _origin.global_position + Vector2(cos(_angle), sin(_angle)) * _orbit_radius

func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, _color)
