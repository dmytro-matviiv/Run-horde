extends HeroPassive3D

## ФЕНІКС — пасивка Чарівниці (колишньої Жриці Багаття).
## Раз за похід вона не вмирає: замість смерті — спалах, половина
## здоров'я назад і вибух, що розкидає тих, хто вже святкував.

const HEAL_PART := 0.45
const BLAST_RADIUS := 4.0
const BLAST_DAMAGE := 1.5
const BLAST_KNOCKBACK := 7.0
const INVULNERABLE := 1.2
const FIRE_COLOR := Color(1.0, 0.6, 0.2)

var _used := false

func _init() -> void:
	id = &"phoenix"
	title = "Фенікс"
	description = "Раз за похід смертельний удар не вбиває: спалах повертає половину здоров'я й розкидає ворогів."
	color = FIRE_COLOR

## Поки не використаний — шкала повна: видно, що "життя в запасі" є.
func get_charge() -> float:
	return 0.0 if _used else 1.0

func on_lethal(player: Node) -> bool:
	if _used:
		return false
	_used = true
	var bonus: float = player.phoenix_bonus() if player.has_method("phoenix_bonus") else 0.0
	player.heal(player.max_hp * (HEAL_PART + bonus))
	player.grant_invulnerable(INVULNERABLE)
	CombatVfx.shockwave(player.get_parent(), player.global_position, BLAST_RADIUS, FIRE_COLOR, 0.6)
	CombatVfx.impact(player.get_parent(), player.global_position + Vector3.UP, FIRE_COLOR, true)
	player.shake_camera(0.25)
	for enemy: Enemy3D in player.enemies_in_radius(BLAST_RADIUS, false):
		var push: Vector3 = enemy.global_position - player.global_position
		push.y = 0.0
		player.deal_damage(enemy, BLAST_DAMAGE, push.normalized() * BLAST_KNOCKBACK, true)
	return true
