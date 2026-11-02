# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scripts/systems/mesh_batcher.gd", [
    ('''## Зібрані розміщення: ключ (меш + матеріал) -> {mesh, material, transforms}
var _batches: Dictionary = {}
''', '''## Зібрані розміщення: ключ (меш + матеріал) -> {mesh, material, transforms}
var _batches: Dictionary = {}

## Лише записувати, що й де стоїть (placements: [[scene, transform]]), без
## малювання — так данж заздалегідь ставить перешкоди під прикраси.
var record := false
var placements: Array = []
static var _bounds: Dictionary = {}
'''),
    ('''func add(scene: PackedScene, transform: Transform3D, color: Color = Color.WHITE, keep_colors: bool = false) -> void:
	var paint''', '''func add(scene: PackedScene, transform: Transform3D, color: Color = Color.WHITE, keep_colors: bool = false) -> void:
	if record:
		placements.append([scene, transform])
		return
	var paint'''),
    ('''## Положення меша відносно кореня сцени: перемножуємо локальні''', '''## Межі моделі в її власних координатах (усі меші разом).
func scene_bounds(scene: PackedScene) -> AABB:
	if _bounds.has(scene):
		return _bounds[scene]
	var box := AABB()
	var first := true
	for part: Dictionary in _get_parts(scene):
		var part_box: AABB = (part.transform as Transform3D) * (part.mesh as Mesh).get_aabb()
		box = part_box if first else box.merge(part_box)
		first = false
	_bounds[scene] = box
	return box

## Положення меша відносно кореня сцени: перемножуємо локальні'''),
])

patch("scenes/dungeon/dungeon_builder.gd", [
    ('''	var rect: Rect2i = chunk.rect
	# Насіння прив'язане до координат шматка, а не до порядку побудови:
	# данж виглядає однаково, з якого боку в нього не зайти.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917 + rect.position.x * 73856093 + rect.position.y * 19349663
	var layout''', '''	var rect: Rect2i = chunk.rect
	var rng := _chunk_rng(rect)
	var layout'''),
    ('''# --- мітки й перешкоди ---
''', '''## Насіння прив'язане до координат шматка, а не до порядку побудови:
## данж виглядає однаково, з якого боку в нього не зайти. Те саме насіння
## бере й add_decor_obstacles — перешкоди стоять рівно там, де прикраси.
static func _chunk_rng(rect: Rect2i) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917 + rect.position.x * 73856093 + rect.position.y * 19349663
	return rng

## Найменша прикраса, крізь яку вже не можна пройти (м): стоп завширшки й
## заввишки. Черепи, монети, свічки, кістки — нижчі, через них ступаємо.
const SOLID_MIN_FOOTPRINT := 0.55
const SOLID_MIN_HEIGHT := 0.35
## Коробка трохи менша за модель: обриси моделей нерівні, а повна
## коробка чіплялась би за героя вже на підході.
const SOLID_SHRINK := 0.78

## ТВЕРДІ ПРИКРАСИ: меблі посеред зал, скрині, ящики й бочки під стінами,
## гриби — під кожну коробка-перешкода (і для героя, і для ворогів). Самі
## прикраси малюються пізніше, шматками (build_chunk), а перешкоди мають
## бути до того, як печеться карта прохідності. Тому тут той самий
## розклад проходить "насухо": те саме насіння, ті самі клітинки й умови,
## лише замість малювання — запис, що й де стоїть.
## Статуї, брили, стійки, припаси й прапори розкладки мають свої перешкоди
## (_add_layout_obstacles) — їх тут пропускаємо.
static func add_decor_obstacles(obstacles: StaticBody3D, map_rows: Array, chunks: Array, decor_density: float,
		theme: Dictionary = DEFAULT_THEME, reserved: Dictionary = {}) -> int:
	var decor: Dictionary = DECOR_SETS.get(theme.get("decor", "crypt"), DECOR_SETS.crypt)
	var layout: Dictionary = _build_layout(map_rows, decor) if decor.has("floor_rules") else {}
	var skip := {}
	for key in ["landmark", "rock", "rack", "supplies", "banner"]:
		if decor.has(key):
			skip[decor[key].scene] = true
	var batcher := MeshBatcher.new()
	batcher.record = true
	for chunk: Dictionary in chunks:
		var rect: Rect2i = chunk.rect
		var rng := _chunk_rng(rect)
		for z in range(rect.position.y, rect.end.y):
			if z < 0 or z >= map_rows.size():
				continue
			var row: String = map_rows[z]
			for x in range(rect.position.x, rect.end.x):
				if x < 0 or x >= row.length() or not WALKABLE.has(row[x]):
					continue
				var position := Vector3(x * CELL, 0.0, z * CELL)
				var cell := Vector2i(x, z)
				if not decor.get("no_columns", false) and _is_column_cell(map_rows, row, x, z):
					continue
				if not layout.is_empty() and _add_layout_items(batcher, layout, cell, position, decor):
					continue
				if not reserved.has(cell):
					_decorate_cell(batcher, map_rows, x, z, position, rng, decor_density, decor)
	var count := 0
	for placement: Array in batcher.placements:
		var scene: PackedScene = placement[0]
		if skip.has(scene):
			continue
		var transform: Transform3D = placement[1]
		var box: AABB = transform * batcher.scene_bounds(scene)
		var footprint := maxf(box.size.x, box.size.z)
		if footprint < SOLID_MIN_FOOTPRINT or box.size.y < SOLID_MIN_HEIGHT:
			continue
		var size := Vector3(box.size.x * SOLID_SHRINK, minf(box.size.y, 2.5), box.size.z * SOLID_SHRINK)
		var center := box.get_center()
		_add_box_shape(obstacles, Vector3(center.x, size.y * 0.5, center.z), size)
		count += 1
	return count

# --- мітки й перешкоди ---
'''),
])

patch("scenes/dungeon/dungeon.gd", [
    ('''	level_root.bake_navigation_mesh(true)
''', '''	# Меблі, скрині, мотлох завбільшки з бочку — тверді (і на карті
	# прохідності теж: вороги їх обходять, а не застрягають).
	DungeonBuilder.add_decor_obstacles(level_root.get_node("Obstacles") as StaticBody3D, _map_rows, _chunks,
		PerfSettings.get_value("decor_density"), _theme, _props_plan.reserved)
	level_root.bake_navigation_mesh(true)
'''),
])
print("patched")
