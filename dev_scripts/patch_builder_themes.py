# -*- coding: utf-8 -*-
# Будівельник данжу: теми (колір, прикраси), нові символи ворогів.
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:80])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


D = 'res://assets/models/dungeon/'

patch('scripts/systems/mesh_batcher.gd', [
    ('''## Додає одну модель у заданому місці.
func add(scene: PackedScene, transform: Transform3D) -> void:
	for part: Dictionary in _get_parts(scene):
		var key := "%s|%s" % [part.mesh.get_rid(), part.material.get_rid() if part.material else "-"]
		if not _batches.has(key):
			_batches[key] = {
				"mesh": part.mesh,
				"material": part.material,
				"lod_scale": part.lod_scale,
				"transforms": [],
			}
		_batches[key].transforms.append(transform * part.transform)''',
     '''## Додає одну модель у заданому місці. color — відтінок саме цієї
## моделі (стіни й підлога в кожного рівня свого кольору); білий — без
## зміни, тоді діє загальний tint.
func add(scene: PackedScene, transform: Transform3D, color: Color = Color.WHITE) -> void:
	var paint := color if color != Color.WHITE else tint
	for part: Dictionary in _get_parts(scene):
		var key := "%s|%s|%s" % [part.mesh.get_rid(), part.material.get_rid() if part.material else "-", paint.to_html()]
		if not _batches.has(key):
			_batches[key] = {
				"mesh": part.mesh,
				"material": part.material,
				"lod_scale": part.lod_scale,
				"tint": paint,
				"transforms": [],
			}
		_batches[key].transforms.append(transform * part.transform)'''),
    ('''		multimesh.mesh = batch.mesh if tint == Color.WHITE else _tinted(batch.mesh, tint)''',
     '''		var paint: Color = batch.get("tint", tint)
		multimesh.mesh = batch.mesh if paint == Color.WHITE else _tinted(batch.mesh, paint)'''),
])

patch('scenes/dungeon/dungeon_builder.gd', [
    ('''## Усі моделі, з яких збирається данж (для прогріву графіки).
static func all_decor_scenes() -> Array:
	var scenes: Array = [FLOOR_SCENE, FLOOR_BRICKS_SCENE, WALL_SCENE, TORCH_SCENE, COLUMN_SCENE]
	for group: Array in [CLUTTER_SCENES, WALL_DECOR_SCENES, FURNITURE_SCENES, TREASURE_SCENES, TRAP_SCENES]:
		scenes.append_array(group)
	return scenes

## Символи, по яких можна ходити.
const WALKABLE := [".", "S", "m", "r", "B", "E"]''',
     '''## ПРИКРАСИ ПІД ТЕМУ РІВНЯ. Склепи захаращені бочками й скринями,
## грибні печери — порожні, у павутинні й черепах, цитадель — з
## прапорами, зброєю на стінах і золотом. Моделі ті самі, набір різний.
const DECOR_SETS := {
	"crypt": {
		"clutter": CLUTTER_SCENES,
		"wall": WALL_DECOR_SCENES,
		"furniture": FURNITURE_SCENES,
		"treasure": TREASURE_SCENES,
		"traps": TRAP_SCENES,
	},
	"fungal": {
		"clutter": [
			preload("%(D)sSkull.fbx"), preload("%(D)sVase.fbx"), preload("%(D)sBrick.fbx"),
			preload("%(D)sBucket.fbx"), preload("%(D)sSkull.fbx"),
		],
		"wall": [preload("%(D)sCobweb.fbx"), preload("%(D)sCobweb2.fbx"), preload("%(D)sDecorative_Wall.fbx")],
		"furniture": [preload("%(D)sWoodfire.fbx"), preload("%(D)sPedestal.fbx")],
		"treasure": [preload("%(D)sCoin_Pile.fbx"), preload("%(D)sBag_Coins.fbx")],
		"traps": [preload("%(D)sSpikes.fbx")],
	},
	"citadel": {
		"clutter": [preload("%(D)sCrate.fbx"), preload("%(D)sBarrel2.fbx"), preload("%(D)sChair.fbx")],
		"wall": [
			preload("%(D)sBanner_wall.fbx"), preload("%(D)sSword_WallMount.fbx"),
			preload("%(D)sDecorative_Wall.fbx"), preload("%(D)sBanner_wall.fbx"),
		],
		"furniture": [preload("%(D)sTable_Big.fbx"), preload("%(D)sPedestal2.fbx"), preload("%(D)sWoodfire.fbx")],
		"treasure": [preload("%(D)sChest_Gold.fbx"), preload("%(D)sCoin_Pile.fbx"), preload("%(D)sChest.fbx")],
		"traps": [preload("%(D)sTrap_spikes.fbx")],
	},
}

## Усі моделі, з яких збирається данж (для прогріву графіки).
static func all_decor_scenes() -> Array:
	var scenes: Array = [FLOOR_SCENE, FLOOR_BRICKS_SCENE, WALL_SCENE, TORCH_SCENE, COLUMN_SCENE]
	for set_name: String in DECOR_SETS:
		for group: String in DECOR_SETS[set_name]:
			for scene: PackedScene in DECOR_SETS[set_name][group]:
				if not scenes.has(scene):
					scenes.append(scene)
	return scenes

## Символи, по яких можна ходити: підлога, вхід/вихід/бос і всі мітки
## ворогів (m r w x c t).
const WALKABLE := [".", "S", "B", "E", "m", "r", "w", "x", "c", "t"]
const ENEMY_SYMBOLS := ["m", "r", "w", "x", "c", "t"]

## Тема за замовчуванням — якщо рівень її не задав.
const DEFAULT_THEME := {
	"stone": Color.WHITE, "floor": Color.WHITE, "torch": Color(1.0, 0.72, 0.38), "decor": "crypt",
}''' % {'D': D}),
    ('''## Повертає {"start", "exit", "boss", "melee", "ranged", "chunks", "lights"}.
static func build_base(map_rows: Array, parent: Node3D) -> Dictionary:
	var result := {
		"start": Vector3.ZERO,
		"exit": Vector3.ZERO,
		"boss": Vector3.ZERO,
		"melee": [],
		"ranged": [],
		"chunks": [],
		"lights": [],
	}''',
     '''## Повертає {"start", "exit", "boss", "spawns", "chunks", "lights"};
## spawns — список {symbol, position} для кожної мітки ворога.
static func build_base(map_rows: Array, parent: Node3D, theme: Dictionary = DEFAULT_THEME) -> Dictionary:
	var result := {
		"start": Vector3.ZERO,
		"exit": Vector3.ZERO,
		"boss": Vector3.ZERO,
		"spawns": [],
		"chunks": [],
		"lights": [],
		"torch_color": theme.get("torch", DEFAULT_THEME.torch),
	}'''),
    ('''static func build_chunk(map_rows: Array, chunk: Dictionary, decor_density: float = 1.0) -> void:
	if chunk.built:
		return
	chunk.built = true

	var batcher := MeshBatcher.new()''',
     '''static func build_chunk(map_rows: Array, chunk: Dictionary, decor_density: float = 1.0, theme: Dictionary = DEFAULT_THEME) -> void:
	if chunk.built:
		return
	chunk.built = true

	var batcher := MeshBatcher.new()
	var stone: Color = theme.get("stone", Color.WHITE)
	var floor_color: Color = theme.get("floor", Color.WHITE)
	var decor: Dictionary = DECOR_SETS.get(theme.get("decor", "crypt"), DECOR_SETS.crypt)
	# Прикраси фарбуємо слабше за камінь: скриня в крижаній цитаделі має
	# бути ледь інеєва, а не синя.
	batcher.tint = Color.WHITE.lerp(stone, 0.5)'''),
    ('''			batcher.add(FLOOR_SCENE, Transform3D(Basis(), position))
			if _is_column_cell(map_rows, row, x, z):
				batcher.add(COLUMN_SCENE, Transform3D(Basis(), position))
			_add_wall_visuals(batcher, map_rows, x, z, position, decor_density)
			_decorate_cell(batcher, map_rows, x, z, position, rng, decor_density)''',
     '''			batcher.add(FLOOR_SCENE, Transform3D(Basis(), position), floor_color)
			if _is_column_cell(map_rows, row, x, z):
				batcher.add(COLUMN_SCENE, Transform3D(Basis(), position), stone)
			_add_wall_visuals(batcher, map_rows, x, z, position, decor_density, stone, decor)
			_decorate_cell(batcher, map_rows, x, z, position, rng, decor_density, decor)'''),
    ('''static func _register_marker(result: Dictionary, symbol: String, position: Vector3) -> void:
	match symbol:
		"S":
			result.start = position
		"E":
			result.exit = position
		"B":
			result.boss = position
		"m":
			result.melee.append(position)
		"r":
			result.ranged.append(position)''',
     '''static func _register_marker(result: Dictionary, symbol: String, position: Vector3) -> void:
	match symbol:
		"S":
			result.start = position
		"E":
			result.exit = position
		"B":
			result.boss = position
		_:
			if ENEMY_SYMBOLS.has(symbol):
				result.spawns.append({"symbol": symbol, "position": position})'''),
    ('''			result.lights.append(_add_light(parent, torch_position))''',
     '''			result.lights.append(_add_light(parent, torch_position, result.torch_color))'''),
    ('''static func _add_light(parent: Node3D, position: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)''',
     '''static func _add_light(parent: Node3D, position: Vector3, color: Color) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color'''),
    ('''static func _add_wall_visuals(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, decor_density: float) -> void:''',
     '''static func _add_wall_visuals(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, decor_density: float, stone: Color, decor: Dictionary) -> void:'''),
    ('''		batcher.add(WALL_SCENE, Transform3D(Basis(Vector3.UP, directions[offset]), wall_position))''',
     '''		batcher.add(WALL_SCENE, Transform3D(Basis(Vector3.UP, directions[offset]), wall_position), stone)'''),
    ('''			var decor: PackedScene = WALL_DECOR_SCENES[(x * 7 + z * 13 + offset.x + offset.y) % WALL_DECOR_SCENES.size()]
			batcher.add(decor, Transform3D(Basis(Vector3.UP, directions[offset]), decor_position))''',
     '''			var wall_set: Array = decor.wall
			var ornament: PackedScene = wall_set[(x * 7 + z * 13 + offset.x + offset.y) % wall_set.size()]
			batcher.add(ornament, Transform3D(Basis(Vector3.UP, directions[offset]), decor_position))'''),
    ('''static func _decorate_cell(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, rng: RandomNumberGenerator, decor_density: float) -> void:''',
     '''static func _decorate_cell(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, rng: RandomNumberGenerator, decor_density: float, decor: Dictionary) -> void:'''),
    ('''		_place(batcher, CLUTTER_SCENES[rng.randi() % CLUTTER_SCENES.size()],''',
     '''		_place(batcher, decor.clutter[rng.randi() % decor.clutter.size()],'''),
    ('''		_place(batcher, FURNITURE_SCENES[rng.randi() % FURNITURE_SCENES.size()],''',
     '''		_place(batcher, decor.furniture[rng.randi() % decor.furniture.size()],'''),
    ('''		_place(batcher, TREASURE_SCENES[rng.randi() % TREASURE_SCENES.size()],''',
     '''		_place(batcher, decor.treasure[rng.randi() % decor.treasure.size()],'''),
    ('''		_place(batcher, TRAP_SCENES[rng.randi() % TRAP_SCENES.size()], position, 0.0, 1.0)''',
     '''		_place(batcher, decor.traps[rng.randi() % decor.traps.size()], position, 0.0, 1.0)'''),
])
