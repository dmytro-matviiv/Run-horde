extends EnemyAbility

## ПІД ЗЕМЛЮ: ворог пірнає в підлогу (його не видно й не вдарити), по
## підлозі до героя біжить доріжка пилу — і просто під героєм спалахує
## коло: за мить ворог вистрибне звідти й ударить. Не стій на місці.

const DIG_TIME := 1.5
const WARN_TIME := 0.8
const RADIUS := 1.9
const MIN_DISTANCE := 4.0
const MAX_DISTANCE := 16.0
const DUST := Color(0.62, 0.48, 0.32)

var _busy := false
var _marker: MeshInstance3D
var _target := Vector3.ZERO

func _init() -> void:
	id = "burrow"
	cooldown = 7.0

func is_busy() -> bool:
	return _busy

func try_use(distance: float) -> bool:
	if distance < MIN_DISTANCE or distance > MAX_DISTANCE:
		return false
	start_cooldown()
	_busy = true
	CombatVfx.impact(world(), enemy.global_position + Vector3.UP * 0.3, DUST, true)
	enemy.set_hidden(true)
	# Доріжка пилу від місця, де пірнув, до героя.
	var from := enemy.global_position
	var tween := enemy.create_tween()
	for step in 5:
		tween.tween_interval(DIG_TIME / 6.0)
		tween.tween_callback(func() -> void:
			var t := float(step + 1) / 6.0
			var spot := from.lerp(player().global_position, t)
			CombatVfx.impact(world(), spot + Vector3.UP * 0.1, DUST, false))
	tween.tween_interval(DIG_TIME / 6.0)
	tween.tween_callback(_warn)
	return true

func _warn() -> void:
	_target = player().global_position
	_marker = CombatVfx.make_telegraph(Color(DUST, 0.9), RADIUS, PI, true)
	world().add_child(_marker)
	_marker.global_position = Vector3(_target.x, DungeonBuilder.FLOOR_TOP + 0.05, _target.z)
	enemy.teleport_to(_target)
	var tween := enemy.create_tween()
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(_marker):
			_marker.set_instance_shader_parameter(&"progress", value), 0.0, 1.0, WARN_TIME)
	tween.tween_callback(_burst)

func _burst() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
	enemy.set_hidden(false)
	enemy.emerge(0.25)
	CombatVfx.shockwave(world(), _target, RADIUS, DUST, 0.35)
	CombatVfx.impact_decal(world(), _target, RADIUS * 0.8, DUST)
	CombatVfx.impact(world(), _target + Vector3.UP * 0.5, DUST, true)
	var offset := player().global_position - _target
	offset.y = 0.0
	if offset.length() <= RADIUS:
		player().take_damage(damage() * 1.3)
	_busy = false

func on_death() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
