extends HeroSkill3D

## ПРОБИВНИЙ ПОСТРІЛ (Лучник): важка стріла прошиває всіх ворогів на
## лінії й відкидає їх.

const DAMAGE := 3.2
const SPEED := 55.0

func _init() -> void:
	id = &"piercing_shot"
	title = "Пробивний постріл"
	description = "Важка стріла прошиває всіх ворогів на своєму шляху й відкидає їх."
	color = Color(1.0, 0.55, 0.25)
	icon_kind = "gun"
	cooldown = 6.0

func _use(player: Node) -> bool:
	var direction: Vector3 = player.facing_vector()
	var target: Node = player.get("_target")
	if is_instance_valid(target) and target is Enemy3D:
		var aim: Vector3 = (target as Enemy3D).global_position - player.global_position
		aim.y = 0.0
		if aim.length() > 0.05:
			direction = aim.normalized()
			player.face_direction(direction)
	# Злітає з лука й опускається до грудей ворога — прошиває всю лінію.
	var origin: Vector3 = player.spell_origin()
	var reach := 6.0
	if is_instance_valid(target) and target is Enemy3D:
		reach = maxf((target as Enemy3D).global_position.distance_to(player.global_position), 1.5)
	var drop: float = (player.global_position.y + 0.85) - origin.y
	direction = (direction * reach + Vector3.UP * drop).normalized()
	var arrow := PlayerProjectile.create(player, DAMAGE, color, 5.0)
	arrow.pierce = 99
	var parent: Node = player.get_parent()
	parent.add_child(arrow)
	arrow.scale = Vector3.ONE * 2.2
	arrow.launch(origin, direction, SPEED)
	CombatVfx.muzzle_flash(parent, origin, direction, color)
	player.play_clip("Pistol_Shoot")
	player.shake_camera(0.08)
	return true
