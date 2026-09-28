extends HeroSkill3D

## ОТРУЙНЕ БОЛОТО — особлива здібність Посоха трясовини.
## Під ціллю (або перед Чарівницею) розливається велика трясовина: хто в
## ній — грузне (сповільнений) і труїться, поки не вибереться.

const RADIUS := 3.6
const DURATION := 5.0
const TICK_DAMAGE := 0.45
const SLOW := 0.55
const AHEAD := 4.0

func _init() -> void:
	id = &"venom_swamp"
	title = "Отруйне болото"
	description = "Велика трясовина під ворогами: сповільнює й труїть усіх, хто в ній."
	color = Spells3D.VENOM_COLOR
	icon_kind = "venom"
	cooldown = 12.0

func _use(player: Node) -> bool:
	var at: Vector3 = player.global_position + player.facing_vector() * AHEAD
	var target: Enemy3D = player.get("_target")
	if target != null and is_instance_valid(target) and target.is_alive():
		at = target.global_position
	PoisonCloud.spawn(player.get_parent(), player, at, RADIUS * sqrt(player.spell_power()), DURATION,
		TICK_DAMAGE, SLOW)
	return true
