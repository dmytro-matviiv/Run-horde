extends HeroSkill3D

## УДАР ЩИТОМ (Танк): поштовх щитом — шкода, відкидання й оглушення
## всім попереду.

const RADIUS := 3.0
const HALF_ANGLE := 55.0
const DAMAGE := 1.8
const STUN := 1.5

func _init() -> void:
	id = &"shield_bash"
	title = "Удар щитом"
	description = "Поштовх щитом: шкода, відкидання й оглушення всім ворогам попереду."
	color = Color(0.75, 0.8, 0.9)
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
		player.deal_damage(enemy, DAMAGE, offset.normalized() * 6.0, true, id)
		enemy.stun(STUN, true)
		hit += 1
	var parent: Node = player.get_parent()
	CombatVfx.shockwave(parent, player.global_position + forward * 1.4, 1.6, color, 0.3)
	Fx.puff(parent, player.global_position + forward * 1.4 + Vector3.UP * 0.2, Color(0.7, 0.65, 0.6), 1.0)
	player.play_clip("Shield_OneShot")
	player.shake_camera(0.14 if hit > 0 else 0.06)
	return true
