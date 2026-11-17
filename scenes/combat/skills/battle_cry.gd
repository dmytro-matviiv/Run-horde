extends HeroSkill3D

## БОЙОВИЙ КЛИЧ (Мечник): 8 секунд +30% шкоди й +25% швидкості атаки,
## вороги поруч відлітають від крику.

const DURATION := 8.0
const RADIUS := 3.2

func _init() -> void:
	id = &"battle_cry"
	title = "Бойовий клич"
	description = "Могутній клич: 8 секунд +30% шкоди й +25% швидкості атаки, вороги поруч відлітають."
	color = Color(1.0, 0.35, 0.25)
	icon_kind = "nova"
	cooldown = 18.0

func _use(player: Node) -> bool:
	player.battle_cry(DURATION)
	for enemy: Enemy3D in player.enemies_in_radius(RADIUS, false):
		var push: Vector3 = enemy.global_position - player.global_position
		push.y = 0.0
		player.deal_damage(enemy, 0.3, push.normalized() * 7.0, false, id)
	CombatVfx.shockwave(player.get_parent(), player.global_position, RADIUS, color, 0.4)
	CombatVfx.flash_model(player.model, color, 0.35)
	player.play_clip("Sword_Block", 1.2)
	player.shake_camera(0.12)
	return true
