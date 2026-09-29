extends Node3D
class_name HealthOrb

## СФЕРА ЗДОРОВ'Я. Червона куля, що інколи випадає з ворога (з еліти —
## часто) й висить над підлогою. Підійшов ближче — підлітає й лікує.
## Коли здоров'я повне, куля не підлітає й чекає: її можна лишити на
## потім — у цьому й вибір, коли битися, а коли відступити до сфери.

const HEAL_SHARE := 0.12
## З якої відстані куля тягнеться до пораненого героя й звідки її вже взято.
const PULL_DISTANCE := 2.6
const PICK_DISTANCE := 0.6
const LIFETIME := 30.0
const HOVER := 0.6
const COLOR := Color(1.0, 0.25, 0.3)

var _player: Node3D
var _left := LIFETIME
var _pulling := false
var _speed := 3.0
var _orb: MeshInstance3D

func setup(player: Node3D) -> void:
	_player = player

func _ready() -> void:
	_orb = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	sphere.radial_segments = 10
	sphere.rings = 6
	_orb.mesh = sphere
	_orb.material_override = CombatVfx.get_glow_material(COLOR)
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_orb)
	# Вискакує з ворога й зависає над підлогою, ледь погойдуючись.
	_orb.position.y = 1.4
	var drop := _orb.create_tween()
	drop.tween_property(_orb, "position:y", HOVER, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.tween_callback(_start_bobbing)

func _start_bobbing() -> void:
	var bob := _orb.create_tween().set_loops()
	bob.tween_property(_orb, "position:y", HOVER + 0.15, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_orb, "position:y", HOVER, 0.7).set_trans(Tween.TRANS_SINE)

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	var target := _player.global_position + Vector3(0, 0.9, 0)
	var offset := target - _orb.global_position
	if not _pulling:
		# Повне здоров'я — куля лишається на потім.
		if offset.length() <= PULL_DISTANCE and _player.current_hp < _player.max_hp:
			_pulling = true
		return
	_speed = minf(_speed + 25.0 * delta, 16.0)
	if offset.length() <= maxf(PICK_DISTANCE, _speed * delta):
		_pick()
		return
	global_position += offset.normalized() * _speed * delta

func _pick() -> void:
	_player.heal(_player.max_hp * HEAL_SHARE)
	CombatVfx.impact(get_parent(), _player.global_position + Vector3.UP * 0.9, COLOR, false)
	AudioManager.play(&"pickup")
	queue_free()
