extends EnemyAbility

## ВОСКРЕСІННЯ (Рунний обеліск, Безодня Рун). Ворог упав поруч (ближче за
## range) — через delay секунд обеліск підіймає його знову (з hp частиною
## здоров'я, примарно-фіолетового). Кожного — лише раз. Розбий обеліск —
## і мертві лишаться мертвими.

const COLOR := Color(0.35, 0.9, 1.0)

var _watched := {}
var _pending: Array = []
## Що видно гравцеві: коло, в межах якого обеліск воскрешає, і підпис.
var _zone: MeshInstance3D
var _label: Label3D
var _beam_left := 0.0

func _init() -> void:
	id = "revive"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	if not enemy.is_alive():
		return
	var radius := float(config.get("range", 7.0))
	if _zone == null:
		_make_signs(radius)
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or other == enemy or other.kind == Enemy3D.Kind.BOSS or other.stationary:
			continue
		if bool(other.definition.get("revived", false)) or not other.is_alive():
			continue
		if other.global_position.distance_to(enemy.global_position) <= radius and not _watched.has(other):
			_watched[other] = true
			other.died.connect(_on_died.bind(other.definition.duplicate(true)))
	_beam_left -= delta
	var beam := _beam_left <= 0.0
	if beam:
		_beam_left = 0.22
	for item: Dictionary in _pending.duplicate():
		item.left = float(item.left) - delta
		# Поки воскрешає — від обеліска до тіла б'є промінь, над тілом
		# відлік: видно, кого і коли підніме.
		if beam:
			CombatVfx.lightning(world(), [enemy.global_position + Vector3.UP * enemy.target_height * 0.9, item.position + Vector3.UP * 0.4], COLOR, 0.12)
		if is_instance_valid(item.count):
			(item.count as Label3D).text = str(ceili(float(item.left)))
		if float(item.left) <= 0.0:
			_pending.erase(item)
			_raise(item)
	if _label != null:
		_label.modulate.a = 1.0 if not _pending.is_empty() else 0.55

func _on_died(position: Vector3, _xp: int, definition: Dictionary) -> void:
	if not enemy.is_alive():
		return
	if position.distance_to(enemy.global_position) > float(config.get("range", 7.0)) + 1.0:
		return
	var mark := BossFx.rune_glyph(Color(COLOR, 0.95), 2.0)
	world().add_child(mark)
	mark.global_position = position + Vector3.UP * 0.06
	var count := _make_label(str(ceili(float(config.get("delay", 3.0)))), 140, COLOR)
	world().add_child(count)
	count.global_position = position + Vector3.UP * 1.6
	CombatVfx.lightning(world(), [enemy.global_position + Vector3.UP * enemy.target_height * 0.9, position + Vector3.UP * 0.3], COLOR, 0.15)
	_pending.append({"position": position, "definition": definition, "left": float(config.get("delay", 3.0)), "mark": mark, "count": count})

func _raise(item: Dictionary) -> void:
	if is_instance_valid(item.mark):
		item.mark.queue_free()
	if is_instance_valid(item.count):
		item.count.queue_free()
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
	BossFx.dark_effect(world(), BossFx.DARK_AREA, item.position, 0.6, 1.2)
	CombatVfx.smoke_puff(world(), item.position + Vector3.UP * 0.6, COLOR, 1.4)

func _make_signs(radius: float) -> void:
	_zone = CombatVfx.make_ground_marker(Color(COLOR, 0.28), radius)
	CombatVfx.set_param(_zone, &"progress", 1.0)
	enemy.add_child(_zone)
	_zone.position = Vector3.UP * 0.05
	_label = _make_label("Воскрешає полеглих — розбий першим", 52, COLOR)
	enemy.add_child(_label)
	_label.position = Vector3.UP * (enemy.target_height + 0.7)

func _make_label(text: String, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.005
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color.lerp(Color.WHITE, 0.3)
	return label

func on_death() -> void:
	for item: Dictionary in _pending:
		if is_instance_valid(item.mark):
			item.mark.queue_free()
		if is_instance_valid(item.count):
			item.count.queue_free()
	_pending.clear()
	if _zone != null and is_instance_valid(_zone):
		_zone.queue_free()
	if _label != null and is_instance_valid(_label):
		_label.queue_free()
	CombatVfx.shockwave(world(), enemy.global_position, 3.0, COLOR, 0.4)
