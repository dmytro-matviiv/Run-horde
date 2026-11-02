# -*- coding: utf-8 -*-
"""Разова правка scenes/dungeon/dungeon_builder.gd: Крижана цитадель —
підлога за змістом (сніг по контуру, кристал під скринями й на входах,
руни посередині), статуї — рідкісні орієнтири, рунні брили й камінці."""
p = r"D:\Claude code\idle survivor_like\scenes\dungeon\dungeon_builder.gd"
s = open(p, encoding="utf-8").read()

OLD_CITADEL = s[s.index('\t## Крижана цитадель — уся на наборі гравця IceCitadel'):s.index('\t## Нижче — п\'ять нових тем')]
NEW_CITADEL = '''\t## Крижана цитадель — уся на арті гравця. Підлога розкладена за змістом
\t## (floor_rules, див. _build_layout): сніг — контуром уздовж стін, плита з
\t## кристалом — під скринями, на входах у коридори, перед статуями й зрідка
\t## посеред зали, рунна — решта. Колон немає: статуя лицаря — не прикраса,
\t## а рідкісний орієнтир на почесному місці (landmark), а попід стінами —
\t## рунні брили й розсип камінців.
\t"citadel": {
\t\t"floor_rules": {"main": ICE_FLOOR_RUNES, "edge": ICE_FLOOR_SNOW, "accent": ICE_FLOOR_GLOW},
\t\t"no_columns": true,
\t\t"wall_tiles": ICE_WALLS,
\t\t"wall_inset": 0.25,
\t\t## Факел замість звичайного: модель, масштаб, глибина кріплення
\t\t## (м, до масштабу) і висота низу над підлогою.
\t\t"torch": {"scene": ICE_TORCH_SCENE, "scale": 1.2, "depth": 0.269, "height": 0.85},
\t\t## Статуя ~2.9 м (стіни — 2 м), не більше трьох на рівень.
\t\t"landmark": {"scene": ICE_KNIGHT_STATUE_SCENE, "scale": 1.55, "max": 3, "footprint": Vector2(1.5, 1.4)},
\t\t"rock": {"scene": RUNE_ROCK_SCENE, "scale": Vector2(0.36, 0.46), "chance": 0.07},
\t\t"stones": {"scene": SLATE_STONES_SCENE, "scale": Vector2(0.4, 0.55), "chance": 0.08},
\t\t"chests": [preload("res://assets/models/dungeon/Chest_Gold.fbx"), preload("res://assets/models/dungeon/Chest.fbx")],
\t\t"chest_chance": 0.4,
\t\t"clutter": [preload("res://assets/models/dungeon/Vase.fbx"), preload("res://assets/models/dungeon/Skull.fbx")],
\t\t"clutter_chance": 0.08,
\t\t"wall": [],
\t\t"furniture": [],
\t\t"treasure": [preload("res://assets/models/dungeon/Chest_Gold.fbx"), preload("res://assets/models/dungeon/Chest.fbx")],
\t},
'''
s = s.replace(OLD_CITADEL, NEW_CITADEL)

LAYOUT_CODE = '''
# --- розкладка рівня за змістом (тема з "floor_rules") ---

## Тема з "floor_rules" розкладає рівень не навмання, а за будовою карти:
##   сніг ("edge")      — контур: кожна клітинка біля стіни, сніжним кутом
##                        до стіни (уздовж стіни — смугою);
##   кристал ("accent") — під скринями, на входах у коридори, під статуєю й
##                        перед нею, зрідка посеред зали;
##   руни ("main")      — решта, середина зал.
## Там же — скрині (внутрішні кути зал), статуї-орієнтири (кілька на рівень:
## посеред північної стіни найбільших зал, обличчям до гравця), рунні брили
## попід прямими стінами й розсип камінців. Рахується раз на карту (кеш за
## її вмістом) і однаково для вигляду (build_chunk), перешкод (build_base) і
## предметів (place_props) — нічого ні на що не налазить.
const CORRIDOR_WIDTH := 4
const LANDMARK_MIN_RUN := 7
const LANDMARK_DEPTH := 5
const LANDMARK_SPACING := 12
const LANDMARK_CLEAR := 6
const ACCENT_CHANCE := 0.025
const ROCK_PUSH := 0.15
static var _layouts: Dictionary = {}

static func _layout_for(map_rows: Array) -> Dictionary:
	return _layouts.get(map_rows.hash(), {})

static func _build_layout(map_rows: Array, decor: Dictionary) -> Dictionary:
	var key := map_rows.hash()
	if _layouts.has(key):
		return _layouts[key]
	var layout := {"floor": {}, "chests": {}, "landmarks": {}, "rocks": {}, "stones": {}, "occupied": {}}
	var sides: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var cells: Array[Vector2i] = []
	var marks: Array[Vector2i] = []
	for z in map_rows.size():
		var row: String = map_rows[z]
		for x in row.length():
			if not _is_walkable(map_rows, x, z):
				continue
			cells.append(Vector2i(x, z))
			if row[x] in ["S", "E", "B"]:
				marks.append(Vector2i(x, z))

	# Коридор — не ширше CORRIDOR_WIDTH поперек і довший уздовж; вхід —
	# його клітинка, що межує із залою.
	var corridor := {}
	for cell in cells:
		var rx := _run_length(map_rows, cell, Vector2i(1, 0))
		var rz := _run_length(map_rows, cell, Vector2i(0, 1))
		if (rx <= CORRIDOR_WIDTH and rz > CORRIDOR_WIDTH) or (rz <= CORRIDOR_WIDTH and rx > CORRIDOR_WIDTH):
			corridor[cell] = true
	var entrances: Array[Vector2i] = []
	for cell: Vector2i in corridor:
		for side in sides:
			var next := cell + side
			if _is_walkable(map_rows, next.x, next.y) and not corridor.has(next):
				entrances.append(cell)
				break

	# Скрині — у внутрішніх кутах зал (дві стіни під прямим кутом).
	var chest_chance: float = decor.get("chest_chance", 0.4)
	for cell in cells:
		if corridor.has(cell) or map_rows[cell.y][cell.x] != "." or _near_any(cell, marks, 4):
			continue
		var n := not _is_walkable(map_rows, cell.x, cell.y - 1)
		var s := not _is_walkable(map_rows, cell.x, cell.y + 1)
		var w := not _is_walkable(map_rows, cell.x - 1, cell.y)
		var e := not _is_walkable(map_rows, cell.x + 1, cell.y)
		if int(n) + int(s) + int(w) + int(e) == 2 and n != s and w != e \\
				and _hash01(cell.x, cell.y, 41) < chest_chance:
			layout.chests[cell] = Vector2i(-1 if w else 1, -1 if n else 1)

	# Статуї — посеред довгої північної стіни глибокої зали, обличчям до
	# камери; найдовші стіни першими, далеко від входу, виходу й боса.
	var landmark: Dictionary = decor.get("landmark", {})
	var chosen: Array[Vector2i] = []
	if not landmark.is_empty():
		var runs: Array[Dictionary] = []
		for z in map_rows.size():
			var row: String = map_rows[z]
			var x := 0
			while x < row.length():
				if not _wall_above_room(map_rows, corridor, Vector2i(x, z)):
					x += 1
					continue
				var start := x
				while x < row.length() and _wall_above_room(map_rows, corridor, Vector2i(x, z)):
					x += 1
				if x - start >= LANDMARK_MIN_RUN:
					runs.append({"cell": Vector2i(start + int((x - start) / 2.0), z), "length": x - start})
		runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.length > b.length)
		for run in runs:
			if chosen.size() >= int(landmark.get("max", 3)):
				break
			var cell: Vector2i = run.cell
			if _near_any(cell, marks, LANDMARK_CLEAR) or _near_any(cell, chosen, LANDMARK_SPACING):
				continue
			if not _landmark_room(map_rows, cell):
				continue
			chosen.append(cell)
			layout.landmarks[cell] = true
			for dx in range(-1, 2):
				layout.occupied[cell + Vector2i(dx, 0)] = true
			layout.occupied[cell + Vector2i(0, 1)] = true

	# Брили — попід прямою стіною зали (стіна рівно з одного боку), не
	# біля входів, скринь, статуй і одна від одної.
	var rock: Dictionary = decor.get("rock", {})
	var rocks: Array[Vector2i] = []
	if not rock.is_empty():
		for cell in cells:
			if corridor.has(cell) or layout.chests.has(cell) or map_rows[cell.y][cell.x] != ".":
				continue
			if _hash01(cell.x, cell.y, 51) >= float(rock.get("chance", 0.06)):
				continue
			if _near_any(cell, marks, 3) or _near_any(cell, chosen, 2) or _near_any(cell, entrances, 2) or _near_any(cell, rocks, 3):
				continue
			var wall_side := Vector2i.ZERO
			var walls := 0
			for side in sides:
				if not _is_walkable(map_rows, cell.x + side.x, cell.y + side.y):
					wall_side = side
					walls += 1
			if walls != 1:
				continue
			layout.rocks[cell] = wall_side
			rocks.append(cell)

	for cell: Vector2i in layout.chests:
		layout.occupied[cell] = true
	for cell: Vector2i in layout.rocks:
		layout.occupied[cell] = true

	# Камінці — будь-де, крім зайнятих клітинок і входів.
	var stones: Dictionary = decor.get("stones", {})
	if not stones.is_empty():
		for cell in cells:
			if not layout.occupied.has(cell) and not entrances.has(cell) \\
					and _hash01(cell.x, cell.y, 61) < float(stones.get("chance", 0.08)):
				layout.stones[cell] = true

	# Плити підлоги: [вид, поворот у чвертях оберту].
	for cell in cells:
		var kind := "main"
		var turn := floori(_hash01(cell.x, cell.y, 32) * 4.0)
		var edge := false
		for side in sides:
			if not _is_walkable(map_rows, cell.x + side.x, cell.y + side.y):
				edge = true
		if layout.chests.has(cell) or entrances.has(cell) or layout.landmarks.has(cell) \\
				or layout.landmarks.has(cell - Vector2i(0, 1)):
			kind = "accent"
		elif edge:
			kind = "edge"
			turn = _snow_turn(map_rows, cell)
		elif _hash01(cell.x, cell.y, 33) < ACCENT_CHANCE:
			kind = "accent"
		layout.floor[cell] = [kind, turn]
	_layouts[key] = layout
	return layout

## Клітинка зали (не коридор) з глухою стіною з півночі.
static func _wall_above_room(map_rows: Array, corridor: Dictionary, cell: Vector2i) -> bool:
	return _is_walkable(map_rows, cell.x, cell.y) and not corridor.has(cell) \\
		and not _is_walkable(map_rows, cell.x, cell.y - 1)

## Чи гідне місце для статуї: перед нею вільна зала на LANDMARK_DEPTH
## клітинок углиб і по клітинці обабіч — без ворогів і предметів на мапі.
static func _landmark_room(map_rows: Array, cell: Vector2i) -> bool:
	for dz in LANDMARK_DEPTH:
		for dx in range(-1, 2):
			var c := cell + Vector2i(dx, dz)
			if not _is_walkable(map_rows, c.x, c.y) or map_rows[c.y][c.x] != ".":
				return false
	return true

## Поворот снігової плити (у чвертях оберту). На плиті сніг лежить у двох
## протилежних кутах: при 0/2 — північно-східний і південно-західний, при
## 1/3 — північно-західний і південно-східний. Обираємо пару, де більше
## кутів упирається в стіну; порівну (пряма стіна, коридор) — чергуємо по
## клітинках, і сніжні кути сусідніх плит сходяться в смугу вздовж стіни.
static func _snow_turn(map_rows: Array, cell: Vector2i) -> int:
	var a := int(_corner_walled(map_rows, cell, 1, -1)) + int(_corner_walled(map_rows, cell, -1, 1))
	var b := int(_corner_walled(map_rows, cell, -1, -1)) + int(_corner_walled(map_rows, cell, 1, 1))
	var pattern := 0 if a > b else (1 if b > a else (cell.x + cell.y) % 2)
	return pattern + (2 if _hash01(cell.x, cell.y, 34) < 0.5 else 0)

static func _corner_walled(map_rows: Array, cell: Vector2i, dx: int, dz: int) -> bool:
	return not _is_walkable(map_rows, cell.x + dx, cell.y) or not _is_walkable(map_rows, cell.x, cell.y + dz) \\
		or not _is_walkable(map_rows, cell.x + dx, cell.y + dz)

## Перешкоди статуй і брил — тим самим тілом, що й стіни.
static func _add_layout_obstacles(obstacles: StaticBody3D, layout: Dictionary, decor: Dictionary) -> void:
	var landmark: Dictionary = decor.get("landmark", {})
	for cell: Vector2i in layout.landmarks:
		var footprint: Vector2 = landmark.get("footprint", Vector2(1.4, 1.4))
		_add_box_shape(obstacles, Vector3(cell.x * CELL, 1.5, cell.y * CELL), Vector3(footprint.x, 3.0, footprint.y))
	for cell: Vector2i in layout.rocks:
		var placement := _rock_placement(cell, layout.rocks[cell], decor)
		var size: float = placement.scale
		var wall_side: Vector2i = layout.rocks[cell]
		var along := 3.4 * size
		var across := 2.0 * size
		var box := Vector3(along, 3.5 * size, across) if wall_side.y != 0 else Vector3(across, 3.5 * size, along)
		_add_box_shape(obstacles, placement.position + Vector3(0, box.y * 0.5, 0), box)

## Де й як стоїть брила: лицем (рунами) від стіни в залу, трохи впритул
## до стіни, з невеликим розкидом повороту й розміру.
static func _rock_placement(cell: Vector2i, wall_side: Vector2i, decor: Dictionary) -> Dictionary:
	var rock: Dictionary = decor.rock
	var sizes: Vector2 = rock.get("scale", Vector2(0.4, 0.4))
	var size := lerpf(sizes.x, sizes.y, _hash01(cell.x, cell.y, 52))
	var yaw: float = _wall_directions()[wall_side] + (_hash01(cell.x, cell.y, 53) - 0.5) * deg_to_rad(30.0)
	var position := Vector3(cell.x * CELL, 0.0, cell.y * CELL) + Vector3(wall_side.x, 0.0, wall_side.y) * ROCK_PUSH
	return {"position": position, "yaw": yaw, "scale": size}

## Статуя, брила, скриня чи камінці на клітинці з розкладки. Повертає true,
## якщо клітинку зайнято — тоді випадкових прикрас на ній не ставимо.
static func _add_layout_items(batcher: MeshBatcher, layout: Dictionary, cell: Vector2i, position: Vector3, decor: Dictionary) -> bool:
	if layout.landmarks.has(cell):
		var landmark: Dictionary = decor.landmark
		var size: float = landmark.get("scale", 1.0)
		batcher.add(landmark.scene, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), position), Color.WHITE, true)
		return true
	if layout.rocks.has(cell):
		var placement := _rock_placement(cell, layout.rocks[cell], decor)
		var size: float = placement.scale
		var basis := Basis(Vector3.UP, placement.yaw).scaled(Vector3.ONE * size)
		batcher.add(decor.rock.scene, Transform3D(basis, placement.position), Color.WHITE, true)
		return true
	if layout.chests.has(cell):
		var corner: Vector2i = layout.chests[cell]
		var chests: Array = decor.get("chests", decor.treasure)
		var scene: PackedScene = chests[int(_hash01(cell.x, cell.y, 42) * chests.size()) % chests.size()]
		# Скриня в куті, лицем по діагоналі в залу.
		var yaw := atan2(-float(corner.x), -float(corner.y))
		batcher.add(scene, Transform3D(Basis(Vector3.UP, yaw), position + Vector3(corner.x, 0.0, corner.y) * 0.3))
		return true
	if layout.stones.has(cell):
		var stones: Dictionary = decor.stones
		var sizes: Vector2 = stones.get("scale", Vector2(0.5, 0.5))
		var size := lerpf(sizes.x, sizes.y, _hash01(cell.x, cell.y, 65))
		var offset := Vector3(_hash01(cell.x, cell.y, 62) - 0.5, 0.0, _hash01(cell.x, cell.y, 63) - 0.5) * 0.9
		var basis := Basis(Vector3.UP, _hash01(cell.x, cell.y, 64) * TAU).scaled(Vector3.ONE * size)
		batcher.add(stones.scene, Transform3D(basis, position + offset), Color.WHITE, true)
	return layout.occupied.has(cell)
'''

reps = [
    # константи: плити окремо, брила й камінці
    ('''const ICE_FLOORS := [
	[preload("res://assets/models/citadel/kit/floor_runes.glb"), 0.6],
	[preload("res://assets/models/citadel/kit/floor_snow.glb"), 0.3],
	[preload("res://assets/models/citadel/kit/floor_glow.glb"), 0.1],
]''', '''const ICE_FLOOR_RUNES := preload("res://assets/models/citadel/kit/floor_runes.glb")
const ICE_FLOOR_SNOW := preload("res://assets/models/citadel/kit/floor_snow.glb")
const ICE_FLOOR_GLOW := preload("res://assets/models/citadel/kit/floor_glow.glb")'''),
    ('''const ICE_TORCH_SCENE := preload("res://assets/models/citadel/ice_torch.glb")''',
     '''const ICE_TORCH_SCENE := preload("res://assets/models/citadel/ice_torch.glb")
## Рунна брила (набір гравця: 58 частин і 8 матеріалів злито в дві сітки з
## кольором у вершинах — звичайна й та, що світиться; 14.8 -> 3.9 тис.
## трикутників) і розсип сланцевих камінців з її підніжжя.
const RUNE_ROCK_SCENE := preload("res://assets/models/citadel/rune_rock.glb")
const SLATE_STONES_SCENE := preload("res://assets/models/citadel/slate_stones.glb")'''),
    # прогрів: словники без "scene" — усі значення
    ('''	if value is Dictionary:
		return _scenes_in((value as Dictionary).get("scene"))''',
     '''	if value is Dictionary:
		var dict := value as Dictionary
		return _scenes_in(dict.scene) if dict.has("scene") else _scenes_in(dict.values())'''),
    # основа рівня: розкладка й перешкоди; колон немає
    ('''	_add_column_obstacles(obstacles, map_rows, decor)''',
     '''	if not decor.get("no_columns", false):
		_add_column_obstacles(obstacles, map_rows, decor)
	if decor.has("floor_rules"):
		_add_layout_obstacles(obstacles, _build_layout(map_rows, decor), decor)'''),
    # предмети оминають зайняте розкладкою
    ('''	var result := {"barrels": [], "trap_lines": [], "shrines": [], "reserved": {}}
	var reserved: Dictionary = result.reserved''',
     '''	var result := {"barrels": [], "trap_lines": [], "shrines": [], "reserved": {}}
	var reserved: Dictionary = result.reserved
	# Статуї, брили й скрині з розкладки рівня (build_base уже порахував).
	for cell: Vector2i in _layout_for(map_rows).get("occupied", {}):
		reserved[cell] = true'''),
    # шматок
    ('''	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917 + rect.position.x * 73856093 + rect.position.y * 19349663
''', '''	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917 + rect.position.x * 73856093 + rect.position.y * 19349663
	var layout: Dictionary = _build_layout(map_rows, decor) if decor.has("floor_rules") else {}
'''),
    ('''			_add_floor(batcher, x, z, position, floor_color, decor)
			if _is_column_cell(map_rows, row, x, z):''',
     '''			var cell := Vector2i(x, z)
			_add_floor(batcher, x, z, position, floor_color, decor, layout)
			if not decor.get("no_columns", false) and _is_column_cell(map_rows, row, x, z):'''),
    ('''			_add_wall_visuals(batcher, map_rows, x, z, position, decor_density, stone, decor)
			if not reserved.has(Vector2i(x, z)):
				_decorate_cell(batcher, map_rows, x, z, position, rng, decor_density, decor)''',
     '''			_add_wall_visuals(batcher, map_rows, x, z, position, decor_density, stone, decor)
			if not layout.is_empty() and _add_layout_items(batcher, layout, cell, position, decor):
				continue
			if not reserved.has(cell):
				_decorate_cell(batcher, map_rows, x, z, position, rng, decor_density, decor)'''),
    # плитка за розкладкою
    ('''static func _add_floor(batcher: MeshBatcher, x: int, z: int, position: Vector3, floor_color: Color, decor: Dictionary) -> void:
	if not decor.has("floor_tiles"):''',
     '''##
## Тема з "floor_rules" — плита за розкладкою рівня (_build_layout).
static func _add_floor(batcher: MeshBatcher, x: int, z: int, position: Vector3, floor_color: Color, decor: Dictionary, layout: Dictionary = {}) -> void:
	if decor.has("floor_rules"):
		var entry: Array = layout.get("floor", {}).get(Vector2i(x, z), ["main", 0])
		var tile: PackedScene = decor.floor_rules[entry[0]]
		batcher.add(tile, Transform3D(Basis(Vector3.UP, entry[1] * PI * 0.5), position), Color.WHITE, true)
		return
	if not decor.has("floor_tiles"):'''),
    # факел не за статуєю
    ('''		if (x + z) % TORCH_EVERY == 0 and offset.y != 0:
			if decor.has("torch"):''',
     '''		if (x + z) % TORCH_EVERY == 0 and offset.y != 0 \\
				and not _layout_for(map_rows).get("landmarks", {}).has(Vector2i(x, z)):
			if decor.has("torch"):'''),
    # випадкові скарби — не для теми з розкладкою (там скрині в кутах)
    ('''	if open_sides == 2 and rng.randf() < 0.26:''',
     '''	if open_sides == 2 and rng.randf() < 0.26 and not decor.has("floor_rules"):'''),
    ('''# --- шматки ---''', LAYOUT_CODE.strip('\n') + '\n\n# --- шматки ---'),
]
for a, b in reps:
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
