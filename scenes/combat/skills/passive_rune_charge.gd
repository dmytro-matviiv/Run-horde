extends HeroPassive3D

## РУННИЙ ЗАРЯД — пасивка Руновода.
## Кожен удар накопичує заряд у посоху; на сьомому посох сам вибухає
## малою новою. Чим швидша зброя, тим частіші вибухи — тому Руноводу
## вигідна швидка зброя.

const HITS_PER_NOVA := 7
const RADIUS := 3.0
const DAMAGE := 1.2
const KNOCKBACK := 2.0
const NOVA_COLOR := Color(0.65, 0.55, 1.0)

var _hits := 0

func _init() -> void:
	id = &"rune_charge"
	title = "Рунний Заряд"
	description = "Кожен сьомий удар сам вибухає рунною новою навколо героя."
	color = NOVA_COLOR

## Показуємо заповнення заряду тією ж шкалою, що й лють, — гравець
## бачить, коли гримне.
func get_charge() -> float:
	return float(_hits) / float(HITS_PER_NOVA)

func on_hit(player: Node, _enemy: Node, _amount: float, _heavy: bool) -> void:
	_hits += 1
	if _hits < HITS_PER_NOVA:
		return
	_hits = 0
	CombatVfx.shockwave(player.get_parent(), player.global_position, RADIUS, NOVA_COLOR, 0.35)
	for enemy: Enemy3D in player.enemies_in_radius(RADIUS):
		var push: Vector3 = enemy.global_position - player.global_position
		push.y = 0.0
		player.deal_damage(enemy, DAMAGE, push.normalized() * KNOCKBACK, false)
