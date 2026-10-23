extends HeroSkill3D

## ВЕЛИКА ПЕЧАТЬ — особлива здібність Книги рун.
## Під ціллю проступає велике коло рун: усі, хто в ньому, застигають на
## місці, поки коло наливається світлом, — і печать вибухає.

const RADIUS := 3.4
const DELAY := 0.9
const HOLD := 0.6
const DAMAGE := 2.0
const AHEAD := 5.0

func _init() -> void:
	id = &"great_seal"
	title = "Велика печать"
	description = "Велике коло рун під ворогами: тримає всіх, хто в ньому, а тоді вибухає."
	color = Spells3D.RUNE_COLOR
	icon_kind = "rune"
	cooldown = 10.0

func _use(player: Node) -> bool:
	var at: Vector3 = player.global_position + player.facing_vector() * AHEAD
	var target: Enemy3D = player.get("_target")
	if target != null and is_instance_valid(target) and target.is_alive():
		at = target.global_position
	var seal := RuneSeal.spawn(player.get_parent(), player, at, RADIUS * sqrt(player.spell_power()), DELAY, DAMAGE, HOLD)
	seal.source = id
	return true
