extends HeroSkill3D

## АРКАННИЙ ЗАЛП — особлива здібність Арканного посоха.
## Вісім стріл розлітаються колом і самі знаходять ворогів довкола:
## кожна бере свою ціль, тож залп накриває всю юрбу, а не одного.

const BOLTS := 8
const RADIUS := 11.0
const DAMAGE := 0.9
const SPEED := 13.0
const HOMING := 7.0

func _init() -> void:
	id = &"arcane_barrage"
	title = "Арканний залп"
	description = "Вісім арканних стріл розлітаються колом і самі знаходять ворогів довкола."
	color = Spells3D.ARCANE_COLOR
	icon_kind = "nova"
	cooldown = 9.0

func _use(player: Node) -> bool:
	var enemies: Array[Enemy3D] = player.enemies_in_radius(RADIUS)
	var origin: Vector3 = player.spell_origin()
	var parent: Node = player.get_parent()
	for i in BOLTS:
		var angle := TAU * float(i) / BOLTS
		var bolt := SpellBolt.create(player, "arcane", DAMAGE, color)
		bolt.homing = HOMING
		if not enemies.is_empty():
			bolt.target = enemies[i % enemies.size()]
		bolt.on_hit = Spells3D.arcane_hit.bind(player)
		parent.add_child(bolt)
		bolt.launch(origin, Vector3(sin(angle), 0.1, cos(angle)), SPEED)
	CombatVfx.shockwave(parent, player.global_position, 2.2, color, 0.35)
	player.shake_camera(0.05)
	return true
