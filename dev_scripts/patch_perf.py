# -*- coding: utf-8 -*-
import os
import re
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:70])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


# --- Складальник данжу: усе статичне малюється пакетами ---
patch('scenes/dungeon/dungeon_builder.gd', [
    ("""const CELL := 2.0          # розмір клітинки в метрах
const WALL_HEIGHT := 2.0""",
     """const CELL := 2.0          # розмір клітинки в метрах
const WALL_HEIGHT := 2.0

## Скільки факелів отримують СПРАВЖНЄ джерело світла. Кожне динамічне
## світло на телефоні коштує дорого, тож смолоскипи стоять усюди, а
## світять лише деякі — решту витягує загальне освітлення.
const LIT_TORCH_EVERY := 3
const MAX_LIGHTS := 10"""),
    # build(): працюємо через пакетувальник
    ("""static func build(map_rows: Array, parent: Node3D) -> Dictionary:
	var result := {
		"start": Vector3.ZERO,
		"exit": Vector3.ZERO,
		"boss": Vector3.ZERO,
		"melee": [],
		"ranged": [],
	}
""",
     """static func build(map_rows: Array, parent: Node3D) -> Dictionary:
	var result := {
		"start": Vector3.ZERO,
		"exit": Vector3.ZERO,
		"boss": Vector3.ZERO,
		"melee": [],
		"ranged": [],
	}
	# Уся статична геометрія данжу йде через пакетувальник: замість
	# сотень окремих вузлів відеокарта отримує десяток команд.
	var batcher := MeshBatcher.new()
	var lights := [0]   # у масиві, щоб лічильник був спільний для всіх викликів
"""),
    ("""			var position := Vector3(x * CELL, 0.0, z * CELL)
			_add_floor(parent, position)
			_add_walls_around(parent, map_rows, x, z, position)
			_register_marker(result, symbol, position)

	_add_floor_collision(parent, map_rows)
	_add_columns(parent, map_rows)
	_decorate(parent, map_rows)
	return result""",
     """			var position := Vector3(x * CELL, 0.0, z * CELL)
			_add_floor(batcher, position)
			_add_walls_around(batcher, parent, lights, map_rows, x, z, position)
			_register_marker(result, symbol, position)

	_add_floor_collision(parent, map_rows)
	_add_columns(batcher, parent, map_rows)
	_decorate(batcher, map_rows)
	batcher.flush(parent)
	return result"""),
    ("""static func _add_floor(parent: Node3D, position: Vector3) -> void:
	var tile: Node3D = FLOOR_SCENE.instantiate()
	tile.position = position
	parent.add_child(tile)""",
     """static func _add_floor(batcher: MeshBatcher, position: Vector3) -> void:
	batcher.add(FLOOR_SCENE, Transform3D(Basis(), position))"""),
    ("""static func _add_walls_around(parent: Node3D, map_rows: Array, x: int, z: int, position: Vector3) -> void:""",
     """static func _add_walls_around(batcher: MeshBatcher, parent: Node3D, lights: Array, map_rows: Array, x: int, z: int, position: Vector3) -> void:"""),
    ("""		var wall: Node3D = WALL_SCENE.instantiate()
		wall.position = position + Vector3(offset.x, 0.0, offset.y) * CELL * 0.5
		wall.position.y = WALL_HEIGHT * 0.5
		wall.rotation.y = directions[offset]
		parent.add_child(wall)
		_add_box_collision(wall, Vector3(CELL, WALL_HEIGHT, 0.5), Vector3.ZERO)

		# Факели через кілька клітинок: данж має бути видним, але не
		# схожим на святкову гірлянду.
		if (x + z) % TORCH_EVERY == 0 and offset.y != 0:
			_add_torch(parent, wall.position, directions[offset], offset)""",
     """		var wall_position := position + Vector3(offset.x, 0.0, offset.y) * CELL * 0.5
		wall_position.y = WALL_HEIGHT * 0.5
		var wall_basis := Basis(Vector3.UP, directions[offset])
		batcher.add(WALL_SCENE, Transform3D(wall_basis, wall_position))
		_add_static_box(parent, wall_position, Vector3(CELL, WALL_HEIGHT, 0.5), wall_basis)

		# Факели через кілька клітинок: данж має бути видним, але не
		# схожим на святкову гірлянду.
		if (x + z) % TORCH_EVERY == 0 and offset.y != 0:
			_add_torch(batcher, parent, lights, wall_position, directions[offset], offset)"""),
    ("""static func _add_torch(parent: Node3D, wall_position: Vector3, wall_rotation: float, offset: Vector2i) -> void:
	var torch: Node3D = TORCH_SCENE.instantiate()
	torch.position = wall_position - Vector3(offset.x, 0.0, offset.y) * 0.35 + Vector3(0, 0.6, 0)
	torch.rotation.y = wall_rotation
	parent.add_child(torch)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 2.4
	light.omni_range = 9.0
	light.position = torch.position + Vector3(0, 0.6, 0)
	parent.add_child(light)""",
     """static func _add_torch(batcher: MeshBatcher, parent: Node3D, lights: Array, wall_position: Vector3, wall_rotation: float, offset: Vector2i) -> void:
	var torch_position := wall_position - Vector3(offset.x, 0.0, offset.y) * 0.35 + Vector3(0, 0.6, 0)
	batcher.add(TORCH_SCENE, Transform3D(Basis(Vector3.UP, wall_rotation), torch_position))

	# Світло дають не всі смолоскипи: тридцять динамічних джерел телефон
	# не тягне, а десяток із більшим радіусом виглядає так само.
	if lights[0] >= MAX_LIGHTS or lights[0] % LIT_TORCH_EVERY != 0:
		lights[0] += 1
		return
	lights[0] += 1
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 3.2
	light.omni_range = 16.0
	light.position = torch_position + Vector3(0, 0.6, 0)
	parent.add_child(light)"""),
    ("""static func _add_columns(parent: Node3D, map_rows: Array) -> void:""",
     """static func _add_columns(batcher: MeshBatcher, parent: Node3D, map_rows: Array) -> void:"""),
    ("""			var column: Node3D = COLUMN_SCENE.instantiate()
			column.position = Vector3(x * CELL, 0.0, z * CELL)
			parent.add_child(column)
			_add_box_collision(column, Vector3(1.1, 4.0, 1.1), Vector3(0, 2.0, 0))""",
     """			var column_position := Vector3(x * CELL, 0.0, z * CELL)
			batcher.add(COLUMN_SCENE, Transform3D(Basis(), column_position))
			_add_static_box(parent, column_position + Vector3(0, 2.0, 0), Vector3(1.1, 4.0, 1.1), Basis())"""),
    ("""static func _decorate(parent: Node3D, map_rows: Array) -> void:""",
     """static func _decorate(batcher: MeshBatcher, map_rows: Array) -> void:"""),
    ("""	_decorate_walls(parent, map_rows, rng)""",
     """	_decorate_walls(batcher, map_rows, rng)"""),
    ("""static func _decorate_walls(parent: Node3D, map_rows: Array, rng: RandomNumberGenerator) -> void:""",
     """static func _decorate_walls(batcher: MeshBatcher, map_rows: Array, rng: RandomNumberGenerator) -> void:"""),
    ("""				_place(parent, WALL_DECOR_SCENES[rng.randi() % WALL_DECOR_SCENES.size()],
					position, directions[offset], 1.0)""",
     """				_place(batcher, WALL_DECOR_SCENES[rng.randi() % WALL_DECOR_SCENES.size()],
					position, directions[offset], 1.0)"""),
    ("""## Ставить прикрасу. Фізики їй не даємо: дрібниці не мають зупиняти ні
## героя, ні ворогів — інакше вони чіплятимуться за кожну вазу.
static func _place(parent: Node3D, scene: PackedScene, position: Vector3, rotation_y: float, scale_factor: float) -> void:
	var node: Node3D = scene.instantiate()
	node.position = position
	node.rotation.y = rotation_y
	node.scale = Vector3.ONE * scale_factor
	parent.add_child(node)""",
     """## Ставить прикрасу. Фізики їй не даємо: дрібниці не мають зупиняти ні
## героя, ні ворогів — інакше вони чіплятимуться за кожну вазу.
static func _place(batcher: MeshBatcher, scene: PackedScene, position: Vector3, rotation_y: float, scale_factor: float) -> void:
	var basis := Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * scale_factor)
	batcher.add(scene, Transform3D(basis, position))"""),
    ("""## Прямокутна перешкода замість точної форми моделі: для стін і підлоги
## це і швидше, і надійніше — герой не чіпляється за виступи цегли, а
## моби не застрягають на них.
static func _add_box_collision(node: Node3D, size: Vector3, offset: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	body.add_child(shape)
	node.add_child(body)""",
     """## Прямокутна перешкода замість точної форми моделі: для стін і підлоги
## це і швидше, і надійніше — герой не чіпляється за виступи цегли, а
## моби не застрягають на них. Малювання й фізика тепер живуть окремо:
## картинку дає пакет (MultiMesh), перешкоду — оцей вузол.
static func _add_static_box(parent: Node3D, position: Vector3, size: Vector3, basis: Basis) -> void:
	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, position)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)"""),
])

# Прикраси теж перетворюємо на пакетні виклики.
s = open('scenes/dungeon/dungeon_builder.gd', encoding='utf-8').read()
s = s.replace("_place(parent, CLUTTER_SCENES", "_place(batcher, CLUTTER_SCENES")
s = s.replace("_place(parent, FURNITURE_SCENES", "_place(batcher, FURNITURE_SCENES")
s = s.replace("_place(parent, TREASURE_SCENES", "_place(batcher, TREASURE_SCENES")
s = s.replace("_place(parent, TRAP_SCENES", "_place(batcher, TRAP_SCENES")
s = s.replace("_place(parent, FLOOR_BRICKS_SCENE", "_place(batcher, FLOOR_BRICKS_SCENE")
open('scenes/dungeon/dungeon_builder.gd', 'w', encoding='utf-8', newline='\n').write(s)
print('decor batched')

# --- Карта прохідності тепер будується по перешкодах, бо мешів як
# --- окремих вузлів більше немає.
s = open('scenes/dungeon/dungeon.tscn', encoding='utf-8').read()
s = s.replace('''[sub_resource type="NavigationMesh" id="NavigationMesh_dungeon"]''',
              '''[sub_resource type="NavigationMesh" id="NavigationMesh_dungeon"]
geometry_parsed_geometry_type = 1''')
open('scenes/dungeon/dungeon.tscn', 'w', encoding='utf-8', newline='\n').write(s)
print('navmesh from colliders')
