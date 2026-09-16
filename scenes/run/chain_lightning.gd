extends Node2D

## Ланцюгова блискавка: миттєво знаходить ланцюжок цілей (кожна
## наступна — найближча до попередньої, повторно в ланцюг не
## потрапляє), б'є їх усіх і малює ламану лінію між ними, яка згасає.

const FADE_TIME := 0.3

var _points := PackedVector2Array()
var _color := Color(0.6, 0.85, 1)
var _elapsed := 0.0

## Повертає, скільки ворогів зачепив ланцюг.
func strike(from_position: Vector2, first_target: Node2D, def: WeaponDef, damage: float) -> int:
	_color = def.color
	_points = PackedVector2Array([from_position])
	var hit_enemies: Array = []
	var current := first_target
	while current != null and hit_enemies.size() < def.chain_targets:
		hit_enemies.append(current)
		_points.append(current.global_position)
		CombatQuery.hit(current, damage, def.status, def.status_power, def.status_duration)
		current = CombatQuery.nearest_enemy(get_tree(), current.global_position, def.chain_range, hit_enemies)
	queue_redraw()
	return hit_enemies.size()

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= FADE_TIME:
		queue_free()

func _draw() -> void:
	if _points.size() < 2:
		return
	var color := _color
	color.a = 1.0 - clampf(_elapsed / FADE_TIME, 0.0, 1.0)
	# Лінія малюється у власних координатах вузла, а точки зібрані у
	# світових — тому віднімаємо позицію вузла.
	for i in _points.size() - 1:
		draw_line(_points[i] - global_position, _points[i + 1] - global_position, color, 3.0)
