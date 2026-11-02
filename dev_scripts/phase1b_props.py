import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:80])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


# ------------------------------------------------------------ builder
edit('scenes/dungeon/dungeon_builder.gd', [
# декоративні пастки більше не ставимо — пастки тепер справжні
('''const TRAP_SCENES := [
	preload("res://assets/models/dungeon/Trap_spikes.fbx"),
	preload("res://assets/models/dungeon/Spikes.fbx"),
]
''', ''),
('''		"treasure": TREASURE_SCENES,
		"traps": TRAP_SCENES,
	},''', '''		"treasure": TREASURE_SCENES,
	},'''),
('''		"treasure": [preload("res://assets/models/dungeon/Coin_Pile.fbx"), preload("res://assets/models/dungeon/Bag_Coins.fbx")],
		"traps": [preload("res://assets/models/dungeon/Spikes.fbx")],
	},''', '''		"treasure": [preload("res://assets/models/dungeon/Coin_Pile.fbx"), preload("res://assets/models/dungeon/Bag_Coins.fbx")],
	},'''),
('''		"treasure": [preload("res://assets/models/dungeon/Chest_Gold.fbx"), preload("res://assets/models/dungeon/Coin_Pile.fbx"), preload("res://assets/models/dungeon/Chest.fbx")],
		"traps": [preload("res://assets/models/dungeon/Trap_spikes.fbx")],
	},''', '''		"treasure": [preload("res://assets/models/dungeon/Chest_Gold.fbx"), preload("res://assets/models/dungeon/Coin_Pile.fbx"), preload("res://assets/models/dungeon/Chest.fbx")],
	},'''),
('''	if open_sides == 2 and rng.randf() < 0.12:
		_place(batcher, decor.traps[rng.randi() % decor.traps.size()], position, 0.0, 1.0)
''', ''),
# прикраси не лягають на клітинки бочок, пасток і святилищ
('''static func build_chunk(map_rows: Array, chunk: Dictionary, decor_density: float = 1.0, theme: Dictionary = DEFAULT_THEME) -> void:''',
 '''##
## reserved — клітинки під бочки, пастки й святилища (place_props): туди
## прикраси не ставимо, щоб стіл не стояв посеред святилища.
static func build_chunk(map_rows: Array, chunk: Dictionary, decor_density: float = 1.0, theme: Dictionary = DEFAULT_THEME, reserved: Dictionary = {}) -> void:'''),
('''			_add_wall_visuals(batcher, map_rows, x, z, position, decor_density, stone, decor)
			_decorate_cell(batcher, map_rows, x, z, position, rng, decor_density, decor)''',
 '''			_add_wall_visuals(batcher, map_rows, x, z, position, decor_density, stone, decor)
			if not reserved.has(Vector2i(x, z)):
				_decorate_cell(batcher, map_rows, x, z, position, rng, decor_density, decor)'''),
('''const CELL := 2.0          # розмір клітинки в метрах
const WALL_HEIGHT := 2.0
''', '''const CELL := 2.0          # розмір клітинки в метрах
const WALL_HEIGHT := 2.0
## Верх плитки підлоги: на цю висоту ставляться бочки, пастки й святилища.
const FLOOR_TOP := 0.125
'''),
('''## ТЕМНА СКЕЛЯ НАВКОЛО ЗАЛІВ''', '''## ПРЕДМЕТИ В ЗАЛАХ (ExplosiveBarrel, SpikeTrap, Shrine):
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
			keep_clear.append(_cell_of(markers[key]))

	# Бочки: поруч із ворогами, щоб було кого підірвати.
	for spawn: Dictionary in markers.spawns:
		if rng.randf() > BARREL_CHANCE:
			continue
		var origin := _cell_of(spawn.position)
		for attempt in 8:
			var cell := origin + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			if cell == origin or _near_any(cell, keep_clear, KEEP_CLEAR) or not _is_room_cell(map_rows, cell, reserved):
				continue
			reserved[cell] = true
			result.barrels.append(_cell_center(cell))
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
	_shuffle(candidates, rng)
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
			positions.append(_cell_center(c))
		result.trap_lines.append(positions)

	# Святилища: усі вісім сусідів прохідні (середина зали), далеко від
	# входу (щоб не взяти силу одразу) і від боса.
	var start := _cell_of(markers.start)
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
	_shuffle(spots, rng)
	var kinds: Array[StringName] = SHRINE_KINDS.duplicate()
	_shuffle(kinds, rng)
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
		result.shrines.append({"position": _cell_center(cell), "kind": kinds[(chosen.size() - 1) % kinds.size()]})
	return result

static func _cell_of(position: Vector3) -> Vector2i:
	return Vector2i(roundi(position.x / CELL), roundi(position.z / CELL))

static func _cell_center(cell: Vector2i) -> Vector3:
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
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap

## ТЕМНА СКЕЛЯ НАВКОЛО ЗАЛІВ'''),
])

# ------------------------------------------------------------ enemy: приціл
edit('scenes/dungeon/enemy_3d.gd', [
('''func is_alive() -> bool:
	return not _dying
''', '''func is_alive() -> bool:
	return not _dying

## Чи наводиться сюди приціл: автоприціл героя й самонавідні чари.
## Вибухова бочка — "ворог" лише для ударів, переслідувати її не треба.
func is_aim_target() -> bool:
	return not _dying
'''),
])

# ------------------------------------------------------------ player
edit('scenes/world/player_3d.gd', [
('''var _damage_taken_factor := 1.0
''', '''var _damage_taken_factor := 1.0

## СВЯТИЛИЩА ДАНЖУ (Shrine): тимчасова сила — лють (більше шкоди), вітер
## (швидше бігає й б'є) або камінь (менше шкоди по герою).
const SHRINE_FURY_DAMAGE := 1.5
const SHRINE_HASTE_SPEED := 0.3
const SHRINE_HASTE_ATTACK := 1.3
const SHRINE_GUARD_FACTOR := 0.6
var _shrine_kind := &""
var _shrine_left := 0.0
'''),
('''func grant_invulnerable(seconds: float) -> void:''', '''func add_shrine_buff(kind: StringName, seconds: float) -> void:
	_shrine_kind = kind
	_shrine_left = seconds
	if kind == &"haste":
		add_attack_speed(SHRINE_HASTE_ATTACK, seconds)

## Сила святилища, що діє зараз: {kind, left}, або порожньо.
func get_shrine_buff() -> Dictionary:
	if _shrine_left <= 0.0:
		return {}
	return {"kind": _shrine_kind, "left": _shrine_left}

func _has_shrine(kind: StringName) -> bool:
	return _shrine_left > 0.0 and _shrine_kind == kind

## Живі вороги в радіусі, на яких можна навестись (без вибухових бочок) —
## для самонавідних чар і вмінь, що самі обирають ціль.
func aim_targets_in_radius(radius: float, require_sight: bool = true) -> Array[Enemy3D]:
	var result: Array[Enemy3D] = []
	for enemy in enemies_in_radius(radius, require_sight):
		if enemy.is_aim_target():
			result.append(enemy)
	return result

func grant_invulnerable(seconds: float) -> void:'''),
('''	if _concealed_left > 0.0:
		amount *= _concealed_damage
''', '''	if _concealed_left > 0.0:
		amount *= _concealed_damage
	if _has_shrine(&"fury"):
		amount *= SHRINE_FURY_DAMAGE
'''),
('''	amount *= _damage_taken_factor
''', '''	amount *= _damage_taken_factor
	if _has_shrine(&"guard"):
		amount *= SHRINE_GUARD_FACTOR
'''),
('''	var factor := 1.0 + _speed_bonus + (_concealed_speed if _concealed_left > 0.0 else 0.0)''',
 '''	var factor := 1.0 + _speed_bonus + (_concealed_speed if _concealed_left > 0.0 else 0.0) \\
		+ (SHRINE_HASTE_SPEED if _has_shrine(&"haste") else 0.0)'''),
('''	_attack_speed_left = maxf(_attack_speed_left - delta, 0.0)
''', '''	_attack_speed_left = maxf(_attack_speed_left - delta, 0.0)
	_shrine_left = maxf(_shrine_left - delta, 0.0)
'''),
('''	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if not enemy.is_alive():
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > LOCK_RANGE:''', '''	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if not enemy.is_aim_target():
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > LOCK_RANGE:'''),
])

# ------------------------------------------------------------ чари й уміння: лише справжні цілі
edit('scenes/combat/spells_3d.gd', [
('''	for enemy: Enemy3D in player.enemies_in_radius(LIGHTNING_RANGE):
		if enemy != target and enemy.global_position.distance_to(target.global_position) < 6.0:''',
 '''	for enemy: Enemy3D in player.aim_targets_in_radius(LIGHTNING_RANGE):
		if enemy != target and enemy.global_position.distance_to(target.global_position) < 6.0:'''),
('''	for enemy: Enemy3D in player.enemies_in_radius(LIGHTNING_RANGE):
		var offset: Vector3 = enemy.global_position - player.global_position''',
 '''	for enemy: Enemy3D in player.aim_targets_in_radius(LIGHTNING_RANGE):
		var offset: Vector3 = enemy.global_position - player.global_position'''),
])
edit('scenes/combat/skills/arcane_barrage.gd', [
('''	var enemies: Array[Enemy3D] = player.enemies_in_radius(RADIUS)''',
 '''	var enemies: Array[Enemy3D] = player.aim_targets_in_radius(RADIUS)'''),
])
edit('scenes/combat/skills/moon_storm.gd', [
('''	var enemies: Array[Enemy3D] = player.enemies_in_radius(RADIUS, false)''',
 '''	var enemies: Array[Enemy3D] = player.aim_targets_in_radius(RADIUS, false)'''),
])

# ------------------------------------------------------------ dungeon
edit('scenes/dungeon/dungeon.gd', [
('''## ВІДЧУТТЯ ВБИВСТВА.''', '''## ПРЕДМЕТИ В ЗАЛАХ: сила вибуху бочки й удару шипів — з силою рівня
## (по ворогах множиться на їхнє здоров'я, по герою — на шкоду рівня).
const BARREL_BLAST := 45.0
const BARREL_HERO_DAMAGE := 12.0
const TRAP_ENEMY_DAMAGE := 22.0
const TRAP_HERO_DAMAGE := 10.0

## ВІДЧУТТЯ ВБИВСТВА.'''),
('''var _loot: LootSwarm
''', '''var _loot: LootSwarm
## Розкладка бочок, пасток і святилищ (DungeonBuilder.place_props).
var _props_plan: Dictionary = {}
var _shrine_label: Label
'''),
('''	var markers := DungeonBuilder.build_base(level.map, level_root, _theme)
''', '''	var markers := DungeonBuilder.build_base(level.map, level_root, _theme)
	# Де стоятимуть бочки, пастки й святилища — до збирання шматків, щоб
	# прикраси не лягли на ті самі клітинки.
	_props_plan = DungeonBuilder.place_props(level.map, markers, 7919 * (_level_index + 1),
		1 if _level_index == 0 else 2)
'''),
('''			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"), _theme)''',
 '''			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"), _theme,
				_props_plan.get("reserved", {}))'''),
('''	_spawn_enemies(markers)
''', '''	_spawn_enemies(markers)
	_spawn_props()
'''),
('''func _spawn_enemy(position: Vector3, definition: Dictionary, is_boss: bool) -> Enemy3D:''', '''## Вибухові бочки, шипи й святилища — там, де їх розклав place_props.
func _spawn_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	var floor_top := Vector3(0, DungeonBuilder.FLOOR_TOP, 0)
	for position: Vector3 in _props_plan.barrels:
		var barrel := ExplosiveBarrel.new()
		barrel.collision_layer = 4
		barrel.collision_mask = 0
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.5
		cylinder.height = ExplosiveBarrel.HEIGHT
		shape.shape = cylinder
		shape.position.y = ExplosiveBarrel.HEIGHT * 0.5
		barrel.add_child(shape)
		props.add_child(barrel)
		barrel.global_position = position + floor_top
		barrel.setup(player, null)
		barrel.blast_damage = BARREL_BLAST * _hp_scale
		barrel.hero_damage = BARREL_HERO_DAMAGE * _damage_scale
	var line_index := 0
	for line: Array in _props_plan.trap_lines:
		line_index += 1
		# Плити одного рядка б'ють разом, різні рядки — зі зсувом.
		var phase := 1.0 + 0.7 * line_index
		for position: Vector3 in line:
			var trap := SpikeTrap.new()
			props.add_child(trap)
			trap.global_position = position + floor_top
			trap.setup(player, phase, 1000 + line_index)
			trap.enemy_damage = TRAP_ENEMY_DAMAGE * _hp_scale
			trap.hero_damage = TRAP_HERO_DAMAGE * _damage_scale
	for plan: Dictionary in _props_plan.shrines:
		var shrine := Shrine.new()
		shrine.setup(player, plan.kind)
		props.add_child(shrine)
		shrine.global_position = plan.position + floor_top

func _spawn_enemy(position: Vector3, definition: Dictionary, is_boss: bool) -> Enemy3D:'''),
('''	_xp_bar = UiTheme.make_bar(UiTheme.HEADING, Vector2(300, 7))
	column.add_child(_xp_bar)
''', '''	_xp_bar = UiTheme.make_bar(UiTheme.HEADING, Vector2(300, 7))
	column.add_child(_xp_bar)

	# Сила святилища, поки діє: назва й скільки секунд лишилось.
	_shrine_label = Label.new()
	UiTheme.hud_text(_shrine_label, 15)
	_shrine_label.visible = false
'''),
('''	_buff_bar = HFlowContainer.new()
	_buff_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE''', '''	corner.add_child(_shrine_label)
	_buff_bar = HFlowContainer.new()
	_buff_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE'''),
('''func _process(delta: float) -> void:
	_stream_left -= delta''', '''func _process(delta: float) -> void:
	_update_shrine_label()
	_stream_left -= delta'''),
('''## Будує те, що попереду, ховає те, що позаду, і присипляє далеких''', '''func _update_shrine_label() -> void:
	var buff: Dictionary = player.get_shrine_buff()
	var text := ""
	if not buff.is_empty():
		var info: Dictionary = Shrine.KINDS[buff.kind]
		text = "%s — ще %d с" % [info.title, ceili(buff.left)]
		_shrine_label.add_theme_color_override("font_color", info.color)
	if text != _shrine_label.text:
		_shrine_label.text = text
		_shrine_label.visible = text != ""

## Будує те, що попереду, ховає те, що позаду, і присипляє далеких'''),
('''	var models: Array = [EXIT_SCENE]''', '''	var models: Array = [EXIT_SCENE, ExplosiveBarrel.BARREL_SCENE, SpikeTrap.PLATE_SCENE,
		SpikeTrap.SPIKES_SCENE, Shrine.PEDESTAL_SCENE]'''),
])
print('ok')
