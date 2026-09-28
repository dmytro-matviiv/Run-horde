extends HeroSkill3D

## ДИМОВА ЗАВІСА — Асасин Порожнечі.
## Асасин зникає: вороги гублять його, перестають бити й шукають
## наосліп. Поки він у тіні — б'є вдвічі сильніше й біжить швидше.
## Особистий талант "Володар Тіней" продовжує завісу.

const DURATION := 3.0
const DAMAGE_BONUS := 2.0
const SPEED_BONUS := 0.2
const SMOKE_COLOR := Color(0.6, 0.35, 0.95)

func _init() -> void:
	id = &"smoke_veil"
	title = "Димова Граната"
	description = "Дим ховає бійця: вороги гублять ціль, а він кілька секунд б'є вдвічі сильніше."
	color = SMOKE_COLOR
	icon_kind = "smoke"
	cooldown = 10.0

func _use(player: Node) -> bool:
	var duration: float = DURATION + 0.5 * talent_level(player) + player.smoke_bonus()
	player.set_concealed(duration, DAMAGE_BONUS, SPEED_BONUS)
	var parent := player.get_parent()
	CombatVfx.shockwave(parent, player.global_position, 2.6, color, 0.5)
	CombatVfx.impact(parent, player.global_position + Vector3.UP, color, true)
	return true
