extends HeroSkill3D

## ВИХОР — Клинкова Вартова.
## Оберт навколо себе: б'є всіх поруч і відкидає їх. Головна відповідь
## на "мене оточили".
##
## Особистий талант "Вихор Клинків" робить його сильнішим і частішим.

const RADIUS := 3.6
const DAMAGE := 2.4
const KNOCKBACK := 4.0
const SPIN_TIME := 0.45
const HIT_DELAY := 0.12
const SKILL_COLOR := Color(0.35, 0.95, 1.0)

var _hit_left := -1.0

func _init() -> void:
	id = &"whirlwind"
	title = "Вихор"
	description = "Оберт із клинком: б'є й відкидає всіх навколо."
	color = SKILL_COLOR
	icon_kind = "whirl"
	cooldown = 6.0

func _use(player: Node) -> bool:
	var level := talent_level(player)
	# Талант: сильніше й частіше.
	cooldown = maxf(6.0 - 0.4 * level, 3.0)
	_hit_left = HIT_DELAY
	player.play_whirl(SPIN_TIME)
	var radius := _radius(player, level)
	# Вихор — один ефект (Fx.whirl): без старого сліду леза по колу поверх.
	Fx.whirl(player, radius, color, SPIN_TIME)
	return true

func _update(player: Node, delta: float) -> void:
	if _hit_left < 0.0:
		return
	_hit_left -= delta
	if _hit_left > 0.0:
		return
	_hit_left = -1.0
	var level := talent_level(player)
	var radius := _radius(player, level)
	var damage: float = DAMAGE * (1.0 + 0.18 * level) * player.whirl_power()
	var hits := 0
	for enemy: Enemy3D in player.enemies_in_radius(radius):
		var push: Vector3 = enemy.global_position - player.global_position
		push.y = 0.0
		player.deal_damage(enemy, damage, push.normalized() * KNOCKBACK, true, id)
		hits += 1
	CombatVfx.hitstop(player.get_tree(), 0.05 if hits > 0 else 0.0)
	player.shake_camera(0.1 if hits > 0 else 0.05)

## Радіус з урахуванням особистого таланту героя й здібності "Буря
## клинків", узятої в поході.
func _radius(player: Node, level: int) -> float:
	return (RADIUS + 0.15 * level) * (1.0 + (player.whirl_power() - 1.0) * 0.5)
