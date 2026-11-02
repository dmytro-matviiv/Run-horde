# -*- coding: utf-8 -*-
"""Разова правка scenes/dungeon/dungeon_builder.gd: Грибні нетрі — на
наборі гравця (DungeonKit): своя підлога, стіни, колони, уламки."""
p = r"D:\Claude code\idle survivor_like\scenes\dungeon\dungeon_builder.gd"
s = open(p, encoding="utf-8").read()

OLD_FUNGAL = s[s.index('\t"fungal": {'):s.index('\t## Потонулі сади')]
NEW_FUNGAL = '''\t## Грибні нетрі — своя архітектура з набору гравця (DungeonKit,
\t## assets/models/fungal/kit, легкі версії — process_dungeon_kit.py):
\t## моховита кладка з корінням і слизом, плити з тріщинами, що світяться,
\t## у залах — то гриб-велетень, то колона з набору. Нічого з першого данжу,
\t## крім павутиння, черепів і скарбів. Свій арт не фарбується під камінь.
\t"fungal": {
\t\t"keep_colors": true,
\t\t"floor_tiles": FUNGAL_FLOORS,
\t\t"wall_tiles": FUNGAL_WALLS,
\t\t## Лице стіни набору — на 0.25 м усередині клітинки (а не на межі).
\t\t"wall_inset": 0.25,
\t\t"columns": [
\t\t\t## Шапка ~2.5 м завширшки — перешкода ширша, щоб під шапкою не
\t\t\t## ховались від камери згори.
\t\t\t{"scene": MUSHROOM_GIANT_SCENE, "scale": 1.25, "obstacle": 1.8, "weight": 0.6},
\t\t\t{"scene": FUNGAL_COLUMN_SCENE, "scale": 1.0, "obstacle": 0.8, "weight": 0.4},
\t\t],
\t\t"cover": MUSHROOM_GIANT_SCENE,
\t\t"cover_scale": Vector2(0.26, 0.42),
\t\t"clutter": [preload("res://assets/models/dungeon/Skull.fbx")],
\t\t"wall": [preload("res://assets/models/dungeon/Cobweb.fbx"), preload("res://assets/models/dungeon/Cobweb2.fbx")],
\t\t"furniture": [FUNGAL_RUBBLE_SCENE],
\t\t"treasure": [preload("res://assets/models/dungeon/Coin_Pile.fbx"), preload("res://assets/models/dungeon/Bag_Coins.fbx")],
\t},
'''
s = s.replace(OLD_FUNGAL, NEW_FUNGAL)

reps = [
    ('''## Частка клітинок попід стінами з грибочками й їхній розмір (від гриба-колони).
const COVER_CHANCE := 0.16
''', '''## Частка клітинок попід стінами з грибочками й їхній розмір (від гриба-колони).
const COVER_CHANCE := 0.16
## Набір гравця для Грибних нетрів (DungeonKit, уже під клітинку 2 м).
## Плитки підлоги — [модель, частка]: звичайна, з корінням, світна тріщина.
const FUNGAL_FLOORS := [
	[preload("res://assets/models/fungal/kit/floor_plain.glb"), 0.6],
	[preload("res://assets/models/fungal/kit/floor_roots.glb"), 0.3],
	[preload("res://assets/models/fungal/kit/floor_glow.glb"), 0.1],
]
const FUNGAL_WALLS := [
	preload("res://assets/models/fungal/kit/wall_plain.glb"), preload("res://assets/models/fungal/kit/wall_plain2.glb"),
	preload("res://assets/models/fungal/kit/wall_moss.glb"), preload("res://assets/models/fungal/kit/wall_moss2.glb"),
	preload("res://assets/models/fungal/kit/wall_roots.glb"), preload("res://assets/models/fungal/kit/wall_roots2.glb"),
	preload("res://assets/models/fungal/kit/wall_shrooms.glb"), preload("res://assets/models/fungal/kit/wall_crack.glb"),
]
const FUNGAL_COLUMN_SCENE := preload("res://assets/models/fungal/kit/column.glb")
const FUNGAL_RUBBLE_SCENE := preload("res://assets/models/fungal/kit/rubble.glb")
'''),
    # прогрів графіки: групи можуть бути й списками пар / описами колон
    ('''			var value: Variant = DECOR_SETS[set_name][group]
			var group_scenes: Array = value if value is Array else ([value] if value is PackedScene else [])
			for scene: PackedScene in group_scenes:
				if not scenes.has(scene):
					scenes.append(scene)''', '''			for scene in _scenes_in(DECOR_SETS[set_name][group]):
				if not scenes.has(scene):
					scenes.append(scene)'''),
    ('''## Символи, по яких можна ходити''', '''## Усі моделі в групі набору прикрас: список моделей, окрема модель,
## пари [модель, частка] (плитки) чи описи {"scene": ...} (колони).
## Числа й інші значення (масштаб) — пропускаємо.
static func _scenes_in(value: Variant) -> Array:
	if value is PackedScene:
		return [value]
	if value is Dictionary:
		return _scenes_in((value as Dictionary).get("scene"))
	var found: Array = []
	if value is Array:
		for item: Variant in value:
			found.append_array(_scenes_in(item))
	return found

## Символи, по яких можна ходити'''),
    ('''	_add_column_obstacles(obstacles, map_rows, decor.get("column_obstacle", 1.1))''',
     '''	_add_column_obstacles(obstacles, map_rows, decor)'''),
    ('''## width — ширина перешкоди: кам'яна колона 1.1 м, гриб-колона ширший —
## під шапку не підійти впритул (згори героя під нею не видно).
static func _add_column_obstacles(obstacles: StaticBody3D, map_rows: Array, width: float = 1.1) -> void:
	for z in range(1, map_rows.size() - 1):
		var row: String = map_rows[z]
		for x in range(1, row.length() - 1):
			if _is_column_cell(map_rows, row, x, z):
				_add_box_shape(obstacles, Vector3(x * CELL, 2.0, z * CELL), Vector3(width, 4.0, width))''',
     '''## Ширина перешкоди — від моделі колони на цій клітинці (_column_variant):
## кам'яна колона 1.1 м, гриб ширший — під шапку не підійти впритул.
static func _add_column_obstacles(obstacles: StaticBody3D, map_rows: Array, decor: Dictionary) -> void:
	for z in range(1, map_rows.size() - 1):
		var row: String = map_rows[z]
		for x in range(1, row.length() - 1):
			if _is_column_cell(map_rows, row, x, z):
				var width: float = _column_variant(decor, x, z).get("obstacle", 1.1)
				_add_box_shape(obstacles, Vector3(x * CELL, 2.0, z * CELL), Vector3(width, 4.0, width))

## Яка колона стоїть на клітинці (x, z): з набору теми "columns" за
## частками й координатами — однаково для моделі й для перешкоди. Немає
## набору — звичайна кам'яна колона.
static func _column_variant(decor: Dictionary, x: int, z: int) -> Dictionary:
	var variants: Array = decor.get("columns", [])
	if variants.is_empty():
		return {"scene": COLUMN_SCENE, "obstacle": 1.1}
	var roll := _hash01(x, z, 21)
	for variant: Dictionary in variants:
		roll -= variant.get("weight", 1.0 / variants.size())
		if roll < 0.0:
			return variant
	return variants[-1]'''),
    ('''			batcher.add(FLOOR_SCENE, Transform3D(Basis(), position), floor_color)''',
     '''			_add_floor(batcher, x, z, position, floor_color, decor)'''),
    ('''static func _add_wall_visuals(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, decor_density: float, stone: Color, decor: Dictionary) -> void:
	var directions := _wall_directions()
	for offset: Vector2i in directions:
		if _is_walkable(map_rows, x + offset.x, z + offset.y):
			continue
		var wall_position := position + Vector3(offset.x, 0.0, offset.y) * CELL * 0.5
		wall_position.y = WALL_HEIGHT * 0.5
		batcher.add(WALL_SCENE, Transform3D(Basis(Vector3.UP, directions[offset]), wall_position), stone)
''', '''## Плитка підлоги. Тема з набором плиток ("floor_tiles") — випадкова
## плитка за частками, повернута на 0/90/180/270° (три малюнки дають
## дванадцять), у власних кольорах; інакше — звичайна плита в кольорі рівня.
static func _add_floor(batcher: MeshBatcher, x: int, z: int, position: Vector3, floor_color: Color, decor: Dictionary) -> void:
	if not decor.has("floor_tiles"):
		batcher.add(FLOOR_SCENE, Transform3D(Basis(), position), floor_color)
		return
	var tiles: Array = decor.floor_tiles
	var tile: PackedScene = tiles[-1][0]
	var roll := _hash01(x, z, 31)
	for entry: Array in tiles:
		roll -= entry[1]
		if roll < 0.0:
			tile = entry[0]
			break
	var turn := floorf(_hash01(x, z, 32) * 4.0) * PI * 0.5
	batcher.add(tile, Transform3D(Basis(Vector3.UP, turn), position), Color.WHITE, true)

static func _add_wall_visuals(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, decor_density: float, stone: Color, decor: Dictionary) -> void:
	var directions := _wall_directions()
	var keep_colors: bool = decor.get("keep_colors", false)
	# Лице стіни від межі клітинки: у звичайних стінах 0 (стіна на межі), у
	# набору гравця — усередині клітинки. Факел і прикраси — перед лицем.
	var inset: float = decor.get("wall_inset", 0.0)
	for offset: Vector2i in directions:
		if _is_walkable(map_rows, x + offset.x, z + offset.y):
			continue
		var wall_position := position + Vector3(offset.x, 0.0, offset.y) * CELL * 0.5
		wall_position.y = WALL_HEIGHT * 0.5
		if decor.has("wall_tiles"):
			# Стіна набору: центр — у клітинці, панель — уздовж краю, до
			# якого її повернуто. Вісім малюнків упереміш, повтор не читається.
			var tiles: Array = decor.wall_tiles
			var tile: PackedScene = tiles[int(_hash01(x * 3 + offset.x, z * 3 + offset.y, 33) * tiles.size()) % tiles.size()]
			batcher.add(tile, Transform3D(Basis(Vector3.UP, directions[offset]), position), Color.WHITE, true)
		else:
			batcher.add(WALL_SCENE, Transform3D(Basis(Vector3.UP, directions[offset]), wall_position), stone)
'''),
    ('''			var torch_position := wall_position - Vector3(offset.x, 0.0, offset.y) * 0.35 + Vector3(0, 0.6, 0)''',
     '''			var torch_position := wall_position - Vector3(offset.x, 0.0, offset.y) * maxf(0.35, inset + 0.1) + Vector3(0, 0.6, 0)'''),
    ('''			var decor_position := position + Vector3(0, 1.3, 0) \\
				+ Vector3(offset.x, 0.0, offset.y) * (CELL * 0.5 - 0.15)
			var wall_set: Array = decor.wall
			var ornament: PackedScene = wall_set[(x * 7 + z * 13 + offset.x + offset.y) % wall_set.size()]
			batcher.add(ornament, Transform3D(Basis(Vector3.UP, directions[offset]), decor_position))''',
     '''			var decor_position := position + Vector3(0, 1.3, 0) \\
				+ Vector3(offset.x, 0.0, offset.y) * (CELL * 0.5 - maxf(0.15, inset + 0.03))
			var wall_set: Array = decor.wall
			var ornament: PackedScene = wall_set[(x * 7 + z * 13 + offset.x + offset.y) % wall_set.size()]
			batcher.add(ornament, Transform3D(Basis(Vector3.UP, directions[offset]), decor_position), Color.WHITE, keep_colors)'''),
    ('''static func _add_column(batcher: MeshBatcher, x: int, z: int, position: Vector3, stone: Color, decor: Dictionary) -> void:
	var column: PackedScene = decor.get("column", COLUMN_SCENE)
	if column == COLUMN_SCENE:
		batcher.add(COLUMN_SCENE, Transform3D(Basis(), position), stone)
		return
	var size: float = decor.get("column_scale", 1.0) * lerpf(0.92, 1.08, _hash01(x, z, 12))''',
     '''static func _add_column(batcher: MeshBatcher, x: int, z: int, position: Vector3, stone: Color, decor: Dictionary) -> void:
	var variant := _column_variant(decor, x, z)
	var column: PackedScene = variant.scene
	if column == COLUMN_SCENE:
		batcher.add(COLUMN_SCENE, Transform3D(Basis(), position), stone)
		return
	var size: float = variant.get("scale", 1.0) * lerpf(0.92, 1.08, _hash01(x, z, 12))'''),
    ('''	if open_sides <= 3 and rng.randf() < 0.3 and small_decor:
		_place(batcher, decor.clutter[rng.randi() % decor.clutter.size()],
			position + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25)),
			rng.randf_range(0.0, TAU), rng.randf_range(0.8, 1.15))
	elif open_sides == 4 and rng.randf() < 0.07:
		_place(batcher, decor.furniture[rng.randi() % decor.furniture.size()],
			position, rng.randf_range(0.0, TAU), 1.0)

	if open_sides == 2 and rng.randf() < 0.26:
		_place(batcher, decor.treasure[rng.randi() % decor.treasure.size()],
			position, rng.randf_range(0.0, TAU), 1.0)
	if rng.randf() < 0.08 and small_decor:
		_place(batcher, FLOOR_BRICKS_SCENE, position + Vector3(0, 0.02, 0), 0.0, 1.0)

static func _place(batcher: MeshBatcher, scene: PackedScene, position: Vector3, rotation_y: float, scale_factor: float) -> void:
	var basis := Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * scale_factor)
	batcher.add(scene, Transform3D(basis, position))''',
     '''	var keep_colors: bool = decor.get("keep_colors", false)
	if open_sides <= 3 and rng.randf() < 0.3 and small_decor:
		_place(batcher, decor.clutter[rng.randi() % decor.clutter.size()],
			position + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25)),
			rng.randf_range(0.0, TAU), rng.randf_range(0.8, 1.15), keep_colors)
	elif open_sides == 4 and rng.randf() < 0.07:
		_place(batcher, decor.furniture[rng.randi() % decor.furniture.size()],
			position, rng.randf_range(0.0, TAU), 1.0, keep_colors)

	if open_sides == 2 and rng.randf() < 0.26:
		_place(batcher, decor.treasure[rng.randi() % decor.treasure.size()],
			position, rng.randf_range(0.0, TAU), 1.0, keep_colors)
	# Розкидана цегла — до звичайних плит; на плитках набору свій малюнок.
	# Число з rng беремо й тут, щоб решта прикрас не зсунулась.
	if rng.randf() < 0.08 and small_decor and not decor.has("floor_tiles"):
		_place(batcher, FLOOR_BRICKS_SCENE, position + Vector3(0, 0.02, 0), 0.0, 1.0)

static func _place(batcher: MeshBatcher, scene: PackedScene, position: Vector3, rotation_y: float, scale_factor: float, keep_colors: bool = false) -> void:
	var basis := Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * scale_factor)
	batcher.add(scene, Transform3D(basis, position), Color.WHITE, keep_colors)'''),
]
for a, b in reps:
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
