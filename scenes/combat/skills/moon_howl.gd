extends HeroSkill3D

## МІСЯЧНЕ ВИТТЯ (Фенрір): вороги довкола в жаху завмирають і
## кровоточать кілька секунд.

const RADIUS := 6.0
const STUN := 2.2
const BLEED := 0.9

func _init() -> void:
	id = &"moon_howl"
	title = "Місячне виття"
	description = "Виття під місяцем: вороги довкола в жаху завмирають і кровоточать."
	color = Color(0.7, 0.85, 1.0)
	icon_kind = "nova"
	cooldown = 15.0

func _use(player: Node) -> bool:
	var bleeds: Array = player.get("_bleeds")
	for enemy: Enemy3D in player.enemies_in_radius(RADIUS, false):
		enemy.stun(STUN, true)
		player.deal_damage(enemy, 0.4, Vector3.ZERO, false, id)
		bleeds.append([enemy, float(player.get("_damage")) * BLEED / 6.0, 6, 0.5])
	var parent: Node = player.get_parent()
	CombatVfx.shockwave(parent, player.global_position, RADIUS, color, 0.6)
	CombatVfx.sky_beam(parent, player.global_position, color)
	player.play_form_strike(true)
	player.shake_camera(0.12)
	return true
