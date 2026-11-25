extends EnemyAbility

## ЗЛИТТЯ (Розпечена іскра, Кузня Присмерку). Якщо три іскри довше за
## hold секунд тримаються купкою (ближче за radius одна до одної), вони
## зливаються в Полум'яне ядро ("into" — опис ядра): більше, повільніше,
## б'є по колу. Іскри краще вбивати поодинці, поки не злиплись.

const COLOR := Color(1.0, 0.55, 0.15, 0.9)

var _close_time := 0.0
var _merged := false

func _init() -> void:
	id = "merge"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	if _merged or not enemy.is_alive():
		return
	var mates := _mates()
	if mates.size() < 2:
		_close_time = 0.0
		return
	_close_time += delta
	# Хто злипається — жевріє дедалі яскравіше (видно, що зараз станеться).
	if _close_time >= float(config.get("hold", 1.5)):
		_merge(mates.slice(0, 2))

func _mates() -> Array:
	var found := []
	var radius := float(config.get("radius", 1.8))
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		if node == enemy or not (node is Enemy3D) or not node.is_alive():
			continue
		var other := node as Enemy3D
		var ability := _merge_of(other)
		if ability == null or ability._merged:
			continue
		if other.global_position.distance_to(enemy.global_position) <= radius:
			found.append(other)
	found.sort_custom(func(a: Enemy3D, b: Enemy3D) -> bool:
		return a.global_position.distance_to(enemy.global_position) < b.global_position.distance_to(enemy.global_position))
	return found

static func _merge_of(other: Enemy3D) -> EnemyAbility:
	for ability in other.abilities:
		if ability.id == "merge":
			return ability
	return null

func _merge(mates: Array) -> void:
	var group: Array = [enemy] + mates
	var center := Vector3.ZERO
	for member: Enemy3D in group:
		(_merge_of(member) as EnemyAbility).set("_merged", true)
		center += member.global_position
	center /= group.size()
	var into: Dictionary = config.get("into", {})
	if not into.is_empty():
		enemy.spawn_requested.emit(center, into.duplicate(true), null)
	CombatVfx.shockwave(world(), center, 2.2, COLOR, 0.45)
	CombatVfx.impact(world(), center + Vector3.UP * 0.8, COLOR, true)
	# Іскри зникають у ядрі — без досвіду (досвід дасть ядро).
	for member: Enemy3D in group:
		member.xp_reward = 0
		member.expire()
