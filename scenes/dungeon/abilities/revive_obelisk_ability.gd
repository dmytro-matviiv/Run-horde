extends EnemyAbility

## ВОСКРЕСІННЯ (Рунний обеліск, Безодня Рун). Ворог упав поруч (ближче за
## range) — через delay секунд обеліск підіймає його знову (з hp частиною
## здоров'я, примарно-фіолетового). Кожного — лише раз. Розбий обеліск —
## і мертві лишаться мертвими.

const COLOR := Color(0.35, 0.9, 1.0)

var _watched := {}
var _pending: Array = []

func _init() -> void:
	id = "revive"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	if not enemy.is_alive():
		return
	var radius := float(config.get("range", 7.0))
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or other == enemy or other.kind == Enemy3D.Kind.BOSS or other.stationary:
			continue
		if bool(other.definition.get("revived", false)) or not other.is_alive():
			continue
		if other.global_position.distance_to(enemy.global_position) <= radius and not _watched.has(other):
			_watched[other] = true
			other.died.connect(_on_died.bind(other.definition.duplicate(true)))
	for item: Dictionary in _pending.duplicate():
		item.left = float(item.left) - delta
		if float(item.left) <= 0.0:
			_pending.erase(item)
			_raise(item)

func _on_died(position: Vector3, _xp: int, definition: Dictionary) -> void:
	if not enemy.is_alive():
		return
	if position.distance_to(enemy.global_position) > float(config.get("range", 7.0)) + 1.0:
		return
	var mark := CombatVfx.make_telegraph(Color(COLOR, 0.7), 0.9, PI, false)
	world().add_child(mark)
	mark.global_position = position + Vector3.UP * 0.05
	CombatVfx.lightning(world(), [enemy.global_position + Vector3.UP * enemy.target_height * 0.9, position + Vector3.UP * 0.3], COLOR, 0.15)
	_pending.append({"position": position, "definition": definition, "left": float(config.get("delay", 3.0)), "mark": mark})

func _raise(item: Dictionary) -> void:
	if is_instance_valid(item.mark):
		item.mark.queue_free()
	if not enemy.is_alive():
		return
	var definition: Dictionary = item.definition
	definition.revived = true
	definition.hp = float(definition.get("hp", 30.0)) * float(config.get("hp", 0.6))
	definition.xp = 0
	definition.tint = Color(0.55, 0.45, 0.9)
	definition.glow = Color(0.15, 0.4, 0.6)
	definition.no_elite = true
	definition.erase("group")
	definition.erase("dormant")
	enemy.spawn_requested.emit(item.position, definition, null)
	CombatVfx.shockwave(world(), item.position, 1.6, COLOR, 0.4)

func on_death() -> void:
	for item: Dictionary in _pending:
		if is_instance_valid(item.mark):
			item.mark.queue_free()
	_pending.clear()
	CombatVfx.shockwave(world(), enemy.global_position, 3.0, COLOR, 0.4)
