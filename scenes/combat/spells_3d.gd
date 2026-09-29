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
const RUNE_COLOR := Color(0.35, 0.85, 1.0)
const CARD_COLOR := Color(1.0, 0.8, 0.35)

## Книга рун: печать під ціллю вибухає через мить.
const RUNE_RADIUS := 1.7
const RUNE_DELAY := 0.45
const RUNE_AHEAD := 5.0
## Рунні карти: віяло з трьох, кут між картами, оберт у польоті.
const CARD_COUNT := 3
const CARD_FAN := 0.12
const CARD_DAMAGE := 0.55
const CARD_SPIN := 16.0

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
		"rune":
			_runes(player, origin, direction, target)
		"cards":
			_cards(player, weapon, origin, direction, target)
		_:
			_bolts(player, "arcane", ARCANE_COLOR, origin, direction, target, weapon.spell_speed,
				ARCANE_HOMING * player.spell_power(), arcane_hit.bind(player))
	CombatVfx.muzzle_flash(player.get_parent(), origin, direction, weapon.color)

## Один снаряд або кілька ("Подвійні чари").
##
## Раніше додаткові снаряди летіли віялом обабіч прицілу — і обидва
## проходили повз ворога, в якого герой цілився. Тепер кожен має свою
## ціль: другий — найближчого ворога біля основної цілі, а якщо поруч
## нікого — ту саму ціль: стартує трохи збоку й сходиться в ній.
static func _bolts(player: Node, kind: String, color: Color, origin: Vector3, direction: Vector3,
		target: Enemy3D, speed: float, homing: float, on_hit: Callable) -> void:
	var count: int = 1 + player.spell_extra()
	var targets := volley_targets(player, target, count)
	var side := direction.cross(Vector3.UP).normalized()
	for i in count:
		var bolt_target: Enemy3D = targets[i] if i < targets.size() else target
		var from := origin
		var aim := direction
		if bolt_target != null and is_instance_valid(bolt_target) and bolt_target.is_alive():
			if i > 0 and bolt_target == target:
				from = origin + side * (0.35 if i % 2 == 1 else -0.35)
			aim = (chest(bolt_target) - from).normalized()
		elif i > 0:
			# Цілі немає зовсім — невеличке віяло вперед.
			aim = direction.rotated(Vector3.UP, 0.1 * ceilf(i / 2.0) * (1.0 if i % 2 == 1 else -1.0))
		var bolt := SpellBolt.create(player, kind, 1.0, color)
		# Легке наведення, щоб снаряд не мазав по ворогу, що рухається.
		bolt.homing = maxf(homing, 2.5 if bolt_target != null else 0.0)
		bolt.target = bolt_target
		bolt.pierce = player.spell_pierce()
		bolt.on_hit = on_hit
		player.get_parent().add_child(bolt)
		bolt.launch(from, aim, speed)

## Цілі для залпу: спершу основна, далі найближчі до неї вороги, яких
## героєві видно.
static func volley_targets(player: Node, target: Enemy3D, count: int) -> Array[Enemy3D]:
	var result: Array[Enemy3D] = []
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return result
	result.append(target)
	if count <= 1:
		return result
	var others: Array[Enemy3D] = []
	for enemy: Enemy3D in player.aim_targets_in_radius(LIGHTNING_RANGE):
		if enemy != target and enemy.global_position.distance_to(target.global_position) < 6.0:
			others.append(enemy)
	others.sort_custom(func(a: Enemy3D, b: Enemy3D) -> bool:
		return a.global_position.distance_to(target.global_position) < b.global_position.distance_to(target.global_position))
	for enemy in others:
		if result.size() >= count:
			break
		result.append(enemy)
	return result

## Куди цілитись у ворога — у груди, а не в ноги.
static func chest(enemy: Enemy3D) -> Vector3:
	return enemy.global_position + Vector3.UP * enemy.target_height * 0.55

# --- книга рун і рунні карти (Руновод) ---

## Під ціллю (і під сусідами — "Подвійні чари") проступає печать і за
## мить вибухає. Цілі немає — печать лягає попереду.
static func _runes(player: Node, origin: Vector3, direction: Vector3, target: Enemy3D) -> void:
	var parent: Node = player.get_parent()
	var power: float = player.spell_power()
	var radius: float = RUNE_RADIUS * sqrt(power) + 0.25 * player.spell_pierce()
	var targets := volley_targets(player, target, 1 + player.spell_extra())
	if targets.is_empty():
		var ahead: Vector3 = player.global_position + Vector3(direction.x, 0.0, direction.z).normalized() * RUNE_AHEAD
		RuneSeal.spawn(parent, player, ahead, radius, RUNE_DELAY, 1.0)
		return
	for enemy in targets:
		RuneSeal.spawn(parent, player, enemy.global_position, radius, RUNE_DELAY, 1.0)

## Віяло карт: середня летить точно в ціль, крайні — трохи обабіч і
## дістають сусідів. Карта прошиває ворога наскрізь.
static func _cards(player: Node, weapon: WeaponDef, origin: Vector3, direction: Vector3, target: Enemy3D) -> void:
	var count: int = CARD_COUNT + player.spell_extra()
	for i in count:
		var angle := (float(i) - float(count - 1) * 0.5) * CARD_FAN
		var card := SpellBolt.create(player, "card", CARD_DAMAGE * player.spell_power(), CARD_COLOR)
		card.spin = CARD_SPIN
		card.pierce = 1 + player.spell_pierce()
		card.on_hit = card_hit.bind(player)
		if absf(angle) < 0.01 and target != null and is_instance_valid(target):
			card.target = target
			card.homing = 2.5
		player.get_parent().add_child(card)
		card.launch(origin, direction.rotated(Vector3.UP, angle), weapon.spell_speed)

static func card_hit(_enemy: Enemy3D, position: Vector3, player: Node) -> void:
	CombatVfx.impact(player.get_parent(), position, CARD_COLOR, false)

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
	for enemy: Enemy3D in player.aim_targets_in_radius(LIGHTNING_RANGE):
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
