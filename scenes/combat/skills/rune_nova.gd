extends HeroSkill3D

## РУННА НОВА — Руновод.
## Вибух рунної сили навколо героя: б'є по всіх у великому колі.
## Особистий талант "Пробивна Руна" розширює коло.

const RADIUS := 4.5
const DAMAGE := 2.2
const KNOCKBACK := 3.0
const CAST_TIME := 0.3
const NOVA_COLOR := Color(0.65, 0.55, 1.0)

var _hit_left := -1.0

func _init() -> void:
	id = &"rune_nova"
	title = "Рунна Нова"
	description = "Вибух рун навколо героя — б'є всіх у великому колі."
	color = NOVA_COLOR
	icon_kind = "nova"
	cooldown = 7.0

func _use(player: Node) -> bool:
	_hit_left = CAST_TIME
	var radius := RADIUS + 0.4 * talent_level(player)
	CombatVfx.shockwave(player.get_parent(), player.global_position, radius, color, 0.45)
	player.spin_model(CAST_TIME)
	return true

func _update(player: Node, delta: float) -> void:
	if _hit_left < 0.0:
		return
	_hit_left -= delta
	if _hit_left > 0.0:
		return
	_hit_left = -1.0
	var radius := RADIUS + 0.4 * talent_level(player)
	var hits := 0
	for enemy: Enemy3D in player.enemies_in_radius(radius):
		var push: Vector3 = enemy.global_position - player.global_position
		push.y = 0.0
		player.deal_damage(enemy, DAMAGE, push.normalized() * KNOCKBACK, true)
		hits += 1
	CombatVfx.shockwave(player.get_parent(), player.global_position, radius, Color(1, 1, 1, 0.7), 0.3)
	player.shake_camera(0.14 if hits > 0 else 0.06)
