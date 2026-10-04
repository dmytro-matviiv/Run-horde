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
## Верх плитки підлоги: на цю висоту ставляться бочки, пастки й святилища.
const FLOOR_TOP := 0.125

## Верх скелі навколо залів — трохи нижче за верх стін, щоб гребінь стіни
## лишався видно й кімната читалась вирубаною в камені.
const ROCK_TOP_HEIGHT := WALL_HEIGHT - 0.03
## На скільки клітинок скеля виходить за край карти: край рівня теж не
## має виглядати проваллям.
const ROCK_MARGIN := 12
## Скільки метрів займає один повтор текстури каменю.
const ROCK_TEXTURE_METERS := 7.0
const ROCK_TEXTURE := preload("res://assets/textures/rock_top.png")
## Колір верху скелі до відтінку теми: темний, як камінь у тіні.
const ROCK_COLOR := Color(0.17, 0.16, 0.15)
## Яскравість скелі за відстанню до найближчої підлоги (у клітинках):
## біля залу камінь ледь видно, за кілька клітинок — майже темрява.
const ROCK_FADE := [1.0, 0.6, 0.34, 0.18, 0.08]

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
## Гігантський гриб (модель гравця, ~4.7 тис. трикутників, одна текстура
## 1024): у грибних нетрях стоїть замість колон, а зменшені копії ростуть
## попід стінами. Пластинки світяться власним кольором — без джерел світла.
const MUSHROOM_GIANT_SCENE := preload("res://assets/models/fungal/mushroom_giant.glb")
## Частка клітинок попід стінами з грибочками й їхній розмір (від гриба-колони).
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

## ПРИКРАСИ ПІД ТЕМУ РІВНЯ. Склепи захаращені бочками й скринями,
## грибні печери — порожні, у павутинні й черепах, цитадель — з
## прапорами, зброєю на стінах і золотом. Моделі ті самі, набір різний.
const DECOR_SETS := {
	"crypt": {
		"clutter": CLUTTER_SCENES,
		"wall": WALL_DECOR_SCENES,
		"furniture": FURNITURE_SCENES,
		"treasure": TREASURE_SCENES,
	},
	## Грибні нетрі — своя архітектура: замість кам'яних колон у залах
	## стоять гігантські гриби (column), попід стінами — грибочки (cover).
	## Грибні нетрі — своя архітектура з набору гравця (DungeonKit,
	## assets/models/fungal/kit, легкі версії — process_dungeon_kit.py):
	## моховита кладка з корінням і слизом, плити з тріщинами, що світяться,
	## у залах — то гриб-велетень, то колона з набору. Нічого з першого данжу,
	## крім павутиння, черепів і скарбів. Свій арт не фарбується під камінь.
	"fungal": {
		"keep_colors": true,
		"floor_tiles": FUNGAL_FLOORS,
		"wall_tiles": FUNGAL_WALLS,
		## Лице стіни набору — на 0.25 м усередині клітинки (а не на межі).
		"wall_inset": 0.25,
		"columns": [
			## Шапка ~2.5 м завширшки — перешкода ширша, щоб під шапкою не
			## ховались від камери згори.
			{"scene": MUSHROOM_GIANT_SCENE, "scale": 1.25, "obstacle": 1.8, "weight": 0.6},
			{"scene": FUNGAL_COLUMN_SCENE, "scale": 1.0, "obstacle": 0.8, "weight": 0.4},
		],
		"cover": MUSHROOM_GIANT_SCENE,
		"cover_scale": Vector2(0.26, 0.42),
		"clutter": [preload("res://assets/models/dungeon/Skull.fbx")],
		## Черепи — єдиний дрібний мотлох тут, тож рідше, ніж бочки в склепах.
		"clutter_chance": 0.1,
		"wall": [preload("res://assets/models/dungeon/Cobweb.fbx"), preload("res://assets/models/dungeon/Cobweb2.fbx")],
		"furniture": [FUNGAL_RUBBLE_SCENE],
		"treasure": [preload("res://assets/models/dungeon/Coin_Pile.fbx"), preload("res://assets/models/dungeon/Bag_Coins.fbx")],
	},
	## Потонулі сади — поки той самий набір, що й у грибних нетрях, але
	## без грибів: гриби — архітектура саме нетрів.
	"sunken": {
		"clutter": [
			preload("res://assets/models/dungeon/Skull.fbx"), preload("res://assets/models/dungeon/Vase.fbx"), preload("res://assets/models/dungeon/Brick.fbx"),
			preload("res://assets/models/dungeon/Bucket.fbx"), preload("res://assets/models/dungeon/Skull.fbx"),
		],
		"wall": [preload("res://assets/models/dungeon/Cobweb.fbx"), preload("res://assets/models/dungeon/Cobweb2.fbx"), preload("res://assets/models/dungeon/Decorative_Wall.fbx")],
		"furniture": [preload("res://assets/models/dungeon/Woodfire.fbx"), preload("res://assets/models/dungeon/Pedestal.fbx")],
		"treasure": [preload("res://assets/models/dungeon/Coin_Pile.fbx"), preload("res://assets/models/dungeon/Bag_Coins.fbx")],
	},
	"citadel": {
		"clutter": [preload("res://assets/models/dungeon/Crate.fbx"), preload("res://assets/models/dungeon/Barrel2.fbx"), preload("res://assets/models/dungeon/Chair.fbx")],
		"wall": [
			preload("res://assets/models/dungeon/Banner_wall.fbx"), preload("res://assets/models/dungeon/Sword_WallMount.fbx"),
			preload("res://assets/models/dungeon/Decorative_Wall.fbx"), preload("res://assets/models/dungeon/Banner_wall.fbx"),
		],
		"furniture": [preload("res://assets/models/dungeon/Table_Big.fbx"), preload("res://assets/models/dungeon/Pedestal2.fbx"), preload("res://assets/models/dungeon/Woodfire.fbx")],
		"treasure": [preload("res://assets/models/dungeon/Chest_Gold.fbx"), preload("res://assets/models/dungeon/Coin_Pile.fbx"), preload("res://assets/models/dungeon/Chest.fbx")],
	},
	## Нижче — п'ять нових тем (рівні 4-8): моделі з Halloween Bits (Kay
	## Lousberg), Medieval Village Pack і Ultimate RPG Items Bundle
	## (Quaternius), розібраної кузні Forge Parts (Don Carson) — усі CC0,
	## крім кузні (CC BY 3.0, є в credits.gd).
	"graveyard": {
		"clutter": [
			preload("res://assets/models/graveyard/skull.glb"), preload("res://assets/models/graveyard/bone.glb"),
			preload("res://assets/models/graveyard/candle_melted.glb"), preload("res://assets/models/graveyard/grave_marker.glb"),
			preload("res://assets/models/graveyard/rocks.glb"),
		],
		"wall": [
			preload("res://assets/models/graveyard/candles.glb"), preload("res://assets/models/graveyard/skull_candle.glb"),
			preload("res://assets/models/graveyard/bone.glb"),
		],
		"furniture": [
			preload("res://assets/models/graveyard/shrine.glb"), preload("res://assets/models/graveyard/coffin.glb"),
			preload("res://assets/models/graveyard/dead_tree_small.glb"),
		],
		"treasure": [
			preload("res://assets/models/graveyard/coffin_open.glb"), preload("res://assets/models/graveyard/grave.glb"),
			preload("res://assets/models/graveyard/gravestone.glb"),
		],
	},
	"forge": {
		"clutter": [
			preload("res://assets/models/village/crate.glb"), preload("res://assets/models/village/barrel.glb"),
			preload("res://assets/models/forge/forge_barrel.tscn"), preload("res://assets/models/forge/forge_tub.tscn"),
		],
		"wall": WALL_DECOR_SCENES,
		"furniture": [
			preload("res://assets/models/forge/forge_hearth.tscn"), preload("res://assets/models/forge/forge_anvil.tscn"),
			preload("res://assets/models/forge/forge_bench.tscn"), preload("res://assets/models/forge/forge_cage.tscn"),
			preload("res://assets/models/forge/forge_grindstone.tscn"),
		],
		"treasure": [
			preload("res://assets/models/treasure/chest.glb"), preload("res://assets/models/treasure/gold_ingots.glb"),
			preload("res://assets/models/treasure/sword.glb"),
		],
	},
	"vault": {
		"clutter": [
			preload("res://assets/models/treasure/coin_pouch.glb"), preload("res://assets/models/treasure/mineral.glb"),
			preload("res://assets/models/treasure/scroll.glb"), preload("res://assets/models/treasure/potion.glb"),
		],
		"wall": [preload("res://assets/models/treasure/scroll.glb"), preload("res://assets/models/dungeon/Banner_wall.fbx")],
		"furniture": [
			preload("res://assets/models/treasure/chest.glb"), preload("res://assets/models/treasure/armor_golden.glb"),
			preload("res://assets/models/graveyard/pillar.glb"),
		],
		"treasure": [
			preload("res://assets/models/treasure/chest.glb"), preload("res://assets/models/treasure/gold_ingots.glb"),
			preload("res://assets/models/treasure/chalice.glb"), preload("res://assets/models/treasure/crown.glb"),
		],
	},
	"village": {
		"clutter": [
			preload("res://assets/models/village/crate.glb"), preload("res://assets/models/village/barrel.glb"),
			preload("res://assets/models/village/hay.glb"), preload("res://assets/models/village/bags.glb"),
			preload("res://assets/models/village/package.glb"),
		],
		"wall": WALL_DECOR_SCENES,
		"furniture": [
			preload("res://assets/models/village/cart.glb"), preload("res://assets/models/village/well.glb"),
			preload("res://assets/models/village/bonfire.glb"), preload("res://assets/models/village/cauldron.glb"),
		],
		"treasure": [
			preload("res://assets/models/village/bags.glb"), preload("res://assets/models/treasure/chest.glb"),
			preload("res://assets/models/treasure/coin_pouch.glb"),
		],
	},
	"abyss": {
		"clutter": [
			preload("res://assets/models/graveyard/bone.glb"), preload("res://assets/models/graveyard/skull.glb"),
			preload("res://assets/models/graveyard/ribcage.glb"), preload("res://assets/models/treasure/mineral.glb"),
		],
		"wall": [preload("res://assets/models/graveyard/candles.glb"), preload("res://assets/models/graveyard/skull_candle.glb")],
		"furniture": [preload("res://assets/models/graveyard/shrine.glb"), preload("res://assets/models/treasure/chest.glb")],
		"treasure": [
			preload("res://assets/models/treasure/chest.glb"), preload("res://assets/models/treasure/gold_ingots.glb"),
			preload("res://assets/models/treasure/crown.glb"),
		],
	},
}

## Усі моделі, з яких збирається данж (для прогріву графіки).
static func all_decor_scenes() -> Array:
	var scenes: Array = [FLOOR_SCENE, FLOOR_BRICKS_SCENE, WALL_SCENE, TORCH_SCENE, COLUMN_SCENE]
	for set_name: String in DECOR_SETS:
		for group: String in DECOR_SETS[set_name]:
			# Група — список моделей, окрема модель (column, cover) або число
			# (масштаб) — числа пропускаємо.
			for scene in _scenes_in(DECOR_SETS[set_name][group]):
				if not scenes.has(scene):
					scenes.append(scene)
	return scenes

## Усі моделі в групі набору прикрас: список моделей, окрема модель,
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

## Символи, по яких можна ходити: підлога, вхід/вихід/бос і всі мітки
## ворогів (m r w x c t).
const WALKABLE := [".", "S", "B", "E", "m", "r", "w", "x", "c", "t"]
const ENEMY_SYMBOLS := ["m", "r", "w", "x", "c", "t"]

## Тема за замовчуванням — якщо рівень її не задав.
const DEFAULT_THEME := {
	"stone": Color.WHITE, "floor": Color.WHITE, "torch": Color(1.0, 0.72, 0.38), "decor": "crypt",
}

## Створює те, що має існувати одразу: мітки, перешкоди, світло і
## порожні вузли-шматки. Геометрію шматків будує вже streamer.
##
## Повертає {"start", "exit", "boss", "spawns", "chunks", "lights"};
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
	var decor: Dictionary = DECOR_SETS.get(theme.get("decor", "crypt"), DECOR_SETS.crypt)
	_add_column_obstacles(obstacles, map_rows, decor)
	_create_chunks(parent, map_rows, result)
	_add_rock_top(parent, map_rows, theme)
	return result

## ПРЕДМЕТИ В ЗАЛАХ (ExplosiveBarrel, SpikeTrap, Shrine):
##   бочки     — біля міток ворогів, на клітинках зали, не в коридорі;
##   пастки    — рядком поперек коридору: плити одного рядка б'ють разом;
##   святилища — посеред великих зал, подалі від входу й боса.
## Розкладка залежить лише від карти й насіння: той самий рівень щоразу
## виглядає однаково. reserved — зайняті клітинки (для прикрас).
const BARREL_CHANCE := 0.4
const MAX_TRAP_LINES := 4
## Відстань між рядками пасток і між святилищами, у клітинках.
const TRAP_SPACING := 5
const SHRINE_SPACING := 10
## Стільки клітинок довкола входу, виходу й боса лишаються вільними.
const KEEP_CLEAR := 3
const SHRINE_KINDS: Array[StringName] = [&"fury", &"haste", &"guard", &"life"]

static func place_props(map_rows: Array, markers: Dictionary, level_seed: int, shrine_count: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	var result := {"barrels": [], "trap_lines": [], "shrines": [], "reserved": {}}
	var reserved: Dictionary = result.reserved
	var keep_clear: Array[Vector2i] = []
	for key: String in ["start", "exit", "boss"]:
		if markers[key] != Vector3.ZERO:
			keep_clear.append(cell_of(markers[key]))

	# Бочки: поруч із ворогами, щоб було кого підірвати.
	for spawn: Dictionary in markers.spawns:
		if rng.randf() > BARREL_CHANCE:
			continue
		var origin := cell_of(spawn.position)
		for attempt in 8:
			var cell := origin + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			if cell == origin or _near_any(cell, keep_clear, KEEP_CLEAR) or not _is_room_cell(map_rows, cell, reserved):
				continue
			reserved[cell] = true
			result.barrels.append(cell_center(cell))
			break

	# Пастки: коридор — поперек не більше двох прохідних клітинок, уздовж
	# щонайменше чотири. Рядок плит перекриває коридор на всю ширину.
	var candidates: Array[Dictionary] = []
	for z in map_rows.size():
		var row: String = map_rows[z]
		for x in row.length():
			var cell := Vector2i(x, z)
			if not _is_walkable(map_rows, x, z) or _near_any(cell, keep_clear, KEEP_CLEAR):
				continue
			var run_x := _run_length(map_rows, cell, Vector2i(1, 0))
			var run_z := _run_length(map_rows, cell, Vector2i(0, 1))
			if run_x <= 2 and run_z >= 4:
				candidates.append({"cell": cell, "across": Vector2i(1, 0)})
			elif run_z <= 2 and run_x >= 4:
				candidates.append({"cell": cell, "across": Vector2i(0, 1)})
	shuffle(candidates, rng)
	var trap_cells: Array[Vector2i] = []
	for candidate: Dictionary in candidates:
		if result.trap_lines.size() >= MAX_TRAP_LINES:
			break
		var cell: Vector2i = candidate.cell
		if _near_any(cell, trap_cells, TRAP_SPACING):
			continue
		var line: Array[Vector2i] = [cell]
		for side: int in [-1, 1]:
			var probe: Vector2i = cell + candidate.across * side
			while _is_walkable(map_rows, probe.x, probe.y):
				line.append(probe)
				probe += candidate.across * side
		if line.any(func(c: Vector2i) -> bool: return reserved.has(c)):
			continue
		var positions: Array[Vector3] = []
		for c in line:
			reserved[c] = true
			trap_cells.append(c)
			positions.append(cell_center(c))
		result.trap_lines.append(positions)

	# Святилища: усі вісім сусідів прохідні (середина зали), далеко від
	# входу (щоб не взяти силу одразу) і від боса.
	var start := cell_of(markers.start)
	var spots: Array[Vector2i] = []
	for z in map_rows.size():
		var row: String = map_rows[z]
		for x in row.length():
			var cell := Vector2i(x, z)
			if not _is_room_cell(map_rows, cell, reserved) or _near_any(cell, keep_clear, KEEP_CLEAR + 2):
				continue
			if maxi(absi(cell.x - start.x), absi(cell.y - start.y)) < 8:
				continue
			if _count_open_neighbours(map_rows, cell) == 8:
				spots.append(cell)
	shuffle(spots, rng)
	var kinds: Array[StringName] = SHRINE_KINDS.duplicate()
	shuffle(kinds, rng)
	var chosen: Array[Vector2i] = []
	for cell in spots:
		if chosen.size() >= shrine_count:
			break
		if _near_any(cell, chosen, SHRINE_SPACING):
			continue
		chosen.append(cell)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				reserved[cell + Vector2i(dx, dz)] = true
		result.shrines.append({"position": cell_center(cell), "kind": kinds[(chosen.size() - 1) % kinds.size()]})
	return result

## Клітинка карти під точкою світу.
static func cell_of(position: Vector3) -> Vector2i:
	return Vector2i(roundi(position.x / CELL), roundi(position.z / CELL))

## Середина клітинки карти у світі (на рівні нуля, не верху підлоги).
static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0.0, cell.y * CELL)

## Скільки прохідних клітинок поспіль уздовж осі через цю клітинку.
static func _run_length(map_rows: Array, cell: Vector2i, axis: Vector2i) -> int:
	var count := 1
	for side: int in [-1, 1]:
		var probe := cell + axis * side
		while _is_walkable(map_rows, probe.x, probe.y):
			count += 1
			probe += axis * side
	return count

static func _count_open_neighbours(map_rows: Array, cell: Vector2i) -> int:
	var count := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dz != 0) and _is_walkable(map_rows, cell.x + dx, cell.y + dz):
				count += 1
	return count

static func _near_any(cell: Vector2i, cells: Array[Vector2i], distance: int) -> bool:
	for other in cells:
		if maxi(absi(cell.x - other.x), absi(cell.y - other.y)) <= distance:
			return true
	return false

## Клітинка всередині зали: прохідна, не колона, не зайнята, і зала тут
## ширша за коридор в обидва боки.
static func _is_room_cell(map_rows: Array, cell: Vector2i, reserved: Dictionary) -> bool:
	if not _is_walkable(map_rows, cell.x, cell.y) or reserved.has(cell):
		return false
	if _is_column_cell(map_rows, map_rows[cell.y], cell.x, cell.y):
		return false
	return _run_length(map_rows, cell, Vector2i(1, 0)) >= 3 and _run_length(map_rows, cell, Vector2i(0, 1)) >= 3

## Перемішати масив генератором рівня — детерміновано.
static func shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap

## ТЕМНА СКЕЛЯ НАВКОЛО ЗАЛІВ
##
## Камера дивиться на данж згори, а стіни — по пояс. Раніше за ними була
## порожнеча: чорні провалля між залами, що різали око. Тепер над кожною
## непрохідною клітинкою (і ще трохи за краєм карти) лежить темний камінь
## на висоті верху стін — зали читаються як вирубані в скелі. Біля залу
## камінь ледь видно, а далі від нього він плавно тоне в темряві
## (ROCK_FADE), тож далекі зали не відволікають.
##
## Це ОДИН меш на весь рівень і один виклик малювання. Камінь не
## освітлюється (unshaded): смолоскипам не треба його рахувати.
static func _add_rock_top(parent: Node3D, map_rows: Array, theme: Dictionary) -> void:
	var width := 0
	for row: String in map_rows:
		width = maxi(width, row.length())
	var cols := width + ROCK_MARGIN * 2
	var rows := map_rows.size() + ROCK_MARGIN * 2
	var distance := _rock_distances(map_rows, cols, rows)

	# Сітка вершин по кутах клітинок: сусідні клітинки ділять вершини, а
	# колір вершини — найсвітліший із чотирьох клітинок довкола. Так
	# згасання плавне, без сходинок.
	var half := CELL * 0.5
	var vertex_cols := cols + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for gz in rows + 1:
		for gx in vertex_cols:
			var corner := Vector3((gx - ROCK_MARGIN) * CELL - half, ROCK_TOP_HEIGHT, (gz - ROCK_MARGIN) * CELL - half)
			vertices.append(corner)
			normals.append(Vector3.UP)
			uvs.append(Vector2(corner.x, corner.z) / ROCK_TEXTURE_METERS)
			var shade := 0.0
			for cz in [gz - 1, gz]:
				for cx in [gx - 1, gx]:
					if cx >= 0 and cz >= 0 and cx < cols and cz < rows and distance[cz * cols + cx] > 0:
						shade = maxf(shade, _rock_shade(distance[cz * cols + cx]))
			# Легкі плями світлішого й темнішого каменю: без них на великій
			# площі помітно, що текстура повторюється.
			shade *= 0.8 + 0.4 * _hash01(gx, gz, 29)
			colors.append(Color(shade, shade, shade))
	var indices := PackedInt32Array()
	for z in rows:
		for x in cols:
			if distance[z * cols + x] == 0:
				continue
			var top_left := z * vertex_cols + x
			var bottom_left := top_left + vertex_cols
			indices.append(top_left)
			indices.append(top_left + 1)
			indices.append(bottom_left + 1)
			indices.append(top_left)
			indices.append(bottom_left + 1)
			indices.append(bottom_left)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = ROCK_TEXTURE
	material.albedo_color = ROCK_COLOR * theme.get("stone", Color.WHITE)
	# Згори видно лише один бік, але так не залежимо від порядку вершин.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rock := MeshInstance3D.new()
	rock.name = "RockTop"
	rock.mesh = mesh
	rock.material_override = material
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rock)

## Відстань кожної клітинки (з полями ROCK_MARGIN) до найближчої підлоги,
## у клітинках, хвилею від підлоги назовні. 0 — сама підлога; далі
## за ROCK_FADE.size() хвиля не йде.
static func _rock_distances(map_rows: Array, cols: int, rows: int) -> PackedInt32Array:
	var distance := PackedInt32Array()
	distance.resize(cols * rows)
	distance.fill(ROCK_FADE.size())
	var frontier: Array[Vector2i] = []
	for z in rows:
		for x in cols:
			if _is_walkable(map_rows, x - ROCK_MARGIN, z - ROCK_MARGIN):
				distance[z * cols + x] = 0
				frontier.append(Vector2i(x, z))
	var step := 0
	while not frontier.is_empty() and step < ROCK_FADE.size() - 1:
		step += 1
		var next: Array[Vector2i] = []
		for cell in frontier:
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nx := cell.x + dx
					var nz := cell.y + dz
					if nx < 0 or nz < 0 or nx >= cols or nz >= rows:
						continue
					if distance[nz * cols + nx] > step:
						distance[nz * cols + nx] = step
						next.append(Vector2i(nx, nz))
		frontier = next
	return distance

static func _rock_shade(distance: int) -> float:
	return ROCK_FADE[mini(distance, ROCK_FADE.size()) - 1]

## Будує видиму геометрію одного шматка. Викликається тоді, коли гравець
## до нього підходить, — і саме тому вхід у данж не гальмує: спершу
## збирається лише найближче.
##
## decor_density — частка дрібних прикрас (1.0 — усі). На слабкому
## телефоні бочок і павутиння менше, але стіни, скрині й колони ті самі:
## рівень упізнаваний на будь-якій якості.
##
## reserved — клітинки під бочки, пастки й святилища (place_props): туди
## прикраси не ставимо, щоб стіл не стояв посеред святилища.
static func build_chunk(map_rows: Array, chunk: Dictionary, decor_density: float = 1.0, theme: Dictionary = DEFAULT_THEME, reserved: Dictionary = {}) -> void:
	if chunk.built:
		return
	chunk.built = true

	var batcher := MeshBatcher.new()
	var stone: Color = theme.get("stone", Color.WHITE)
	var floor_color: Color = theme.get("floor", Color.WHITE)
	var decor: Dictionary = DECOR_SETS.get(theme.get("decor", "crypt"), DECOR_SETS.crypt)
	# Прикраси фарбуємо слабше за камінь: скриня в крижаній цитаделі має
	# бути ледь інеєва, а не синя.
	batcher.tint = Color.WHITE.lerp(stone, 0.5)
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
			_add_floor(batcher, x, z, position, floor_color, decor)
			if _is_column_cell(map_rows, row, x, z):
				# На клітинці з колоною більше нічого не ставимо — інакше
				# стіл чи скриня стирчали б просто з колони.
				_add_column(batcher, x, z, position, stone, decor)
				continue
			_add_wall_visuals(batcher, map_rows, x, z, position, decor_density, stone, decor)
			if not reserved.has(Vector2i(x, z)):
				_decorate_cell(batcher, map_rows, x, z, position, rng, decor_density, decor)

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
		_:
			if ENEMY_SYMBOLS.has(symbol):
				result.spawns.append({"symbol": symbol, "position": position})

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
			result.lights.append(_add_light(parent, torch_position, result.torch_color))
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

static func _add_light(parent: Node3D, position: Vector3, color: Color) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
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

## Ширина перешкоди — від моделі колони на цій клітинці (_column_variant):
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
	return variants[-1]

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

## Плитка підлоги. Тема з набором плиток ("floor_tiles") — випадкова
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

		if (x + z) % TORCH_EVERY == 0 and offset.y != 0:
			var torch_position := wall_position - Vector3(offset.x, 0.0, offset.y) * maxf(0.35, inset + 0.1) + Vector3(0, 0.6, 0)
			batcher.add(TORCH_SCENE, Transform3D(Basis(Vector3.UP, directions[offset]), torch_position))

		if _chance(3, x, z, offset) and _hash01(x, z, 11) < decor_density:
			var decor_position := position + Vector3(0, 1.3, 0) \
				+ Vector3(offset.x, 0.0, offset.y) * (CELL * 0.5 - maxf(0.15, inset + 0.03))
			var wall_set: Array = decor.wall
			var ornament: PackedScene = wall_set[(x * 7 + z * 13 + offset.x + offset.y) % wall_set.size()]
			batcher.add(ornament, Transform3D(Basis(Vector3.UP, directions[offset]), decor_position), Color.WHITE, keep_colors)

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

## Колона в залі. Тема може підмінити її своєю архітектурою (у грибних
## нетрях — гігантський гриб): та сама клітинка й та сама перешкода, лише
## інша модель, повернута по-різному й у власних кольорах.
static func _add_column(batcher: MeshBatcher, x: int, z: int, position: Vector3, stone: Color, decor: Dictionary) -> void:
	var variant := _column_variant(decor, x, z)
	var column: PackedScene = variant.scene
	if column == COLUMN_SCENE:
		batcher.add(COLUMN_SCENE, Transform3D(Basis(), position), stone)
		return
	var size: float = variant.get("scale", 1.0) * lerpf(0.92, 1.08, _hash01(x, z, 12))
	var basis := Basis(Vector3.UP, _hash01(x, z, 11) * TAU).scaled(Vector3.ONE * size)
	batcher.add(column, Transform3D(basis, position), Color.WHITE, true)

## Грибочки попід стіною: зменшені копії гриба-колони, по одному-два,
## зсунуті до стіни, щоб не стояти на проході. Випадковість — з координат
## клітинки (_hash01), а не з rng: інакше зсунулися б усі інші прикраси.
static func _add_cover(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, decor: Dictionary) -> void:
	var toward_wall := Vector3.ZERO
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if not _is_walkable(map_rows, x + offset.x, z + offset.y):
			toward_wall += Vector3(offset.x, 0.0, offset.y)
	if toward_wall == Vector3.ZERO:
		return
	toward_wall = toward_wall.normalized()
	var side := Vector3(-toward_wall.z, 0.0, toward_wall.x)
	var sizes: Vector2 = decor.get("cover_scale", Vector2(0.3, 0.4))
	var count := 1 + int(_hash01(x, z, 14) < 0.45)
	for i in count:
		var along := lerpf(-0.45, 0.45, _hash01(x, z, 15 + i))
		var spot := position + toward_wall * CELL * 0.3 + side * along * CELL * 0.5
		var size := lerpf(sizes.x, sizes.y, _hash01(x, z, 17 + i)) * (0.7 if i == 1 else 1.0)
		var basis := Basis(Vector3.UP, _hash01(x, z, 19 + i) * TAU).scaled(Vector3.ONE * size)
		batcher.add(decor.cover, Transform3D(basis, spot), Color.WHITE, true)

## Оздоблення клітинки: мотлох попід стінами, меблі посеред залів,
## скрині по кутах, пастки у вузьких місцях.
static func _decorate_cell(batcher: MeshBatcher, map_rows: Array, x: int, z: int, position: Vector3, rng: RandomNumberGenerator, decor_density: float, decor: Dictionary) -> void:
	if map_rows[z][x] == "S":
		return   # вхідна зала лишається чистою
	var open_sides := _count_open_sides(map_rows, x, z)
	var small_decor := _hash01(x, z, 5) < decor_density
	if decor.has("cover") and open_sides <= 3 and small_decor and _hash01(x, z, 13) < COVER_CHANCE:
		_add_cover(batcher, map_rows, x, z, position, decor)

	var keep_colors: bool = decor.get("keep_colors", false)
	if open_sides <= 3 and rng.randf() < decor.get("clutter_chance", 0.3) and small_decor:
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
	batcher.add(scene, Transform3D(basis, position), Color.WHITE, keep_colors)

static func _count_open_sides(map_rows: Array, x: int, z: int) -> int:
	var count := 0
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if _is_walkable(map_rows, x + offset.x, z + offset.y):
			count += 1
	return count

## Чи можна ходити клітинкою (x, z). За межами карти — ні.
static func is_walkable(map_rows: Array, x: int, z: int) -> bool:
	return _is_walkable(map_rows, x, z)

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
