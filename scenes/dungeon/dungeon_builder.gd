extends RefCounted
class_name DungeonBuilder

## Збирає данж із модульних деталей за текстовою картою.
##
## Данж не генерується випадково — він НАМАЛЬОВАНИЙ. Кожен рівень це
## кілька рядків тексту, де один символ = клітинка 2x2 метри:
##
##   #  непрохідне місце (стіни виростають по межі підлоги)
##   .  підлога
##   S  вхід: сюди стає герой, ворогів тут немає
##   m  поява ворога ближнього бою
##   r  поява стрільця
##   B  бос
##   E  вихід із данжу
##
## ЧОМУ ДАНЖ РІЖЕТЬСЯ НА ШМАТКИ
##
## Раніше рівень будувався цілком і цілком же малювався щокадру: навіть
## кімнати за три повороти звідси. Для відеокарти вся підлога — один
## великий об'єкт, і сховати її частину неможливо. На комп'ютері це
## непомітно, телефон від такого гріється й лагає.
##
## Тепер карта ріжеться на квадрати CHUNK_CELLS x CHUNK_CELLS. Кожен
## шматок малюється окремо, будується не раніше, ніж гравець до нього
## наблизиться, і ховається, коли той відходить. Гравець цього не
## бачить — він просто йде коридором, а данж з'являється попереду.
##
## Перешкоди (стіни, колони) створюються одразу для всього рівня: вони
## коштують дешево, зате карта прохідності для ворогів будується один
## раз і не ламається, коли шматок сховано.
##
## Стіни у фізиці зливаються в довгі прямі відрізки: замість чотирьохсот
## окремих коробочок по одній на кожну клітинку — кілька десятків довгих
## плит в одному тілі. Для героя й ворогів нічого не змінюється, а
## процесору телефона менше перевіряти на кожному кроці.

const CELL := 2.0          # розмір клітинки в метрах
const WALL_HEIGHT := 2.0

## Розмір шматка в клітинках. 10 клітинок = 20 метрів: приблизно одна
## велика зала або довгий коридор.
const CHUNK_CELLS := 10

## Джерело світла отримує кожен другий смолоскип по всьому рівню, але
## горять лише кілька найближчих до героя (скільки — вирішує якість
## графіки, див. Dungeon._update_lights). Вимкнене світло нічого не
## коштує, тож данж освітлений однаково, хоч біля входу, хоч біля боса.
const LIT_TORCH_EVERY := 2
const TORCH_EVERY := 4

const FLOOR_SCENE := preload("res://assets/models/dungeon/Floor_Modular.fbx")
const FLOOR_BRICKS_SCENE := preload("res://assets/models/dungeon/Floor_BricksSeparate.fbx")
const WALL_SCENE := preload("res://assets/models/dungeon/Wall_Modular.fbx")
const TORCH_SCENE := preload("res://assets/models/dungeon/Torch.fbx")
const COLUMN_SCENE := preload("res://assets/models/dungeon/Column.fbx")

## Дрібний непотріб попід стінами.
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

## Усі моделі, з яких збирається данж (для прогріву графіки).
static func all_decor_scenes() -> Array:
	var scenes: Array = [FLOOR_SCENE, FLOOR_BRICKS_SCENE, WALL_SCENE, TORCH_SCENE, COLUMN_SCENE]
	for group: Array in [CLUTTER_SCENES, WALL_DECOR_SCENES, FURNITURE_SCENES, TREASURE_SCENES, TRAP_SCENES]:
		scenes.append_array(group)
	return scenes

## Символи, по яких можна ходити.
const WALKABLE := [".", "S", "m", "r", "B", "E"]

## Створює те, що має існувати одразу: мітки, перешкоди, світло і
## порожні вузли-шматки. Геометрію шматків будує вже streamer.
##
## Повертає {"start", "exit", "boss", "melee", "ranged", "chunks", "lights"}.
static func build_base(map_rows: Array, parent: Node3D) -> Dictionary:
	var result := {
		"start": Vector3.ZERO,
		"exit": Vector3.ZERO,
		"boss": Vector3.ZERO,
		"melee": [],
		"ranged": [],
		"chunks": [],
		"lights": [],
	}

	# Уся нерухома фізика рівня — одне тіло з багатьма формами.
	var obstacles := StaticBody3D.new()
	obstacles.name = "Obstacles"
	parent.add_child(obstacles)

	var light_count := 0
	var wall_runs := {}
	for z in map_rows.size():
		var row: String = map_rows[z]
		for x in row.length():
			var symbol := row[x]
			if not WALKABLE.has(symbol):
				continue
			var position := Vector3(x * CELL, 0.0, z * CELL)
			_register_marker(result, symbol, position)
			light_count = _collect_walls(parent, result, wall_runs, map_rows, x, z, position, light_count)

	_add_merged_walls(obstacles, wall_runs)
	_add_floor_collision(obstacles, map_rows)
	_add_column_obstacles(obstacles, map_rows)
	_create_chunks(parent, map_rows, result)
	return result

## Будує видиму геометрію одного шматка. Викликається тоді, коли гравець
## до нього підходить, — і саме тому вхід у данж не гальмує: спершу
## збирається лише найближче.
##
## decor_density — частка дрібних прикрас (1.0 — усі). На слабкому
## телефоні бочок і павутиння менше, але стіни, скрині й колони ті самі:
## рівень упізнаваний на будь-якій якості.
static func build_chunk(map_rows: Array, chunk: Dictionary, decor_density: float = 1.0) -> void:
	if chunk.built:
		return
	chunk.built = true

	var batcher := MeshBatcher.new()
	var rect: Rect2i = chunk.rect
	# Насіння прив'язане до координат шматка, а не до порядку побудови:
	# данж виглядає однаково, з якого боку в нього не зайти.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917 + rect.position.x * 73856093 + rect.position.y * 19349663

	for z in range(rect.position.y, rect.end.y):
		if z < 0 or z >= map_rows.size():
			continue
		var row: String = map_rows[z]
		for x in range(rect.position.x, rect.end.x):
			if x < 0 or x >= row.length() or not WALKABLE.has(row[x]):
				continue
			var position := Vector3(x * CELL, 0.0, z * CELL)
			batcher.add(FLOOR_SCENE, Transform3D(Basis(), position))
			if _is_column_cell(map_rows, row, x, z):
				batcher.add(COLUMN_SCENE, Transform3D(Basis(), position))
			_add_wall_visuals(batcher, map_rows, x, z, position, decor_density)
			_decorate_cell(batcher, map_rows, x, z, position, rng, decor_density)

	batcher.flush(chunk.node)

# --- мітки й перешкоди ---

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

static func _wall_directions() -> Dictionary:
	return {
		Vector2i(0, -1): 0.0,       # північ
		Vector2i(0, 1): PI,         # південь
		Vector2i(-1, 0): PI / 2.0,  # захід
		Vector2i(1, 0): -PI / 2.0,  # схід
	}

## Перешкоди й світло — на весь рівень одразу: вони дешеві, а карта
## прохідності має бути суцільною, інакше вороги губили б маршрут у
## ще не побудованих шматках.
##
## Кожен шматок стіни записуємо в "лінію" — межу між рядами або
## стовпцями клітинок. Потім сусідні шматки на одній лінії зливаються.
static func _collect_walls(parent: Node3D, result: Dictionary, wall_runs: Dictionary, map_rows: Array, x: int, z: int, position: Vector3, light_count: int) -> int:
	for offset: Vector2i in _wall_directions():
		if _is_walkable(map_rows, x + offset.x, z + offset.y):
			continue
		var wall_position := position + Vector3(offset.x, 0.0, offset.y) * CELL * 0.5
		wall_position.y = WALL_HEIGHT * 0.5
		if offset.y != 0:
			_append_run(wall_runs, "h%d" % (z * 2 + offset.y), x)
		else:
			_append_run(wall_runs, "v%d" % (x * 2 + offset.x), z)

		if (x + z) % TORCH_EVERY != 0 or offset.y == 0:
			continue
		if light_count % LIT_TORCH_EVERY == 0:
			var torch_position := wall_position - Vector3(offset.x, 0.0, offset.y) * 0.35 + Vector3(0, 1.2, 0)
			result.lights.append(_add_light(parent, torch_position))
		light_count += 1
	return light_count

static func _append_run(wall_runs: Dictionary, key: String, cell: int) -> void:
	if not wall_runs.has(key):
		wall_runs[key] = []
	wall_runs[key].append(cell)

## Зливає сусідні шматки стіни на кожній лінії в одну довгу плиту.
## Ключ "h7" — горизонтальна лінія між рядами (7 = подвоєна координата),
## "v12" — вертикальна між стовпцями.
static func _add_merged_walls(obstacles: StaticBody3D, wall_runs: Dictionary) -> void:
	for key: String in wall_runs:
		var cells: Array = wall_runs[key]
		cells.sort()
		var line := float(key.substr(1).to_int()) * CELL * 0.5
		var start: int = cells[0]
		var previous: int = cells[0]
		for i in range(1, cells.size() + 1):
			var current: int = cells[i] if i < cells.size() else previous + 2
			if current == previous + 1:
				previous = current
				continue
			_add_wall_run(obstacles, key[0] == "h", line, start, previous)
			start = current
			previous = current

static func _add_wall_run(obstacles: StaticBody3D, horizontal: bool, line: float, first: int, last: int) -> void:
	var length := float(last - first + 1) * CELL
	var middle := (float(first + last) * 0.5) * CELL
	if horizontal:
		_add_box_shape(obstacles, Vector3(middle, WALL_HEIGHT * 0.5, line), Vector3(length, WALL_HEIGHT, 0.5))
	else:
		_add_box_shape(obstacles, Vector3(line, WALL_HEIGHT * 0.5, middle), Vector3(0.5, WALL_HEIGHT, length))

static func _add_light(parent: Node3D, position: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 4.0
	light.omni_range = 20.0
	light.position = position
	light.visible = false   # вмикає данж, коли герой поруч
	parent.add_child(light)
	return light

## Одна суцільна плита під усім рівнем: рівно на висоті плиток, без
## жодного шва, на якому герой міг би зачепитись.
static func _add_floor_collision(obstacles: StaticBody3D, map_rows: Array) -> void:
	var width := float(map_rows[0].length()) * CELL
	var depth := float(map_rows.size()) * CELL
	_add_box_shape(obstacles, Vector3(width * 0.5 - CELL * 0.5, -0.125, depth * 0.5 - CELL * 0.5),
		Vector3(width + CELL, 0.5, depth + CELL))

static func _add_column_obstacles(obstacles: StaticBody3D, map_rows: Array) -> void:
	for z in range(1, map_rows.size() - 1):
		var row: String = map_rows[z]
		for x in range(1, row.length() - 1):
			if _is_column_cell(map_rows, row, x, z):
				_add_box_shape(obstacles, Vector3(x * CELL, 2.0, z * CELL), Vector3(1.1, 4.0, 1.1))

static func _is_column_cell(map_rows: Array, row: String, x: int, z: int) -> bool:
	if row[x] != "." or x % 6 != 0 or z % 6 != 0:
		return false
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if not _is_walkable(map_rows, x + offset.x, z + offset.y):
			return false
	return true

# --- шматки ---

## Ріже карту на квадрати й створює для кожного порожній вузол.
static func _create_chunks(parent: Node3D, map_rows: Array, result: Dictionary) -> void:
	var width: int = map_rows[0].length()
	var depth: int = map_rows.size()
	for chunk_z in range(0, depth, CHUNK_CELLS):
		for chunk_x in range(0, width, CHUNK_CELLS):
			var rect := Rect2i(chunk_x, chunk_z, CHUNK_CELLS, CHUNK_CELLS)
			if not _chunk_has_floor(map_rows, rect):
				continue
			var node := Node3D.new()
			node.visible = false
			parent.add_child(node)
			result.chunks.append({
				"node": node,
				"rect": rect,
				"built": false,
				# Межі шматка у світі (площина XZ). Відстань міряємо до
				# найближчого КРАЮ, а не до центру: інакше великий шматок
				# міг би зникнути, коли його край ще в кадрі.
				"bounds": Rect2(
					(chunk_x - 0.5) * CELL, (chunk_z - 0.5) * CELL,
					CHUNK_CELLS * CELL, CHUNK_CELLS * CELL),
			})

static func _chunk_has_floor(map_rows: Array, rect: Rect2i) -> bool:
	for z in range(rect.position.y, rect.end.y):
		if z < 0 or z >= map_rows.size():
			continue
		var row: String = map_rows[z]
		for x in range(rect.position.x, rect.end.x):
			if x >= 0 and x < row.length() and WALKABLE.has(row[x]):
				return true
	return false

# --- видима геометрія шматка ---

static func _add_wall_visuals(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, decor_density: float) -> void:
	var directions := _wall_directions()
	for offset: Vector2i in directions:
		if _is_walkable(map_rows, x + offset.x, z + offset.y):
			continue
		var wall_position := position + Vector3(offset.x, 0.0, offset.y) * CELL * 0.5
		wall_position.y = WALL_HEIGHT * 0.5
		batcher.add(WALL_SCENE, Transform3D(Basis(Vector3.UP, directions[offset]), wall_position))

		if (x + z) % TORCH_EVERY == 0 and offset.y != 0:
			var torch_position := wall_position - Vector3(offset.x, 0.0, offset.y) * 0.35 + Vector3(0, 0.6, 0)
			batcher.add(TORCH_SCENE, Transform3D(Basis(Vector3.UP, directions[offset]), torch_position))

		if _chance(3, x, z, offset) and _hash01(x, z, 11) < decor_density:
			var decor_position := position + Vector3(0, 1.3, 0) \
				+ Vector3(offset.x, 0.0, offset.y) * (CELL * 0.5 - 0.15)
			var decor: PackedScene = WALL_DECOR_SCENES[(x * 7 + z * 13 + offset.x + offset.y) % WALL_DECOR_SCENES.size()]
			batcher.add(decor, Transform3D(Basis(Vector3.UP, directions[offset]), decor_position))

## Невелика хитрість: "випадковість" для стін рахується з координат, а
## не з генератора. Тоді шматок виглядає однаково, скільки б разів його
## не будували й ховали.
static func _chance(one_in: int, x: int, z: int, offset: Vector2i) -> bool:
	return (x * 31 + z * 17 + offset.x * 7 + offset.y * 3) % (one_in * 2) == 0

## Стале "випадкове" число 0..1 для клітинки. Густота прикрас вирішується
## ним, а не генератором, щоб на різній якості решта оздоблення лишалась
## на тих самих місцях.
static func _hash01(x: int, z: int, salt: int) -> float:
	var h := (x * 73856093) ^ (z * 19349663) ^ (salt * 83492791)
	return float(absi(h) % 1000) / 1000.0

## Оздоблення клітинки: мотлох попід стінами, меблі посеред залів,
## скрині по кутах, пастки у вузьких місцях.
static func _decorate_cell(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, rng: RandomNumberGenerator, decor_density: float) -> void:
	if map_rows[z][x] == "S":
		return   # вхідна зала лишається чистою
	var open_sides := _count_open_sides(map_rows, x, z)
	var small_decor := _hash01(x, z, 5) < decor_density

	if open_sides <= 3 and rng.randf() < 0.3 and small_decor:
		_place(batcher, CLUTTER_SCENES[rng.randi() % CLUTTER_SCENES.size()],
			position + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25)),
			rng.randf_range(0.0, TAU), rng.randf_range(0.8, 1.15))
	elif open_sides == 4 and rng.randf() < 0.07:
		_place(batcher, FURNITURE_SCENES[rng.randi() % FURNITURE_SCENES.size()],
			position, rng.randf_range(0.0, TAU), 1.0)

	if open_sides == 2 and rng.randf() < 0.26:
		_place(batcher, TREASURE_SCENES[rng.randi() % TREASURE_SCENES.size()],
			position, rng.randf_range(0.0, TAU), 1.0)
	if open_sides == 2 and rng.randf() < 0.12:
		_place(batcher, TRAP_SCENES[rng.randi() % TRAP_SCENES.size()], position, 0.0, 1.0)
	if rng.randf() < 0.08 and small_decor:
		_place(batcher, FLOOR_BRICKS_SCENE, position + Vector3(0, 0.02, 0), 0.0, 1.0)

static func _place(batcher: MeshBatcher, scene: PackedScene, position: Vector3, rotation_y: float, scale_factor: float) -> void:
	var basis := Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * scale_factor)
	batcher.add(scene, Transform3D(basis, position))

static func _count_open_sides(map_rows: Array, x: int, z: int) -> int:
	var count := 0
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if _is_walkable(map_rows, x + offset.x, z + offset.y):
			count += 1
	return count

static func _is_walkable(map_rows: Array, x: int, z: int) -> bool:
	if z < 0 or z >= map_rows.size():
		return false
	var row: String = map_rows[z]
	if x < 0 or x >= row.length():
		return false
	return WALKABLE.has(row[x])

## Прямокутна перешкода замість точної форми моделі: герой не чіпляється
## за виступи цегли, а моби не застрягають на них. Малювання й фізика
## живуть окремо — картинку дає пакет, перешкоду оця форма.
static func _add_box_shape(obstacles: StaticBody3D, position: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	obstacles.add_child(shape)
