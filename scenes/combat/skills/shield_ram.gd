extends "res://scenes/combat/skills/bear_charge.gd"

## ТАРАН ЩИТОМ (Танк): мчиш уперед зі щитом, збиваючи й відкидаючи всіх
## на шляху; той, у кого врізався, оглушений.

func _init() -> void:
	super()
	id = &"shield_ram"
	title = "Таран щитом"
	description = "Мчиш уперед зі щитом, збиваючи й відкидаючи всіх на шляху; той, у кого врізався, оглушений."
	color = Color(0.6, 0.75, 1.0)
	icon_kind = "dash"
	cooldown = 8.0

func _use(player: Node) -> bool:
	if not super(player):
		return false
	if _target != null and is_instance_valid(_target):
		_target.stun(1.6, true)
	player.play_clip("Shield_Dash", 1.4)
	return true
