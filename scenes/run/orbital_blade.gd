extends Area2D

## Один орбітальний клинок: обертається навколо героя (origin) на
## фіксованому радіусі й куті-зсуві, б'є ворога, коли влітає в нього.
## На відміну від снарядів — живе постійно, поки в героя є цей
## апгрейд, тож пулу не потребує: створюється й видаляється разом
## зі зміною рівня апгрейду (Hero._apply_orbital_blades).

var _origin: Node2D
var _orbit_radius := 50.0
var _angle := 0.0
var _angular_speed := 2.5
var _damage := 8.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(origin: Node2D, orbit_radius: float, angle_offset: float, angular_speed: float, damage: float) -> void:
	_origin = origin
	_orbit_radius = orbit_radius
	_angle = angle_offset
	_angular_speed = angular_speed
	_damage = damage
	_update_position()

func _physics_process(delta: float) -> void:
	if _origin == null:
		return
	_angle += _angular_speed * delta
	_update_position()

func _update_position() -> void:
	global_position = _origin.global_position + Vector2(cos(_angle), sin(_angle)) * _orbit_radius

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(_damage)
