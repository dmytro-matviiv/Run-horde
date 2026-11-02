# -*- coding: utf-8 -*-
"""Друга правка розкладки цитаделі: статуї парами обабіч входів, брили й
посеред зал, без розсипаної цегли й камінців."""
p = r"D:\Claude code\idle survivor_like\scenes\dungeon\dungeon_builder.gd"
s = open(p, encoding="utf-8").read()

OLD_LANDMARKS = s[s.index('\t# Статуї — посеред довгої північної стіни глибокої зали, обличчям до'):s.index('\t# Брили — попід прямою стіною зали')]
NEW_LANDMARKS = '''\t# Статуї — почесна варта обабіч входів у зали: прохід у північній стіні
\t# зали (не ширший за коридор), по статуї з кожного боку через клітинку від
\t# проходу, обличчям до гравця. Далі — посеред найдовших глухих північних
\t# стін. Не біля виходу й боса, не більше landmark.max на рівень.
\tvar landmark: Dictionary = decor.get("landmark", {})
\tvar chosen: Array[Vector2i] = []
\tif not landmark.is_empty():
\t\tvar keep_away: Array[Vector2i] = []
\t\tfor cell in marks:
\t\t\tif map_rows[cell.y][cell.x] != "S":
\t\t\t\tkeep_away.append(cell)
\t\tvar groups: Array[Array] = []
\t\tvar singles: Array[Dictionary] = []
\t\tfor z in map_rows.size():
\t\t\tvar row: String = map_rows[z]
\t\t\tvar x := 0
\t\t\twhile x < row.length():
\t\t\t\tif _wall_above_room(map_rows, corridor, Vector2i(x, z)):
\t\t\t\t\tvar start := x
\t\t\t\t\twhile x < row.length() and _wall_above_room(map_rows, corridor, Vector2i(x, z)):
\t\t\t\t\t\tx += 1
\t\t\t\t\tif x - start >= LANDMARK_MIN_RUN:
\t\t\t\t\t\tsingles.append({"cell": Vector2i(start + int((x - start) / 2.0), z), "length": x - start})
\t\t\t\t\tcontinue
\t\t\t\t# Прохід: клітинки зали, над якими теж прохідно, між глухими стінами.
\t\t\t\tif _is_walkable(map_rows, x, z) and not corridor.has(Vector2i(x, z)) and _is_walkable(map_rows, x, z - 1) \\
\t\t\t\t\t\tand _wall_above_room(map_rows, corridor, Vector2i(x - 1, z)):
\t\t\t\t\tvar door_start := x
\t\t\t\t\twhile x < row.length() and _is_walkable(map_rows, x, z) and _is_walkable(map_rows, x, z - 1):
\t\t\t\t\t\tx += 1
\t\t\t\t\tvar left := Vector2i(door_start - 2, z)
\t\t\t\t\tvar right := Vector2i(x + 1, z)
\t\t\t\t\tif x - door_start <= CORRIDOR_WIDTH and _wall_above_room(map_rows, corridor, left) \\
\t\t\t\t\t\t\tand _wall_above_room(map_rows, corridor, right) and _wall_above_room(map_rows, corridor, Vector2i(x, z)):
\t\t\t\t\t\tgroups.append([left, right])
\t\t\t\t\tcontinue
\t\t\t\tx += 1
\t\tsingles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.length > b.length)
\t\tfor single in singles:
\t\t\tgroups.append([single.cell])
\t\tvar limit := int(landmark.get("max", 4))
\t\tfor group in groups:
\t\t\tif chosen.size() + group.size() > limit:
\t\t\t\tcontinue
\t\t\tvar fits := true
\t\t\tfor cell: Vector2i in group:
\t\t\t\tif _near_any(cell, keep_away, LANDMARK_CLEAR) or _near_any(cell, chosen, LANDMARK_SPACING) \\
\t\t\t\t\t\tor not _landmark_room(map_rows, cell):
\t\t\t\t\tfits = false
\t\t\tif not fits:
\t\t\t\tcontinue
\t\t\tfor cell: Vector2i in group:
\t\t\t\tchosen.append(cell)
\t\t\t\tlayout.landmarks[cell] = true
\t\t\t\tfor dx in range(-1, 2):
\t\t\t\t\tlayout.occupied[cell + Vector2i(dx, 0)] = true
\t\t\t\tlayout.occupied[cell + Vector2i(0, 1)] = true

'''
s = s.replace(OLD_LANDMARKS, NEW_LANDMARKS)

reps = [
    # місце для статуї: сама клітинка й перед нею — вільні, решта — прохідна
    ('''## Чи гідне місце для статуї: перед нею вільна зала на LANDMARK_DEPTH
## клітинок углиб і по клітинці обабіч — без ворогів і предметів на мапі.
static func _landmark_room(map_rows: Array, cell: Vector2i) -> bool:
	for dz in LANDMARK_DEPTH:
		for dx in range(-1, 2):
			var c := cell + Vector2i(dx, dz)
			if not _is_walkable(map_rows, c.x, c.y) or map_rows[c.y][c.x] != ".":
				return false
	return true''',
     '''## Чи гідне місце для статуї: перед нею прохідна зала на LANDMARK_DEPTH
## клітинок углиб і по клітинці обабіч, а сама клітинка й та, що перед
## нею, — порожні (не мітка ворога).
static func _landmark_room(map_rows: Array, cell: Vector2i) -> bool:
	for dz in LANDMARK_DEPTH:
		for dx in range(-1, 2):
			if not _is_walkable(map_rows, cell.x + dx, cell.y + dz):
				return false
	return map_rows[cell.y][cell.x] == "." and map_rows[cell.y + 1][cell.x] == "."'''),
    ('''const LANDMARK_MIN_RUN := 7
const LANDMARK_DEPTH := 5
const LANDMARK_SPACING := 12
const LANDMARK_CLEAR := 6''', '''const LANDMARK_MIN_RUN := 7
const LANDMARK_DEPTH := 4
const LANDMARK_SPACING := 4
const LANDMARK_CLEAR := 4
## Брила посеред зали — лише там, де всі вісім сусідів прохідні.
const ROCK_INTERIOR_CHANCE := 0.025'''),
    # брили: також посеред великих зал
    ('''			var wall_side := Vector2i.ZERO
			var walls := 0
			for side in sides:
				if not _is_walkable(map_rows, cell.x + side.x, cell.y + side.y):
					wall_side = side
					walls += 1
			if walls != 1:
				continue
			layout.rocks[cell] = wall_side
			rocks.append(cell)''',
     '''			var wall_side := Vector2i.ZERO
			var walls := 0
			for side in sides:
				if not _is_walkable(map_rows, cell.x + side.x, cell.y + side.y):
					wall_side = side
					walls += 1
			if walls == 0:
				# Посеред зали — рідше й лише у великій залі (вісім прохідних
				# сусідів), щоб брила не перекрила прохід.
				if _count_open_neighbours(map_rows, cell) != 8 or _near_any(cell, entrances, 3) \\
						or _hash01(cell.x, cell.y, 54) >= ROCK_INTERIOR_CHANCE / float(rock.get("chance", 0.06)):
					continue
			elif walls != 1:
				continue
			layout.rocks[cell] = wall_side
			rocks.append(cell)'''),
    ('''	var rock: Dictionary = decor.rock
	var sizes: Vector2 = rock.get("scale", Vector2(0.4, 0.4))
	var size := lerpf(sizes.x, sizes.y, _hash01(cell.x, cell.y, 52))
	var yaw: float = _wall_directions()[wall_side] + (_hash01(cell.x, cell.y, 53) - 0.5) * deg_to_rad(30.0)''',
     '''	var rock: Dictionary = decor.rock
	var sizes: Vector2 = rock.get("scale", Vector2(0.4, 0.4))
	var size := lerpf(sizes.x, sizes.y, _hash01(cell.x, cell.y, 52))
	var yaw := (_hash01(cell.x, cell.y, 53) - 0.5) * deg_to_rad(30.0)
	if wall_side == Vector2i.ZERO:
		# Посеред зали — менша й лицем до камери.
		size *= 0.8
		yaw *= 1.6
	else:
		yaw += _wall_directions()[wall_side]'''),
    ('''		var box := Vector3(along, 3.5 * size, across) if wall_side.y != 0 else Vector3(across, 3.5 * size, along)''',
     '''		var box := Vector3(across, 3.5 * size, along) if wall_side.x != 0 else Vector3(along, 3.5 * size, across)'''),
    # без розсипаної цегли на плитах з розкладкою
    ('''	if rng.randf() < 0.08 and small_decor and not decor.has("floor_tiles"):''',
     '''	if rng.randf() < 0.08 and small_decor and not decor.has("floor_tiles") and not decor.has("floor_rules"):'''),
    # цитадель: без камінців, до чотирьох статуй
    ('''		"landmark": {"scene": ICE_KNIGHT_STATUE_SCENE, "scale": 1.55, "max": 3, "footprint": Vector2(1.5, 1.4)},
		"rock": {"scene": RUNE_ROCK_SCENE, "scale": Vector2(0.36, 0.46), "chance": 0.07},
		"stones": {"scene": SLATE_STONES_SCENE, "scale": Vector2(0.4, 0.55), "chance": 0.08},''',
     '''		"landmark": {"scene": ICE_KNIGHT_STATUE_SCENE, "scale": 1.55, "max": 4, "footprint": Vector2(1.5, 1.4)},
		"rock": {"scene": RUNE_ROCK_SCENE, "scale": Vector2(0.36, 0.46), "chance": 0.08},'''),
    ('''		## Статуя ~2.9 м (стіни — 2 м), не більше трьох на рівень.''',
     '''		## Статуя ~2.9 м (стіни — 2 м): парами обабіч входів у зали, не більше
		## чотирьох на рівень.'''),
]
for a, b in reps:
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)
# Камінці (slate_stones) у цитаделі більше не потрібні — модель і константу прибираємо.
s = s.replace('''const RUNE_ROCK_SCENE := preload("res://assets/models/citadel/rune_rock.glb")
const SLATE_STONES_SCENE := preload("res://assets/models/citadel/slate_stones.glb")''',
              '''const RUNE_ROCK_SCENE := preload("res://assets/models/citadel/rune_rock.glb")''')
s = s.replace('''## Рунна брила (набір гравця: 58 частин і 8 матеріалів злито в дві сітки з
## кольором у вершинах — звичайна й та, що світиться; 14.8 -> 3.9 тис.
## трикутників) і розсип сланцевих камінців з її підніжжя.''',
              '''## Рунна брила (каміння гравця: 58 частин і 8 матеріалів злито в дві сітки
## з кольором у вершинах — звичайна й та, що світиться; 14.8 -> 3.9 тис.
## трикутників, write_vertex_color_glb.py).''')
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
