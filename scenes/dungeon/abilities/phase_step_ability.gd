extends EnemyAbility

## ТЕЛЕПОРТ (Склепний чаклун): отримавши шкоду, розсипається зеленим
## димом і за мить виникає в іншому місці тієї ж зали — раз на cooldown
## секунд. Місце — distance метрів від себе, у прямій видимості (та сама
## зала), не впритул до героя.

const SMOKE := Color(0.45, 1.0, 0.5)
const FADE := 0.35
const MIN_FROM_HERO := 4.0

var _busy := false

func _init() -> void:
	id = "phase_step"
	cooldown = 10.0

func is_busy() -> bool:
	return _busy

func on_damaged() -> void:
	if _busy or not ready_to_use() or not enemy.is_alive():
		return
	var spot := _pick_spot()
	if spot == Vector3.INF:
		return
	start_cooldown()
	_busy = true
	CombatVfx.impact(world(), enemy.global_position + Vector3.UP, SMOKE, true)
	CombatVfx.shockwave(world(), enemy.global_position, 1.4, SMOKE, 0.3)
	enemy.set_hidden(true)
	var tween := enemy.create_tween()
	tween.tween_interval(FADE)
	tween.tween_callback(func() -> void:
		enemy.teleport_to(spot)
		enemy.set_hidden(false)
		CombatVfx.impact(world(), spot + Vector3.UP, SMOKE, true)
		CombatVfx.shockwave(world(), spot, 1.4, SMOKE, 0.3)
		_busy = false)

func _pick_spot() -> Vector3:
	var space := enemy.get_world_3d().direct_space_state
	var from := enemy.global_position
	var map_rows: Array = DungeonLevels.get_level(GameState.dungeon_level).map
	var hero := player()
	var low := float(config.get("min", 5.0))
	var high := float(config.get("max", 8.0))
	for attempt in 14:
		var angle := randf() * TAU
		var spot := from + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(low, high)
		var cell := DungeonBuilder.cell_of(spot)
		if not DungeonBuilder.is_walkable(map_rows, cell.x, cell.y):
			continue
		if hero != null and spot.distance_to(hero.global_position) < MIN_FROM_HERO:
			continue
		var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP, spot + Vector3.UP, 1)
		if not space.intersect_ray(query).is_empty():
			continue
		return Vector3(spot.x, from.y, spot.z)
	return Vector3.INF
