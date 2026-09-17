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
const FLOOR_BRICKS_SCENE := preload("res://assets/models/dungeon/Floor_BricksSeparate.fbx")

## Дрібний непотріб попід стінами: бочки, ящики, черепи, вази.
const CLUTTER_SCENES := [
	preload("res://assets/models/dungeon/Barrel.fbx"),
	preload("res://assets/models/dungeon/Barrel2.fbx"),
	preload("res://assets/models/dungeon/Crate.fbx"),
	preload("res://assets/models/dungeon/Vase.fbx"),
	preload("res://assets/models/dungeon/Skull.fbx"),
	preload("res://assets/models/dungeon/Bucket.fbx"),
	preload("res://assets/models/dungeon/Bag_Standing.fbx"),
	preload("res://assets/models/dungeon/Brick.fbx"),
]

## Те, що вішається на стіни.
const WALL_DECOR_SCENES := [
	preload("res://assets/models/dungeon/Banner_wall.fbx"),
	preload("res://assets/models/dungeon/Cobweb.fbx"),
	preload("res://assets/models/dungeon/Cobweb2.fbx"),
	preload("res://assets/models/dungeon/Sword_WallMount.fbx"),
	preload("res://assets/models/dungeon/Decorative_Wall.fbx"),
]

## Великі речі посеред залів.
const FURNITURE_SCENES := [
	preload("res://assets/models/dungeon/Table_Small.fbx"),
	preload("res://assets/models/dungeon/Woodfire.fbx"),
	preload("res://assets/models/dungeon/Pedestal.fbx"),
	preload("res://assets/models/dungeon/Pedestal2.fbx"),
]

## Скарби й пастки.
const TREASURE_SCENES := [
	preload("res://assets/models/dungeon/Chest.fbx"),
	preload("res://assets/models/dungeon/Chest_Gold.fbx"),
	preload("res://assets/models/dungeon/Coin_Pile.fbx"),
	preload("res://assets/models/dungeon/Bag_Coins.fbx"),
]
const TRAP_SCENES := [
	preload("res://assets/models/dungeon/Trap_spikes.fbx"),
	preload("res://assets/models/dungeon/Spikes.fbx"),
]
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

	_add_floor_collision(parent, map_rows)
	_add_columns(parent, map_rows)
	_decorate(parent, map_rows)
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

## Підлогу малюємо плитками, а фізику для неї робимо суцільною плитою
## на весь рівень (див. _add_floor_collision). Сто окремих коробок
## давали стики, на яких герой чіплявся й "застрягав на рівному місці".
static func _add_floor(parent: Node3D, position: Vector3) -> void:
	var tile: Node3D = FLOOR_SCENE.instantiate()
	tile.position = position
	parent.add_child(tile)

## Одна велика плита під усім рівнем: рівно на висоті плиток, без
## жодного шва.
static func _add_floor_collision(parent: Node3D, map_rows: Array) -> void:
	var width := float(map_rows[0].length()) * CELL
	var depth := float(map_rows.size()) * CELL
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + CELL, 0.5, depth + CELL)
	shape.shape = box
	shape.position = Vector3(width * 0.5 - CELL * 0.5, -0.125, depth * 0.5 - CELL * 0.5)
	body.add_child(shape)
	parent.add_child(body)

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

## Оздоблення. Данж без дрібниць виглядає як коробка з коридорами, тож
## розставляємо весь набір: попід стінами — бочки, ящики й черепи, на
## стінах — прапори, павутиння й зброя, посеред великих залів — столи,
## багаття й статуї, по кутах — скрині, у вузьких місцях — пастки.
##
## Розкидаємо з фіксованим зерном: данж щоразу той самий, тож рівень
## лишається "намальованим", а не новим щоразу.
static func _decorate(parent: Node3D, map_rows: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917

	for z in map_rows.size():
		var row: String = map_rows[z]
		for x in row.length():
			if not WALKABLE.has(row[x]):
				continue
			var position := Vector3(x * CELL, 0.0, z * CELL)
			var open_sides := _count_open_sides(map_rows, x, z)

			# Клітинка біля стіни — сюди мотлох і настінні прикраси.
			if open_sides <= 3 and rng.randf() < 0.32:
				_place(parent, CLUTTER_SCENES[rng.randi() % CLUTTER_SCENES.size()],
					position + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25)),
					rng.randf_range(0.0, TAU), rng.randf_range(0.8, 1.15))
			elif open_sides == 4 and rng.randf() < 0.07:
				# Посеред зали — щось велике.
				_place(parent, FURNITURE_SCENES[rng.randi() % FURNITURE_SCENES.size()],
					position, rng.randf_range(0.0, TAU), 1.0)

			# Кути кімнат — скрині та скарби.
			if open_sides == 2 and rng.randf() < 0.28:
				_place(parent, TREASURE_SCENES[rng.randi() % TREASURE_SCENES.size()],
					position, rng.randf_range(0.0, TAU), 1.0)

			# Вузькі коридори — пастки на підлозі.
			if open_sides == 2 and rng.randf() < 0.12:
				_place(parent, TRAP_SCENES[rng.randi() % TRAP_SCENES.size()],
					position, 0.0, 1.0)

			# Плитка з окремих цеглин подекуди замість рівної підлоги.
			if rng.randf() < 0.1:
				_place(parent, FLOOR_BRICKS_SCENE, position + Vector3(0, 0.02, 0), 0.0, 1.0)

	_decorate_walls(parent, map_rows, rng)

## Настінні прикраси вішаємо на межі прохідної й непрохідної клітинки —
## там, де стоїть сама стіна.
static func _decorate_walls(parent: Node3D, map_rows: Array, rng: RandomNumberGenerator) -> void:
	var directions := {
		Vector2i(0, -1): 0.0,
		Vector2i(0, 1): PI,
		Vector2i(-1, 0): PI / 2.0,
		Vector2i(1, 0): -PI / 2.0,
	}
	for z in map_rows.size():
		var row: String = map_rows[z]
		for x in row.length():
			if not WALKABLE.has(row[x]):
				continue
			for offset: Vector2i in directions:
				if _is_walkable(map_rows, x + offset.x, z + offset.y):
					continue
				if rng.randf() > 0.16:
					continue
				var position := Vector3(x * CELL, 1.3, z * CELL) 					+ Vector3(offset.x, 0.0, offset.y) * (CELL * 0.5 - 0.15)
				_place(parent, WALL_DECOR_SCENES[rng.randi() % WALL_DECOR_SCENES.size()],
					position, directions[offset], 1.0)

static func _count_open_sides(map_rows: Array, x: int, z: int) -> int:
	var count := 0
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if _is_walkable(map_rows, x + offset.x, z + offset.y):
			count += 1
	return count

## Ставить прикрасу. Фізики їй не даємо: дрібниці не мають зупиняти ні
## героя, ні ворогів — інакше вони чіплятимуться за кожну вазу.
static func _place(parent: Node3D, scene: PackedScene, position: Vector3, rotation_y: float, scale_factor: float) -> void:
	var node: Node3D = scene.instantiate()
	node.position = position
	node.rotation.y = rotation_y
	node.scale = Vector3.ONE * scale_factor
	parent.add_child(node)
