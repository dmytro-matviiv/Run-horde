# -*- coding: utf-8 -*-
import os
os.chdir(r'D:\Claude code\idle survivor_like')
path = 'scenes/dungeon/dungeon_builder.gd'
s = open(path, encoding='utf-8').read()


def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b, 1)


rep('''## Перешкоди (стіни, колони) створюються одразу для всього рівня: вони
## коштують дешево, зате карта прохідності для ворогів будується один
## раз і не ламається, коли шматок сховано.''',
'''## Перешкоди (стіни, колони) створюються одразу для всього рівня: вони
## коштують дешево, зате карта прохідності для ворогів будується один
## раз і не ламається, коли шматок сховано.
##
## Стіни у фізиці зливаються в довгі прямі відрізки: замість чотирьохсот
## окремих коробочок по одній на кожну клітинку — кілька десятків довгих
## плит в одному тілі. Для героя й ворогів нічого не змінюється, а
## процесору телефона менше перевіряти на кожному кроці.''')

rep('''	var light_count := 0
	for z in map_rows.size():
		var row: String = map_rows[z]
		for x in row.length():
			var symbol := row[x]
			if not WALKABLE.has(symbol):
				continue
			var position := Vector3(x * CELL, 0.0, z * CELL)
			_register_marker(result, symbol, position)
			light_count = _add_wall_obstacles(parent, result, map_rows, x, z, position, light_count)

	_add_floor_collision(parent, map_rows)
	_add_column_obstacles(parent, map_rows)
	_create_chunks(parent, map_rows, result)
	return result''',
'''	# Уся нерухома фізика рівня — одне тіло з багатьма формами.
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
	return result''')

rep('''## Будує видиму геометрію одного шматка. Викликається тоді, коли гравець
## до нього підходить, — і саме тому вхід у данж не гальмує: спершу
## збирається лише найближче.
static func build_chunk(map_rows: Array, chunk: Dictionary) -> void:''',
'''## Будує видиму геометрію одного шматка. Викликається тоді, коли гравець
## до нього підходить, — і саме тому вхід у данж не гальмує: спершу
## збирається лише найближче.
##
## decor_density — частка дрібних прикрас (1.0 — усі). На слабкому
## телефоні бочок і павутиння менше, але стіни, скрині й колони ті самі:
## рівень упізнаваний на будь-якій якості.
static func build_chunk(map_rows: Array, chunk: Dictionary, decor_density: float = 1.0) -> void:''')

rep('''			var position := Vector3(x * CELL, 0.0, z * CELL)
			batcher.add(FLOOR_SCENE, Transform3D(Basis(), position))
			_add_wall_visuals(batcher, map_rows, x, z, position)
			_decorate_cell(batcher, map_rows, x, z, position, rng)''',
'''			var position := Vector3(x * CELL, 0.0, z * CELL)
			batcher.add(FLOOR_SCENE, Transform3D(Basis(), position))
			if _is_column_cell(map_rows, row, x, z):
				batcher.add(COLUMN_SCENE, Transform3D(Basis(), position))
			_add_wall_visuals(batcher, map_rows, x, z, position, decor_density)
			_decorate_cell(batcher, map_rows, x, z, position, rng, decor_density)''')

rep('''## Перешкоди й світло — на весь рівень одразу: вони дешеві, а карта
## прохідності має бути суцільною, інакше вороги губили б маршрут у
## ще не побудованих шматках.
static func _add_wall_obstacles(parent: Node3D, result: Dictionary, map_rows: Array, x: int, z: int, position: Vector3, light_count: int) -> int:
	for offset: Vector2i in _wall_directions():
		if _is_walkable(map_rows, x + offset.x, z + offset.y):
			continue
		var wall_position := position + Vector3(offset.x, 0.0, offset.y) * CELL * 0.5
		wall_position.y = WALL_HEIGHT * 0.5
		var wall_basis := Basis(Vector3.UP, _wall_directions()[offset])
		_add_static_box(parent, wall_position, Vector3(CELL, WALL_HEIGHT, 0.5), wall_basis)
''',
'''## Перешкоди й світло — на весь рівень одразу: вони дешеві, а карта
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
''')

rep('''static func _add_light(parent: Node3D, position: Vector3) -> OmniLight3D:''',
'''static func _append_run(wall_runs: Dictionary, key: String, cell: int) -> void:
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

static func _add_light(parent: Node3D, position: Vector3) -> OmniLight3D:''')

rep('''static func _add_floor_collision(parent: Node3D, map_rows: Array) -> void:
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

static func _add_column_obstacles(parent: Node3D, map_rows: Array) -> void:
	for z in range(1, map_rows.size() - 1):
		var row: String = map_rows[z]
		for x in range(1, row.length() - 1):
			if _is_column_cell(map_rows, row, x, z):
				_add_static_box(parent, Vector3(x * CELL, 2.0, z * CELL), Vector3(1.1, 4.0, 1.1), Basis())''',
'''static func _add_floor_collision(obstacles: StaticBody3D, map_rows: Array) -> void:
	var width := float(map_rows[0].length()) * CELL
	var depth := float(map_rows.size()) * CELL
	_add_box_shape(obstacles, Vector3(width * 0.5 - CELL * 0.5, -0.125, depth * 0.5 - CELL * 0.5),
		Vector3(width + CELL, 0.5, depth + CELL))

static func _add_column_obstacles(obstacles: StaticBody3D, map_rows: Array) -> void:
	for z in range(1, map_rows.size() - 1):
		var row: String = map_rows[z]
		for x in range(1, row.length() - 1):
			if _is_column_cell(map_rows, row, x, z):
				_add_box_shape(obstacles, Vector3(x * CELL, 2.0, z * CELL), Vector3(1.1, 4.0, 1.1))''')

rep('''			var node := Node3D.new()
			node.visible = false
			parent.add_child(node)
			result.chunks.append({
				"node": node,
				"rect": rect,
				"built": false,
				"center": Vector3(
					(chunk_x + CHUNK_CELLS * 0.5) * CELL, 0.0,
					(chunk_z + CHUNK_CELLS * 0.5) * CELL),
			})''',
'''			var node := Node3D.new()
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
			})''')

rep('''static func _add_wall_visuals(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3) -> void:''',
'''static func _add_wall_visuals(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, decor_density: float) -> void:''')

rep('''		if _chance(3, x, z, offset):''',
'''		if _chance(3, x, z, offset) and _hash01(x, z, 11) < decor_density:''')

rep('''static func _chance(one_in: int, x: int, z: int, offset: Vector2i) -> bool:
	return (x * 31 + z * 17 + offset.x * 7 + offset.y * 3) % (one_in * 2) == 0''',
'''static func _chance(one_in: int, x: int, z: int, offset: Vector2i) -> bool:
	return (x * 31 + z * 17 + offset.x * 7 + offset.y * 3) % (one_in * 2) == 0

## Стале "випадкове" число 0..1 для клітинки. Густота прикрас вирішується
## ним, а не генератором, щоб на різній якості решта оздоблення лишалась
## на тих самих місцях.
static func _hash01(x: int, z: int, salt: int) -> float:
	var h := (x * 73856093) ^ (z * 19349663) ^ (salt * 83492791)
	return float(absi(h) % 1000) / 1000.0''')

rep('''static func _decorate_cell(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, rng: RandomNumberGenerator) -> void:
	if map_rows[z][x] == "S":
		return   # вхідна зала лишається чистою
	var open_sides := _count_open_sides(map_rows, x, z)

	if open_sides <= 3 and rng.randf() < 0.3:''',
'''static func _decorate_cell(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, rng: RandomNumberGenerator, decor_density: float) -> void:
	if map_rows[z][x] == "S":
		return   # вхідна зала лишається чистою
	var open_sides := _count_open_sides(map_rows, x, z)
	var small_decor := _hash01(x, z, 5) < decor_density

	if open_sides <= 3 and rng.randf() < 0.3 and small_decor:''')

rep('''	if rng.randf() < 0.08:
		_place(batcher, FLOOR_BRICKS_SCENE''',
'''	if rng.randf() < 0.08 and small_decor:
		_place(batcher, FLOOR_BRICKS_SCENE''')

rep('''## Прямокутна перешкода замість точної форми моделі: герой не чіпляється
## за виступи цегли, а моби не застрягають на них. Малювання й фізика
## живуть окремо — картинку дає пакет, перешкоду оцей вузол.
static func _add_static_box(parent: Node3D, position: Vector3, size: Vector3, basis: Basis) -> void:
	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, position)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)''',
'''## Прямокутна перешкода замість точної форми моделі: герой не чіпляється
## за виступи цегли, а моби не застрягають на них. Малювання й фізика
## живуть окремо — картинку дає пакет, перешкоду оця форма.
static func _add_box_shape(obstacles: StaticBody3D, position: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	obstacles.add_child(shape)''')

open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('builder ok')
