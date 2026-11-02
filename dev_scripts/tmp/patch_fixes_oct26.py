# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


# 1. Каст переривають лише суперздібності (не зброя), босів — ніщо.
patch("scenes/dungeon/enemy_3d.gd", [
    ('''	if heavy or not is_boss:
		if heavy:
			_cancel_windup()
		_stagger_left = maxf(_stagger_left, (0.45 if heavy else 0.15) * (0.5 if is_boss else 1.0))

	if _windup_left <= 0.0 and not _wall_stunned:''', '''	# Замах (каст) збиває лише суперздібність героя (не удар зброєю), і лише
	# звичайного ворога: бос свій прийом доводить до кінця. Поки ворог
	# замахується, удари його не спиняють і не "смикають".
	var by_skill := String(last_hit_source) != "" and String(last_hit_source) != "weapon"
	if by_skill and kind != Kind.BOSS and _windup_left > 0.0:
		_cancel_windup()
	if (heavy or not is_boss) and _windup_left <= 0.0:
		_stagger_left = maxf(_stagger_left, (0.45 if heavy else 0.15) * (0.5 if is_boss else 1.0))
	last_hit_source = &""

	if _windup_left <= 0.0 and not _wall_stunned:'''),
])

# 2. Камера не виходить за краї карти.
patch("scenes/world/camera_rig.gd", [
    ('''var _target: Node3D
''', '''var _target: Node3D
## Межі, у яких ходить сама камера (данж): біля краю карти герой іде далі,
## а камера стоїть — за краєм видно не порожнечу. Rect2 у метрах (x, z).
var _bounds := Rect2()
'''),
    ('''## Нахил камери вгору-вниз тим самим пальцем.''', '''## Межі камери на площині (x, z). Порожній Rect2 — без меж.
func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds

## Нахил камери вгору-вниз тим самим пальцем.'''),
    ('''	var wanted := _target.global_position + Vector3.UP * HEIGHT_OFFSET
	# lerp''', '''	var wanted := _target.global_position + Vector3.UP * HEIGHT_OFFSET
	if _bounds.size != Vector2.ZERO:
		wanted.x = clampf(wanted.x, _bounds.position.x, _bounds.end.x)
		wanted.z = clampf(wanted.z, _bounds.position.y, _bounds.end.y)
	# lerp'''),
    ('''func snap_to_target() -> void:
	if _target != null:
		global_position = _target.global_position + Vector3.UP * HEIGHT_OFFSET''', '''func snap_to_target() -> void:
	if _target != null:
		global_position = _target.global_position + Vector3.UP * HEIGHT_OFFSET
		if _bounds.size != Vector2.ZERO:
			global_position.x = clampf(global_position.x, _bounds.position.x, _bounds.end.x)
			global_position.z = clampf(global_position.z, _bounds.position.y, _bounds.end.y)'''),
])

patch("scenes/dungeon/dungeon.gd", [
    ('''	$CameraRig.set_world_collision(false)''', '''	$CameraRig.set_world_collision(false)
	$CameraRig.set_bounds(_camera_bounds())'''),
    ('''## Вільне місце для ворога поруч із бажаним''', '''## Межі камери: прохідна частина карти, звужена на CAMERA_EDGE з кожного
## боку (ближче до краю камера не йде — за ним не видно порожнечі). Вузька
## карта — камера стоїть посередині.
const CAMERA_EDGE := 6.0

func _camera_bounds() -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for z in _map_rows.size():
		var row: String = _map_rows[z]
		for x in row.length():
			if DungeonBuilder.is_walkable(_map_rows, x, z):
				var p := Vector2(x, z) * DungeonBuilder.CELL
				low = Vector2(minf(low.x, p.x), minf(low.y, p.y))
				high = Vector2(maxf(high.x, p.x), maxf(high.y, p.y))
	if low.x == INF:
		return Rect2()
	var center := (low + high) * 0.5
	var lo := Vector2(minf(low.x + CAMERA_EDGE, center.x), minf(low.y + CAMERA_EDGE, center.y))
	var hi := Vector2(maxf(high.x - CAMERA_EDGE, center.x), maxf(high.y - CAMERA_EDGE, center.y))
	return Rect2(lo, hi - lo + Vector2(0.01, 0.01))

## Вільне місце для ворога поруч із бажаним'''),
    # 4. У залі боса — лише бос.
    ('''	for spawn: Dictionary in markers.spawns:
		var arena_index := _arena_at(DungeonBuilder.cell_of(spawn.position))''', '''	var boss_room := DungeonBuilder.boss_room(_map_rows)
	for spawn: Dictionary in markers.spawns:
		# У залі боса — лише бос (і ті, кого він кличе сам).
		if boss_room.has(DungeonBuilder.cell_of(spawn.position)):
			continue
		var arena_index := _arena_at(DungeonBuilder.cell_of(spawn.position))'''),
    ('''	for spot in DungeonBuilder.sentinel_spots(_map_rows):
		_spawn_enemy(spot, definition, false)''', '''	var boss_room := DungeonBuilder.boss_room(_map_rows)
	for spot in DungeonBuilder.sentinel_spots(_map_rows):
		if not boss_room.has(DungeonBuilder.cell_of(spot)):
			_spawn_enemy(spot, definition, false)'''),
])

patch("scenes/dungeon/dungeon_builder.gd", [
    ('''## Де замість статуй стоять Ожилі вартові''', '''## Клітинки зали боса: від мітки "B" заливкою по залі — лише клітинки, де
## уздовж і впоперек щонайменше 3 прохідні (коридори зупиняють заливку).
static func boss_room(map_rows: Array) -> Dictionary:
	var start := Vector2i(-1, -1)
	for z in map_rows.size():
		var x := String(map_rows[z]).find("B")
		if x >= 0:
			start = Vector2i(x, z)
	var room := {}
	if start.x < 0:
		return room
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if room.has(cell) or not _is_walkable(map_rows, cell.x, cell.y):
			continue
		if cell != start and (_run_length(map_rows, cell, Vector2i(1, 0)) < 3 or _run_length(map_rows, cell, Vector2i(0, 1)) < 3):
			continue
		room[cell] = true
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(cell + step)
	return room

## Де замість статуй стоять Ожилі вартові'''),
])
print("patched")
