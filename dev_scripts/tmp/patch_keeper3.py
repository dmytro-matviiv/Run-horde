# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"
BS = chr(92)


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/enemy_3d.gd", [
    ('''func _add_health_bar() -> void:
	_health_bar = HEALTH_BAR_SCRIPT.new()''', '''func _add_health_bar() -> void:
	# У боса смуга внизу екрана (Dungeon._build_boss_bar) — над головою зайва.
	if kind == Kind.BOSS:
		return
	_health_bar = HEALTH_BAR_SCRIPT.new()'''),
    ('''static func make_stun_stars() -> Node3D:''', '''## Чи вільне місце під ворога: немає стін, колон, меблів, саркофагів
## (шар 1) у колі radius на висоті пояса.
static func is_spot_clear(world: World3D, spot: Vector3, radius: float = 0.45) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), Vector3(spot.x, DungeonBuilder.FLOOR_TOP + 0.7, spot.z))
	query.collision_mask = 1
	return world.direct_space_state.intersect_shape(query, 1).is_empty()

static func make_stun_stars() -> Node3D:'''),
])

patch("scenes/dungeon/boss_phases.gd", [
    ('''	while phase - 1 < thresholds.size() and ratio <= thresholds[phase - 1]:''',
     '''	# Запас на округлення: здоров'я, зупинене рівно на порозі ("phase_lock"),
	# мусить відкрити фазу, інакше бос лишався б невразливим назавжди.
	while phase - 1 < thresholds.size() and ratio <= float(thresholds[phase - 1]) + 0.001:'''),
])

patch("scenes/dungeon/dungeon.gd", [
    ('''	enemies_root.add_child(enemy)
	enemy.global_position = position + Vector3(0, 0.2, 0)''', '''	enemies_root.add_child(enemy)
	enemy.global_position = _clear_spot(position) + Vector3(0, 0.2, 0)'''),
    ('''## Бос перейшов у нову фазу — великий напис.''', '''## Вільне місце для ворога поруч із бажаним: стіл, саркофаг чи колона на
## місці появи — шукаємо найближче вільне по колах довкола.
func _clear_spot(position: Vector3) -> Vector3:
	var world := get_world_3d()
	if Enemy3D.is_spot_clear(world, position):
		return position
	for ring in [0.9, 1.6, 2.4, 3.2]:
		for i in 8:
			var angle := TAU * i / 8.0
			var spot := position + Vector3(cos(angle), 0.0, sin(angle)) * ring
			var cell := DungeonBuilder.cell_of(spot)
			if DungeonBuilder.is_walkable(_map_rows, cell.x, cell.y) and Enemy3D.is_spot_clear(world, spot):
				return spot
	return position

## Бос перейшов у нову фазу — великий напис.'''),
])

patch("scenes/dungeon/abilities/phase_step_ability.gd", [
    ('''		var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP, spot + Vector3.UP, 1)
		if not space.intersect_ray(query).is_empty():
			continue''', '''		var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP, spot + Vector3.UP, 1)
		if not space.intersect_ray(query).is_empty():
			continue
		# Не на стіл і не в колону — там чаклун застряг би.
		if not Enemy3D.is_spot_clear(enemy.get_world_3d(), spot):
			continue'''),
])

patch("scenes/dungeon/dungeon_builder.gd", [
    ('''static func portal_wall(map_rows: Array, start: Vector2i, skip: Vector3 = Vector3.ZERO) -> Dictionary:''',
     '''## room_only — лише стіна самої зали: клітинка перед стіною не в
## коридорі (уздовж і впоперек щонайменше 3 прохідні клітинки).
static func portal_wall(map_rows: Array, start: Vector2i, skip: Vector3 = Vector3.ZERO, room_only: bool = false) -> Dictionary:'''),
    ('''			if steps >= MAX_STEPS:
				continue
			var wall := cell + dir''', '''			if steps >= MAX_STEPS:
				continue
			if room_only and (_run_length(map_rows, cell, Vector2i(1, 0)) < 3 or _run_length(map_rows, cell, Vector2i(0, 1)) < 3):
				continue
			var wall := cell + dir'''),
])
print("patched")
