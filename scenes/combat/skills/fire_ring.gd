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
var _ring: Node3D
var _age := 0.0

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
	_age = 0.0
	# Стіна вогню довкола Чарівниці (Fx.make_fire_wall): розгоряється від
	# неї назовні, іде за нею, язики полум'я по колу; наприкінці гасне.
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = Fx.make_fire_wall()
	player.add_child(_ring)
	_ring.position = Vector3(0, 0.04, 0)
	Fx.update_fire_wall(_ring, 0.3, 0.2, 0.0)
	return true

func _update(player: Node, delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	_age += delta
	if _ring != null and is_instance_valid(_ring):
		var grow := ease(minf(_age / 0.3, 1.0), 0.4)
		var fade := clampf(_left / 0.45, 0.0, 1.0)
		var power := minf(_age / 0.15, 1.0) * fade
		Fx.update_fire_wall(_ring, maxf(_radius(player) * grow, 0.3), 1.35 * (0.4 + 0.6 * grow) * (0.5 + 0.5 * fade), power)
		if _left <= 0.0:
			var ring := _ring
			(ring.get_node("Embers") as CPUParticles3D).emitting = false
			(ring.get_node("Flames") as CPUParticles3D).emitting = false
			ring.get_tree().create_timer(0.8, false).timeout.connect(ring.queue_free)
			_ring = null
	_next_tick -= delta
	if _next_tick > 0.0:
		return
	_next_tick = TICK
	var radius := _radius(player)
	var damage := TICK_DAMAGE * (1.0 + 0.15 * talent_level(player)) * _ring_power(player)
	for enemy: Enemy3D in player.enemies_in_radius(radius):
		player.deal_damage(enemy, damage, Vector3.ZERO, false, id)

func _radius(player: Node) -> float:
	return (RADIUS + 0.2 * talent_level(player)) * (1.0 + (_ring_power(player) - 1.0) * 0.5)

## Здібність походу "Жар кола" (є лише в 3D-героя).
func _ring_power(player: Node) -> float:
	return player.ring_power() if player.has_method("ring_power") else 1.0
