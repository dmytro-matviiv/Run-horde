extends "res://scenes/combat/skills/rage_dash.gd"

## РОЗБІГ (Ведмідь): ведмідь кидається на найближчого ворога, збиваючи
## всіх на шляху, і б'є з розгону. Як ривок мечника, але за таймером, а
## не за люттю.

func _init() -> void:
	super()
	id = &"bear_charge"
	title = "Розбіг"
	description = "Ведмідь кидається на найближчого ворога, збиває всіх на шляху і б'є з розгону."
	color = Color(0.85, 0.6, 0.35)
	icon_kind = "dash"
	cooldown = 7.0

func get_charge(_player: Node) -> float:
	return -1.0

func _use(player: Node) -> bool:
	_target = _pick_target(player)
	var direction: Vector3 = player.facing_vector()
	var distance := NO_TARGET_DISTANCE
	if _target != null:
		var offset: Vector3 = _target.global_position - player.global_position
		offset.y = 0.0
		direction = offset.normalized() if offset.length() > 0.05 else direction
		distance = maxf(offset.length() - STOP_GAP - _target.body_radius(), 0.0)
	distance = _clear_distance(player, direction, distance)
	var time := maxf(distance / SPEED, 0.08)
	_dash_left = time
	_hit_ids.clear()
	if _target != null:
		_hit_ids.append(_target.get_instance_id())
	player.face_direction(direction)
	player.dash(direction, distance / time, time)
	player.play_form_strike(true)
	player.grant_invulnerable(time + 0.2)
	Fx.puff(player.get_parent(), player.global_position + Vector3.UP * 0.25, Color(0.75, 0.65, 0.55), 1.3)
	player.shake_camera(0.1)
	return true
