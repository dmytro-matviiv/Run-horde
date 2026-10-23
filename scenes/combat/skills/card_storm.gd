extends HeroSkill3D

## КОЛОДА ДОЛІ — особлива здібність Рунних карт.
## Дванадцять карт розлітаються колом, прошивають усіх на шляху й
## повертаються до Руновода, як бумеранг, — б'ють удруге на зворотному
## шляху.

const CARDS := 12
const DAMAGE := 0.7
const SPEED := 15.0
const SPIN := 18.0

func _init() -> void:
	id = &"card_storm"
	title = "Колода долі"
	description = "Дванадцять карт розлітаються колом і повертаються, як бумеранг, — б'ють двічі."
	color = Spells3D.CARD_COLOR
	icon_kind = "cards"
	cooldown = 9.0

func _use(player: Node) -> bool:
	var origin: Vector3 = (player as Node3D).global_position + Vector3.UP * 1.1
	var parent: Node = player.get_parent()
	for i in CARDS:
		var angle := TAU * float(i) / CARDS
		var card := SpellBolt.create(player, "card", DAMAGE * player.spell_power(), color)
		card.source = id
		card.spin = SPIN
		card.boomerang = true
		card.pierce = 99
		card.on_hit = Spells3D.card_hit.bind(player)
		parent.add_child(card)
		card.launch(origin, Vector3(sin(angle), 0.0, cos(angle)), SPEED)
	CombatVfx.shockwave(parent, player.global_position, 1.6, color, 0.3)
	return true
