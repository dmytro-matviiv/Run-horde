extends Node3D
class_name SpikeTrap

## ШИПИ З ПІДЛОГИ. Плита в коридорі. Спершу під нею червоніє коло — як
## зона замаху ворога, — тоді з підлоги б'ють шипи й ранять усіх, хто на
## плиті: і героя, і ворогів (бочку на плиті підпалюють). Потім шипи
## ховаються. Плити поперек одного коридору б'ють разом, а в різних
## коридорів свій ритм — прохід треба вгадати або заманити туди ворогів.

const PLATE_SCENE := preload("res://assets/models/dungeon/Trap_empty.fbx")
const SPIKES_SCENE := preload("res://assets/models/dungeon/Spikes.fbx")

const WARN_TIME := 0.85
const UP_TIME := 0.7
const REST_MIN := 1.5
const REST_MAX := 2.6
## Хто стоїть у цьому квадраті від центру плити, того й ранить.
const HALF_SIZE := 0.95
## Шипи ховаються під підлогою й виринають на висоту по коліно.
const HIDDEN_Y := -1.25
const RAISED_Y := -0.35
const WARN_COLOR := Color(1.0, 0.22, 0.15, 0.85)
## Далі за це від героя пастка "спить" і нічого не рахує.
const ACTIVE_DISTANCE := 26.0

enum State {REST, WARN, UP}

var hero_damage := 10.0
var enemy_damage := 22.0

var _player: Node3D
var _state := State.REST
var _left := 1.0
var _rng := RandomNumberGenerator.new()
var _spikes: Node3D
var _marker: MeshInstance3D
var _hit: Array[Node] = []

## phase — скільки секунд до першого удару: плити одного коридору
## отримують однакову фазу й б'ють разом.
func setup(player: Node3D, phase: float, seed: int) -> void:
	_player = player
	_left = phase
	_rng.seed = seed

func _ready() -> void:
	var plate: Node3D = PLATE_SCENE.instantiate()
	# Трохи над плиткою підлоги, інакше дві поверхні мерехтіли б одна крізь одну.
	plate.position.y = 0.012
	add_child(plate)
	_spikes = SPIKES_SCENE.instantiate()
	_spikes.position.y = HIDDEN_Y
	_spikes.visible = false
	add_child(_spikes)
	for node in find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).visibility_range_end = 40.0

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if _state == State.REST and global_position.distance_to(_player.global_position) > ACTIVE_DISTANCE:
		return
	_left -= delta
	match _state:
		State.REST:
			if _left <= 0.0:
				_warn()
		State.WARN:
			if _marker != null:
				CombatVfx.set_param(_marker, &"progress", 1.0 - maxf(_left, 0.0) / WARN_TIME)
			if _left <= 0.0:
				_raise()
		State.UP:
			_hurt_standing()
			if _left <= 0.0:
				_lower()

func _warn() -> void:
	_state = State.WARN
	_left = WARN_TIME
	_marker = CombatVfx.make_ground_marker(WARN_COLOR, HALF_SIZE + 0.1)
	add_child(_marker)
	_marker.position.y = 0.16

func _raise() -> void:
	_state = State.UP
	_left = UP_TIME
	_hit.clear()
	if _marker != null:
		_marker.queue_free()
		_marker = null
	_spikes.visible = true
	var tween := create_tween()
	tween.tween_property(_spikes, "position:y", RAISED_Y, 0.07)

func _lower() -> void:
	_state = State.REST
	_left = _rng.randf_range(REST_MIN, REST_MAX)
	var tween := create_tween()
	tween.tween_property(_spikes, "position:y", HIDDEN_Y, 0.3)
	tween.tween_callback(func() -> void: _spikes.visible = false)

## Кожного, хто на плиті, шипи ранять раз за удар.
func _hurt_standing() -> void:
	if _covers(_player.global_position) and not _hit.has(_player):
		_hit.append(_player)
		_player.take_damage(hero_damage)
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy3D
		if enemy == null or not enemy.is_alive() or _hit.has(enemy):
			continue
		if _covers(enemy.global_position):
			_hit.append(enemy)
			enemy.take_damage(enemy_damage, Vector3.ZERO, false, false)

func _covers(position: Vector3) -> bool:
	var offset := position - global_position
	return absf(offset.x) <= HALF_SIZE and absf(offset.z) <= HALF_SIZE
