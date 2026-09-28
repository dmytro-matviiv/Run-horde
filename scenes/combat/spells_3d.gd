extends RefCounted
class_name Spells3D

## ЧАРИ ПОСОХІВ Чарівниці. Кожен посох — своя механіка, яку видно:
##   arcane    — арканні стріли самі доводяться на ціль;
##   frost     — крижаний уламок сповільнює (під ворогом синіє іній), а
##               третій поспіль заморожує його в крижану брилу;
##   venom     — отруйна куля лишає на влучанні хмару, що труїть;
##   lightning — блискавка б'є ціль і перескакує на сусідів.
##
## Здібності походу (player.spell_*) підсилюють чари: більше снарядів,
## пробиття, сила ефекту посоха.

const ARCANE_COLOR := Color(0.78, 0.45, 1.0)
const FROST_COLOR := Color(0.55, 0.85, 1.0)
const VENOM_COLOR := Color(0.45, 0.95, 0.3)
const LIGHTNING_COLOR := Color(1.0, 0.92, 0.45)

const ARCANE_HOMING := 5.5
const FROST_SLOW := 0.55
const FROST_SLOW_TIME := 2.5
const FROST_STACKS_TO_FREEZE := 3
const FROST_FREEZE_TIME := 1.3
const VENOM_CLOUD_RADIUS := 1.9
const VENOM_CLOUD_TIME := 3.0
const VENOM_TICK_DAMAGE := 0.35
const LIGHTNING_RANGE := 10.0
const CHAIN_JUMPS := 3
const CHAIN_RADIUS := 5.0
const CHAIN_FALLOFF := 0.75

## Пустити чари посоха з точки origin у напрямку direction (у ціль,
## якщо вона є).
static func cast(player: Node, weapon: WeaponDef, origin: Vector3, direction: Vector3, target: Enemy3D) -> void:
	match weapon.spell:
		"frost":
			_bolts(player, "frost", FROST_COLOR, origin, direction, target, weapon.spell_speed, 0.0,
				frost_hit.bind(player))
		"venom":
			_bolts(player, "venom", VENOM_COLOR, origin, direction, target, weapon.spell_speed, 0.0,
				venom_hit.bind(player))
		"lightning":
			_lightning(player, origin, direction, target)
		_:
			_bolts(player, "arcane", ARCANE_COLOR, origin, direction, target, weapon.spell_speed,
				ARCANE_HOMING * player.spell_power(), arcane_hit.bind(player))
	CombatVfx.muzzle_flash(player.get_parent(), origin, direction, weapon.color)

## Один снаряд або кілька віялом ("Подвійні чари").
static func _bolts(player: Node, kind: String, color: Color, origin: Vector3, direction: Vector3,
		target: Enemy3D, speed: float, homing: float, on_hit: Callable) -> void:
	var count: int = 1 + player.spell_extra()
	for i in count:
		var spread := 0.0 if count == 1 else lerpf(-0.18, 0.18, float(i) / float(count - 1))
		var bolt := SpellBolt.create(player, kind, 1.0, color)
		bolt.homing = homing
		bolt.target = target
		bolt.pierce = player.spell_pierce()
		bolt.on_hit = on_hit
		player.get_parent().add_child(bolt)
		bolt.launch(origin, direction.rotated(Vector3.UP, spread), speed)

# --- що робить влучання ---

static func arcane_hit(enemy: Enemy3D, position: Vector3, player: Node) -> void:
	CombatVfx.impact(player.get_parent(), position, ARCANE_COLOR, false)
	if enemy != null:
		CombatVfx.shockwave(player.get_parent(), enemy.global_position, 0.9, ARCANE_COLOR, 0.2)

## Крига: сповільнює, а третє влучання поспіль заморожує в брилу.
static func frost_hit(enemy: Enemy3D, position: Vector3, player: Node) -> void:
	var parent: Node = player.get_parent()
	CombatVfx.impact(parent, position, FROST_COLOR, false)
	if enemy == null or not enemy.is_alive():
		return
	var power: float = player.spell_power()
	enemy.apply_slow(FROST_SLOW, FROST_SLOW_TIME * power)
	var stacks := int(enemy.get_meta(&"frost_stacks", 0)) + 1
	if stacks >= FROST_STACKS_TO_FREEZE:
		stacks = 0
		enemy.freeze(FROST_FREEZE_TIME * power)
		CombatVfx.shockwave(parent, enemy.global_position, 1.3, FROST_COLOR, 0.3)
	enemy.set_meta(&"frost_stacks", stacks)

## Отрута: там, де куля влучила (у ворога чи в стіну), лишається хмара.
static func venom_hit(enemy: Enemy3D, position: Vector3, player: Node) -> void:
	var parent: Node = player.get_parent()
	CombatVfx.impact(parent, position, VENOM_COLOR, false)
	var at := enemy.global_position if enemy != null and is_instance_valid(enemy) else position
	PoisonCloud.spawn(parent, player, at, VENOM_CLOUD_RADIUS * sqrt(player.spell_power()),
		VENOM_CLOUD_TIME, VENOM_TICK_DAMAGE)

# --- блискавка ---

## Блискавка б'є миттєво: ціль, далі перескакує на найближчого сусіда,
## щоразу трохи слабше. Нікого поруч — розряд просто б'є вперед.
static func _lightning(player: Node, origin: Vector3, direction: Vector3, target: Enemy3D) -> void:
	var parent: Node = player.get_parent()
	var first := target
	if first == null or not is_instance_valid(first) or not first.is_alive():
		first = _nearest_ahead(player, direction)
	if first == null:
		var fizzle: Array[Vector3] = [origin, origin + direction * 5.0]
		CombatVfx.lightning(parent, fizzle, LIGHTNING_COLOR)
		return
	var hit: Array[Enemy3D] = []
	# "Подвійні чари": ще одна гілка — від іншого ворога поруч.
	var starts: Array[Enemy3D] = [first]
	for i in player.spell_extra():
		var other := _next_jump(first.global_position, starts, player)
		if other != null:
			starts.append(other)
	var falloff := minf(CHAIN_FALLOFF * player.spell_power(), 0.95)
	for start in starts:
		var points: Array[Vector3] = [origin]
		var current: Enemy3D = start
		var multiplier := 1.0
		var jumps: int = CHAIN_JUMPS + player.spell_pierce()
		while current != null:
			var chest := current.global_position + Vector3.UP * current.target_height * 0.55
			points.append(chest)
			hit.append(current)
			player.deal_damage(current, multiplier, Vector3.ZERO, false)
			CombatVfx.impact(parent, chest, LIGHTNING_COLOR, false)
			if jumps <= 0:
				break
			jumps -= 1
			multiplier *= falloff
			current = _next_jump(chest, hit, player)
		CombatVfx.lightning(parent, points, LIGHTNING_COLOR)

## Найближчий видимий ворог попереду — якщо цілі немає.
static func _nearest_ahead(player: Node, direction: Vector3) -> Enemy3D:
	var best: Enemy3D = null
	var best_score := INF
	for enemy: Enemy3D in player.enemies_in_radius(LIGHTNING_RANGE):
		var offset: Vector3 = enemy.global_position - player.global_position
		offset.y = 0.0
		if offset.length() > 0.1 and direction.dot(offset.normalized()) < 0.4:
			continue
		if offset.length() < best_score:
			best = enemy
			best_score = offset.length()
	return best

## Наступний, на кого перескочить блискавка: найближчий живий, ще не
## влучений і не за стіною.
static func _next_jump(from: Vector3, exclude: Array[Enemy3D], player: Node) -> Enemy3D:
	var best: Enemy3D = null
	var best_distance := INF
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for enemy: Enemy3D in player.enemies_near(from, CHAIN_RADIUS):
		if exclude.has(enemy):
			continue
		var distance := enemy.global_position.distance_to(from)
		if distance >= best_distance:
			continue
		var query := PhysicsRayQueryParameters3D.create(from, enemy.global_position + Vector3.UP)
		query.collision_mask = 1
		if not space.intersect_ray(query).is_empty():
			continue
		best = enemy
		best_distance = distance
	return best
