extends HeroSkill3D

## КРИЖАНА НОВА — особлива здібність Крижаного посоха.
## Хвиля холоду розходиться довкола Чарівниці: б'є всіх поруч і
## заморожує їх у крижані брили — час відійти чи добити.

const RADIUS := 5.0
const DAMAGE := 1.1
const FREEZE := 1.8

func _init() -> void:
	id = &"frost_nova"
	title = "Крижана нова"
	description = "Хвиля холоду б'є всіх довкола й заморожує їх у крижані брили."
	color = Spells3D.FROST_COLOR
	icon_kind = "frost"
	cooldown = 11.0

func _use(player: Node) -> bool:
	var parent: Node = player.get_parent()
	var center: Vector3 = player.global_position
	CombatVfx.shockwave(parent, center, RADIUS, color, 0.45)
	Fx.bloom(parent, center + Vector3.UP * 0.06, "smoke_10", RADIUS * 2.2, Color(0.75, 0.9, 1.0, 0.55), 0.7)
	for enemy: Enemy3D in player.enemies_in_radius(RADIUS):
		player.deal_damage(enemy, DAMAGE, Vector3.ZERO, true, id)
		if enemy.is_alive():
			enemy.freeze(FREEZE * player.spell_power(), true)
	player.shake_camera(0.08)
	return true
