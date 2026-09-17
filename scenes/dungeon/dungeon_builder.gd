extends RefCounted
class_name DungeonBuilder

## Збирає данж із модульних деталей за текстовою картою.
##
## Данж не генерується випадково — він НАМАЛЬОВАНИЙ. Кожен рівень це
## кілька рядків тексту, де один символ = одна клітинка 2x2 метри:
##
##   #  стіна (точніше — просто непрохідне місце; самі стіни
##      виростають по межі підлоги)
##   .  підлога
##   S  вхід: сюди стає герой, ворогів тут немає
##   m  поява ворога ближнього бою
##   r  поява стрільця
##   B  бос
##   E  вихід із данжу
##
## Так рівень легко правити руками, і кожен новий — це просто ще один
## текстовий блок, без жодного рядка коду.

const CELL := 2.0          # розмір клітинки в метрах
const WALL_HEIGHT := 2.0

const FLOOR_SCENE := preload("res://assets/models/dungeon/Floor_Modular.fbx")
const WALL_SCENE := preload("res://assets/models/dungeon/Wall_Modular.fbx")
const TORCH_SCENE := preload("res://assets/models/dungeon/Torch.fbx")
const COLUMN_SCENE := preload("res://assets/models/dungeon/Column.fbx")

## Символи, по яких можна ходити.
const WALKABLE := [".", "S", "m", "r", "B", "E"]

## Через скільки клітинок вішати факели.
const TORCH_EVERY := 4

## Збирає геометрію в parent і повертає, де що опинилось:
## {"start": Vector3, "exit": Vector3, "boss": Vector3,
##  "melee": [Vector3], "ranged": [Vector3]}
static func build(map_rows: Array, parent: Node3D) -> Dictionary:
	var result := {
		"start": Vector3.ZERO,
		"exit": Vector3.ZERO,
		"boss": Vector3.ZERO,
		"melee": [],
		"ranged": [],
	}

	for z in map_rows.size():
		var row: String = map_rows[z]
		for x in row.length():
			var symbol := row[x]
			if not WALKABLE.has(symbol):
				continue
			var position := Vector3(x * CELL, 0.0, z * CELL)
			_add_floor(parent, position)
			_add_walls_around(parent, map_rows, x, z, position)
			_register_marker(result, symbol, position)

	_add_columns(parent, map_rows)
	return result

static func _register_marker(result: Dictionary, symbol: String, position: Vector3) -> void:
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
			result.ranged.append(position)

static func _add_floor(parent: Node3D, position: Vector3) -> void:
	var tile: Node3D = FLOOR_SCENE.instantiate()
	tile.position = position
	parent.add_child(tile)
	_add_box_collision(tile, Vector3(CELL, 0.25, CELL), Vector3.ZERO)

## Стіни ставимо по МЕЖІ прохідних клітинок: якщо сусідня клітинка
## непрохідна, між ними виростає стіна. Так коридор завжди закритий, а
## зайвих стін усередині кімнат не буває.
static func _add_walls_around(parent: Node3D, map_rows: Array, x: int, z: int, position: Vector3) -> void:
	var directions := {
		Vector2i(0, -1): 0.0,       # північ
		Vector2i(0, 1): PI,         # південь
		Vector2i(-1, 0): PI / 2.0,  # захід
		Vector2i(1, 0): -PI / 2.0,  # схід
	}
	for offset: Vector2i in directions:
		if _is_walkable(map_rows, x + offset.x, z + offset.y):
			continue
		var wall: Node3D = WALL_SCENE.instantiate()
		wall.position = position + Vector3(offset.x, 0.0, offset.y) * CELL * 0.5
		wall.position.y = WALL_HEIGHT * 0.5
		wall.rotation.y = directions[offset]
		parent.add_child(wall)
		_add_box_collision(wall, Vector3(CELL, WALL_HEIGHT, 0.5), Vector3.ZERO)

		# Факели через кілька клітинок: данж має бути видним, але не
		# схожим на святкову гірлянду.
		if (x + z) % TORCH_EVERY == 0 and offset.y != 0:
			_add_torch(parent, wall.position, directions[offset], offset)

static func _add_torch(parent: Node3D, wall_position: Vector3, wall_rotation: float, offset: Vector2i) -> void:
	var torch: Node3D = TORCH_SCENE.instantiate()
	torch.position = wall_position - Vector3(offset.x, 0.0, offset.y) * 0.35 + Vector3(0, 0.6, 0)
	torch.rotation.y = wall_rotation
	parent.add_child(torch)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 2.4
	light.omni_range = 9.0
	light.position = torch.position + Vector3(0, 0.6, 0)
	parent.add_child(light)

## Колони всередині великих кімнат, щоб приміщення не були порожніми
## коробками. Ставимо рідко й лише там, де довкола вільно.
static func _add_columns(parent: Node3D, map_rows: Array) -> void:
	for z in range(1, map_rows.size() - 1):
		var row: String = map_rows[z]
		for x in range(1, row.length() - 1):
			if row[x] != "." or x % 6 != 0 or z % 6 != 0:
				continue
			if not _has_open_neighbours(map_rows, x, z):
				continue
			var column: Node3D = COLUMN_SCENE.instantiate()
			column.position = Vector3(x * CELL, 0.0, z * CELL)
			parent.add_child(column)
			_add_box_collision(column, Vector3(1.1, 4.0, 1.1), Vector3(0, 2.0, 0))

static func _has_open_neighbours(map_rows: Array, x: int, z: int) -> bool:
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if not _is_walkable(map_rows, x + offset.x, z + offset.y):
			return false
	return true

static func _is_walkable(map_rows: Array, x: int, z: int) -> bool:
	if z < 0 or z >= map_rows.size():
		return false
	var row: String = map_rows[z]
	if x < 0 or x >= row.length():
		return false
	return WALKABLE.has(row[x])

## Прямокутна перешкода замість точної форми моделі: для стін і підлоги
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
	node.add_child(body)
