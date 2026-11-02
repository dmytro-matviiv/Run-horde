extends EnemyAbility

## СТРИБОК: ворог присідає — і стрибає туди, де стоїть герой. Там одразу
## червоне коло, що заповнюється до приземлення: відійди або перекотись.

const CROUCH := 0.3
const FLIGHT := 0.65
const RADIUS := 2.0
const MIN_DISTANCE := 4.0
const MAX_DISTANCE := 11.0
const HEIGHT := 3.0
const COLOR := Color(1.0, 0.3, 0.2, 0.9)

var _busy := false
var _from := Vector3.ZERO
var _target := Vector3.ZERO
var _marker: MeshInstance3D

func _init() -> void:
	id = "leap"
	cooldown = 6.0

func is_busy() -> bool:
	return _busy

func try_use(distance: float) -> bool:
	if distance < MIN_DISTANCE or distance > MAX_DISTANCE or not enemy.sees_player():
		return false
	start_cooldown()
	_busy = true
	_from = enemy.global_position
	_target = player().global_position
	_target.y = _from.y
	var radius := RADIUS * float(config.get("radius_mult", 1.0))
	_marker = CombatVfx.make_telegraph(COLOR, radius, PI, true)
	world().add_child(_marker)
	_marker.global_position = Vector3(_target.x, DungeonBuilder.FLOOR_TOP + 0.05, _target.z)
	enemy.face_player(100.0)
	enemy.play_once(["Jump", "Jump_Idle", "Headbutt", "Punch"])
	var tween := enemy.create_tween()
	tween.tween_interval(CROUCH)
	tween.tween_method(_fly, 0.0, 1.0, FLIGHT)
	tween.tween_callback(_land.bind(radius))
	return true

func _fly(t: float) -> void:
	var position := _from.lerp(_target, t)
	position.y += HEIGHT * 4.0 * t * (1.0 - t)
	enemy.global_position = position
	if is_instance_valid(_marker):
		CombatVfx.set_param(_marker, &"progress", t)

func _land(radius: float) -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
	enemy.global_position = _target
	CombatVfx.shockwave(world(), _target, radius, COLOR, 0.35)
	CombatVfx.impact_decal(world(), _target, radius * 0.8, COLOR)
	CombatVfx.impact(world(), _target + Vector3.UP * 0.4, COLOR, true)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.14)
	var offset := player().global_position - _target
	offset.y = 0.0
	if offset.length() <= radius:
		if player().take_damage(damage() * 1.4) and player().has_method("stun"):
			player().stun(float(config.get("stun", 0.5)))
	_busy = false
	enemy.hold_still(0.5)

func on_death() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
