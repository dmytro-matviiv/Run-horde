extends EnemyAbility

## КРИЖАНИЙ ПАНЦИР (Інейна чаклунка): раз за бій простягає руку до
## найближчого союзника — його вкриває лід, і seconds секунд він не
## отримує шкоди. Тому чаклунку вбивають першою.

const COLOR := Color(0.55, 0.9, 1.0)

var _target: Enemy3D

func _init() -> void:
	id = "ice_armor"
	cooldown = 9999.0

func try_use(_distance: float) -> bool:
	_target = _find_target()
	if _target == null:
		return false
	start_cooldown()
	enemy.face_point(_target.global_position)
	enemy.begin_special(id, 0.5, Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_alive():
		return
	var points: Array[Vector3] = [enemy.global_position + Vector3.UP * enemy.target_height * 0.7,
		_target.global_position + Vector3.UP * _target.target_height * 0.6]
	CombatVfx.lightning(world(), points, COLOR)
	_target.add_absorb(1.0e9, float(config.get("seconds", 3.0)), COLOR, true)
	_target = null

func _find_target() -> Enemy3D:
	var best: Enemy3D = null
	var best_distance := float(config.get("range", 10.0))
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or other == enemy or not other.is_alive() or other.has_absorb() or other.stationary \
				or other.is_dormant():
			continue
		var distance := other.global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best = other
			best_distance = distance
	return best
