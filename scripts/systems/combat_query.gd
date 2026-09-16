extends RefCounted
class_name CombatQuery

## Спільні "запити по площі" для всієї нової зброї: знайти ворогів у
## колі або в конусі й завдати їм шкоди зі статус-ефектом. Раніше вся
## шкода йшла лише від зіткнення снаряда з тілом ворога — для вибухів,
## вогнемета й замаху сокири цього замало, бо їм треба вдарити всіх у
## зоні одразу, не створюючи снарядів.
##
## Працюємо напряму з фізичним простором (intersect_shape), тому
## удар зараховується в той самий кадр — без очікування сигналів
## area_entered і без зайвих вузлів на сцені.

const ENEMY_LAYER_MASK := 4   # шар 3 "enemies"
const MAX_HITS := 64

## Усі живі вороги в колі radius навколо center.
static func enemies_in_circle(world: World2D, center: Vector2, radius: float) -> Array:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = ENEMY_LAYER_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result: Array = []
	for hit in world.direct_space_state.intersect_shape(query, MAX_HITS):
		var body: Variant = hit.get("collider")
		if body is Node2D and body.has_method("take_damage") and body.visible:
			result.append(body)
	return result

## Вороги в секторі: спершу коло, потім відсіюємо тих, хто поза кутом.
## half_angle_deg — половина розкриття конуса (70° конус = 35°).
static func enemies_in_cone(world: World2D, center: Vector2, radius: float, direction: Vector2, full_angle_deg: float) -> Array:
	var half_angle := deg_to_rad(full_angle_deg) * 0.5
	var result: Array = []
	for enemy: Node2D in enemies_in_circle(world, center, radius):
		var to_enemy := center.direction_to(enemy.global_position)
		if absf(direction.angle_to(to_enemy)) <= half_angle:
			result.append(enemy)
	return result

## Шкода + статус-ефект одному ворогу. status може бути порожнім.
static func hit(enemy: Node, damage: float, status: StringName = &"", power: float = 0.0, duration: float = 0.0) -> void:
	if status != &"" and enemy.has_method("apply_status"):
		enemy.apply_status(status, power, duration)
	enemy.take_damage(damage)

## Шкода всім у списку (результат enemies_in_circle/enemies_in_cone).
static func hit_all(enemies: Array, damage: float, status: StringName = &"", power: float = 0.0, duration: float = 0.0) -> int:
	for enemy in enemies:
		hit(enemy, damage, status, power, duration)
	return enemies.size()

## Найближчий ворог до точки, крім тих, що вже в exclude.
static func nearest_enemy(tree: SceneTree, from: Vector2, max_distance: float, exclude: Array = []) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := max_distance * max_distance
	for enemy: Node2D in tree.get_nodes_in_group("enemies"):
		if not enemy.visible or exclude.has(enemy):
			continue
		var distance := from.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest
