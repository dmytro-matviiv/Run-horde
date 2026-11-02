extends Node3D

## ЛИПКА КАЛЮЖА склепного слизу: зелена пляма на підлозі. Герой, що
## ступив у неї, на SLOW_TIME секунд сповільнюється (SLOW_FACTOR від
## швидкості). Калюжа живе LIFETIME секунд і тоді висихає. Своя фізика —
## лишається й після смерті слизу.

const COLOR := Color(0.55, 0.85, 0.25, 0.55)
const LIFETIME := 4.0
const FADE_TIME := 0.6
const CHECK_INTERVAL := 0.25

var radius := 0.8
var slow_factor := 0.7
var slow_time := 3.0
var _player: Node3D
var _left := LIFETIME
var _check_left := 0.0
var _marker: MeshInstance3D

static func spawn(world: Node, position: Vector3, player: Node3D, puddle_radius: float,
		factor: float, seconds: float) -> Node3D:
	var puddle: Node3D = load("res://scenes/dungeon/hazards/slime_puddle.gd").new()
	puddle._player = player
	puddle.radius = puddle_radius
	puddle.slow_factor = factor
	puddle.slow_time = seconds
	world.add_child(puddle)
	puddle.global_position = Vector3(position.x, DungeonBuilder.FLOOR_TOP + 0.03, position.z)
	return puddle

func _ready() -> void:
	_marker = CombatVfx.make_ground_marker(COLOR, radius)
	CombatVfx.set_param(_marker, &"progress", 1.0)
	add_child(_marker)
	# Розпливається з краплі.
	_marker.scale = Vector3(radius * 0.6, 1.0, radius * 0.6)
	var tween := _marker.create_tween()
	tween.tween_property(_marker, "scale", Vector3(radius * 2.0, 1.0, radius * 2.0), 0.25).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	if _left < FADE_TIME:
		CombatVfx.set_param(_marker, &"fade", _left / FADE_TIME)
		return
	_check_left -= delta
	if _check_left > 0.0 or _player == null or not is_instance_valid(_player):
		return
	_check_left = CHECK_INTERVAL
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() > radius:
		return
	# Липне раз — і тримає slow_time секунд; доки стоїть у калюжі,
	# сповільнення поновлюється, щойно скінчилось.
	if _player.has_method("apply_slow") and not _player.is_slowed():
		_player.apply_slow(slow_factor, slow_time)
