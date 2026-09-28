extends HeroSkill3D

## ВОГНЯНЕ КОЛО — Чарівниця.
## Навколо неї кілька секунд горить кільце: усе, що стоїть у ньому,
## горить раз за разом. Нагорода за те, щоб не тікати, а крутитись у
## гущі. Особистий талант "Багаття Люті" і здібність походу "Жар кола"
## роблять коло більшим і гарячішим.

const RADIUS := 3.4
const DURATION := 3.0
const TICK := 0.5
const TICK_DAMAGE := 0.5
const FIRE_COLOR := Color(1.0, 0.5, 0.15)

var _left := 0.0
var _next_tick := 0.0

func _init() -> void:
	id = &"fire_ring"
	title = "Вогняне Коло"
	description = "Кільце вогню навколо Чарівниці: кілька секунд палить усіх, хто поруч."
	color = FIRE_COLOR
	icon_kind = "fire"
	cooldown = 9.0

func _use(player: Node) -> bool:
	_left = DURATION
	_next_tick = 0.0
	CombatVfx.shockwave(player.get_parent(), player.global_position, _radius(player), color, 0.5)
	return true

func _update(player: Node, delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	_next_tick -= delta
	if _next_tick > 0.0:
		return
	_next_tick = TICK
	var radius := _radius(player)
	# Кільце йде за жрицею — воно горить навколо неї, а не на місці.
	CombatVfx.shockwave(player.get_parent(), player.global_position, radius, color, TICK)
	var damage := TICK_DAMAGE * (1.0 + 0.15 * talent_level(player)) * _ring_power(player)
	for enemy: Enemy3D in player.enemies_in_radius(radius):
		player.deal_damage(enemy, damage, Vector3.ZERO, false)

func _radius(player: Node) -> float:
	return (RADIUS + 0.2 * talent_level(player)) * (1.0 + (_ring_power(player) - 1.0) * 0.5)

## Здібність походу "Жар кола" (є лише в 3D-героя).
func _ring_power(player: Node) -> float:
	return player.ring_power() if player.has_method("ring_power") else 1.0
