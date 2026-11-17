extends HeroSkill3D

## УДАР ЛАПОЮ (Ведмідь): могутній розмах — шкода й оглушення всім у
## конусі попереду.

const RADIUS := 3.4
const HALF_ANGLE := 65.0
const DAMAGE := 2.2
const STUN := 1.6

func _init() -> void:
	id = &"paw_swipe"
	title = "Удар лапою"
	description = "Розмах лапою: шкода й оглушення всім ворогам у конусі попереду."
	color = Color(0.85, 0.55, 0.3)
	icon_kind = "nova"
	cooldown = 6.0

func _use(player: Node) -> bool:
	var target: Node = player.get("_target")
	if is_instance_valid(target) and target is Enemy3D:
		var to: Vector3 = (target as Enemy3D).global_position - player.global_position
		to.y = 0.0
		if to.length() > 0.05:
			player.face_direction(to.normalized())
	var forward: Vector3 = player.facing_vector()
	var hit := 0
	for enemy: Enemy3D in player.enemies_in_radius(RADIUS, false):
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		if offset.length() > 0.3 and rad_to_deg(forward.angle_to(offset.normalized())) > HALF_ANGLE:
			continue
		player.deal_damage(enemy, DAMAGE, offset.normalized() * 4.0, true, id)
		enemy.stun(STUN, true)
		hit += 1
	var parent: Node = player.get_parent()
	CombatVfx.slash(parent, player.global_position + Vector3.UP * 0.9, player.facing_angle(), RADIUS, HALF_ANGLE * 2.0,
		color, false, -0.4, 0.35)
	Fx.puff(parent, player.global_position + forward * 1.6 + Vector3.UP * 0.2, Color(0.7, 0.6, 0.5), 1.2)
	player.play_form_strike(true)
	player.shake_camera(0.14 if hit > 0 else 0.06)
	return true
