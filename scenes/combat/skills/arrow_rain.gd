extends HeroSkill3D

## ГРАД СТРІЛ (Лучник): злива стріл падає з неба довкола цілі —
## кілька хвиль, кожна стріла ранить того, в кого влучить.

const RADIUS := 3.6
const WAVES := 6
const PER_WAVE := 6
const GAP := 0.22
const DAMAGE := 0.55

var _center := Vector3.ZERO
var _waves_left := 0
var _next := 0.0

func _init() -> void:
	id = &"arrow_rain"
	title = "Град стріл"
	description = "Злива стріл падає з неба на ворогів довкола цілі."
	color = Color(1.0, 0.85, 0.45)
	icon_kind = "gun"
	cooldown = 12.0

func _use(player: Node) -> bool:
	_center = player.global_position + player.facing_vector() * 6.0
	var target: Node = player.get("_target")
	if is_instance_valid(target) and target is Enemy3D:
		_center = (target as Enemy3D).global_position
	_waves_left = WAVES
	_next = 0.15
	player.play_clip("OverhandThrow", 1.3)
	CombatVfx.shockwave(player.get_parent(), _center, RADIUS, color, 0.5)
	return true

func _update(player: Node, delta: float) -> void:
	if _waves_left <= 0:
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = GAP
	_waves_left -= 1
	var parent: Node = player.get_parent()
	for i in PER_WAVE:
		var spot := _center + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(1.0) * RADIUS
		var arrow := PlayerProjectile.create(player, DAMAGE, color, 0.5)
		parent.add_child(arrow)
		arrow.launch(spot + Vector3(0.6, 9.0, 0.4), Vector3(-0.06, -1.0, -0.04), 34.0)
