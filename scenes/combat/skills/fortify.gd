extends HeroSkill3D

## СТІНА ЩИТІВ (Танк): кілька секунд герой отримує набагато менше шкоди
## й одразу відновлює частину здоров'я. Вороги поруч відлітають.

const DURATION := 5.0
const TAKEN := 0.4
const HEAL := 0.12
const PUSH_RADIUS := 3.2

var _left := 0.0

func _init() -> void:
	id = &"fortify"
	title = "Стіна щитів"
	description = "П'ять секунд отримуєш на 60% менше шкоди, одразу лікуєш 12% здоров'я й відкидаєш ворогів поруч."
	color = Color(0.45, 0.7, 1.0)
	icon_kind = "nova"
	cooldown = 14.0

func _use(player: Node) -> bool:
	if _left <= 0.0:
		player.set("_damage_taken_factor", float(player.get("_damage_taken_factor")) * TAKEN)
	_left = DURATION
	player.heal(float(player.get("max_hp")) * HEAL)
	for enemy: Enemy3D in player.enemies_in_radius(PUSH_RADIUS, false):
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		player.deal_damage(enemy, 0.4, offset.normalized() * 7.0, false, id)
	CombatVfx.shockwave(player.get_parent(), player.global_position, PUSH_RADIUS, color, 0.4)
	CombatVfx.flash_model(player.model, color, 0.3)
	player.play_clip("Sword_Block")
	return true

func _update(player: Node, delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		player.set("_damage_taken_factor", float(player.get("_damage_taken_factor")) / TAKEN)
