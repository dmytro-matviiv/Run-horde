extends EnemyAbility

## ТЕМНИЙ ЩИТ (Склепний чаклун): простягає руку до найближчого союзника
## (чия назва містить target, напр. "Орк") без щита — і на нього лягає
## зелена сфера, що поглинає amount шкоди (Enemy3D.add_absorb). Тому
## чаклуна вбивають першим.
##
## Налаштування: range (м), amount (частка здоров'я цілі), seconds, target.

const COLOR := Color(0.4, 1.0, 0.5)
const WINDUP := 0.6

var _target: Enemy3D

func _init() -> void:
	id = "dark_shield"
	cooldown = 7.0

func try_use(_distance: float) -> bool:
	_target = _find_target()
	if _target == null:
		return false
	start_cooldown()
	enemy.face_point(_target.global_position)
	enemy.begin_special(id, WINDUP, Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_alive():
		return
	var from := enemy.global_position + Vector3.UP * enemy.target_height * 0.6
	var to := _target.global_position + Vector3.UP * _target.target_height * 0.6
	var points: Array[Vector3] = [from, to]
	CombatVfx.lightning(world(), points, COLOR)
	_target.add_absorb(_target.max_hp * float(config.get("amount", 0.6)), float(config.get("seconds", 12.0)), COLOR)
	_target = null

func _find_target() -> Enemy3D:
	var tag := String(config.get("target", ""))
	var best: Enemy3D = null
	var best_distance := float(config.get("range", 10.0))
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or other == enemy or not other.is_alive() or other.has_absorb():
			continue
		if tag != "" and not String(other.definition.get("name", "")).contains(tag):
			continue
		var distance := other.global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best = other
			best_distance = distance
	return best
