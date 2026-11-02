import io
import os
import re

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:80])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


# ------------------------------------------------------------ builder: публічні помічники
p = 'scenes/dungeon/dungeon_builder.gd'
s = io.open(p, encoding='utf-8').read()
s = re.sub(r'\b_shuffle\(', 'shuffle(', s)
s = re.sub(r'\b_cell_of\(', 'cell_of(', s)
s = re.sub(r'\b_cell_center\(', 'cell_center(', s)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
edit(p, [
('''static func _is_walkable(map_rows: Array, x: int, z: int) -> bool:''',
 '''## Чи можна ходити клітинкою (x, z). За межами карти — ні.
static func is_walkable(map_rows: Array, x: int, z: int) -> bool:
	return _is_walkable(map_rows, x, z)

static func _is_walkable(map_rows: Array, x: int, z: int) -> bool:'''),
('''static func cell_of(position: Vector3) -> Vector2i:''',
 '''## Клітинка карти під точкою світу.
static func cell_of(position: Vector3) -> Vector2i:'''),
('''static func cell_center(cell: Vector2i) -> Vector3:''',
 '''## Середина клітинки карти у світі (на рівні нуля, не верху підлоги).
static func cell_center(cell: Vector2i) -> Vector3:'''),
])

# ------------------------------------------------------------ enemy: поява з-під підлоги
edit('scenes/dungeon/enemy_3d.gd', [
('''## Чи наводиться сюди приціл: автоприціл героя й самонавідні чари.''',
 '''## Помітити героя одразу, хоч би де він був (засідка).
func alert() -> void:
	_aggro = true
	_repath_left = 0.0

## Вилізти з-під підлоги (засідка): модель підіймається з порталу, а
## ворог тим часом стоїть і не б'є. Потім одразу йде на героя.
func emerge(seconds: float) -> void:
	var rest := _model.position.y
	_model.position.y = rest - target_height - 0.3
	var tween := create_tween()
	tween.tween_property(_model, "position:y", rest, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hold_still(seconds)
	alert()

## Чи наводиться сюди приціл: автоприціл героя й самонавідні чари.'''),
])

# ------------------------------------------------------------ якість: засідки
edit('scripts/autoload/perf_settings.gd', [
('''##   enemy_awake      — далі за цю відстань ворог спить.
''', '''##   enemy_awake      — далі за цю відстань ворог спить.
##   arena_max_enemies — скільки ворогів засідки живуть одночасно (решта
##                      хвилі чекає черги).
##   horde_size       — скільки дрібноти в орді засідки.
'''),
('''		"decor_density": 0.45,
		"enemy_awake": 22.0,
	},''', '''		"decor_density": 0.45,
		"enemy_awake": 22.0,
		"arena_max_enemies": 9,
		"horde_size": 4,
	},'''),
('''		"decor_density": 0.8,
		"enemy_awake": 30.0,
	},''', '''		"decor_density": 0.8,
		"enemy_awake": 30.0,
		"arena_max_enemies": 12,
		"horde_size": 5,
	},'''),
('''		"decor_density": 1.0,
		"enemy_awake": 34.0,
	},''', '''		"decor_density": 1.0,
		"enemy_awake": 34.0,
		"arena_max_enemies": 15,
		"horde_size": 6,
	},'''),
])

# ------------------------------------------------------------ рівні: зали-засідки
edit('scenes/dungeon/dungeon_levels.gd', [
('''		"id": &"crypts",''', '''		"id": &"crypts",
		# Засідки (ArenaAmbush): зали в клітинках карти — Rect2i(x, z, ширина, висота).
		"arenas": [Rect2i(2, 12, 36, 7)],'''),
('''		"id": &"fungal",''', '''		"id": &"fungal",
		"arenas": [Rect2i(20, 30, 11, 11), Rect2i(15, 12, 23, 10)],'''),
('''		"id": &"citadel",''', '''		"id": &"citadel",
		"arenas": [Rect2i(18, 25, 14, 12), Rect2i(17, 10, 16, 9)],'''),
])

# ------------------------------------------------------------ данж
edit('scenes/dungeon/dungeon.gd', [
('''## ВІДЧУТТЯ ВБИВСТВА.''', '''## ЗАСІДКИ: нагорода зі скрині (золото множиться на золотість рівня).
const ARENA_CHEST_GOLD := 45
const ARENA_CHEST_XP := 8
## Дрібнота орди й ватажок: частки від звичайного ворога рівня.
const MINION_HP := 0.3
const MINION_DAMAGE := 0.5
const MINION_SIZE := 0.72
const CHAMPION_HP := 2.6
const CHAMPION_DAMAGE := 1.3
const CHAMPION_SIZE := 1.3

## ВІДЧУТТЯ ВБИВСТВА.'''),
('''var _shrine_label: Label
''', '''var _shrine_label: Label
## Мітки ворогів усередині засідок: такі вороги не стоять із самого
## початку, а вилазять хвилями.
var _arena_spawns: Array = []
var _arena_status := ""
var _banner: Control
'''),
('''func _spawn_enemies(markers: Dictionary) -> void:
	var enemies: Dictionary = _level.enemies
	for spawn: Dictionary in markers.spawns:''', '''func _spawn_enemies(markers: Dictionary) -> void:
	var enemies: Dictionary = _level.enemies
	var arenas: Array = _level.get("arenas", [])
	_arena_spawns.clear()
	for i in arenas.size():
		_arena_spawns.append([])
	for spawn: Dictionary in markers.spawns:
		var arena_index := _arena_at(DungeonBuilder.cell_of(spawn.position))
		if arena_index >= 0:
			_arena_spawns[arena_index].append(spawn)
			continue'''),
('''## Вибухові бочки, шипи й святилища — там, де їх розклав place_props.''', '''func _arena_at(cell: Vector2i) -> int:
	var arenas: Array = _level.get("arenas", [])
	for i in arenas.size():
		if (arenas[i] as Rect2i).has_point(cell):
			return i
	return -1

## Засідки: зали, що зачиняються, щойно герой зайде, і вороги вилазять
## хвилями (ArenaAmbush).
func _spawn_arenas() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4201 + _level_index
	var arenas: Array = _level.get("arenas", [])
	for i in arenas.size():
		var arena := ArenaAmbush.new()
		add_child(arena)
		arena.setup(player, _map_rows, arenas[i], _plan_arena_waves(_arena_spawns[i], rng),
			func(position: Vector3, definition: Dictionary) -> Enemy3D:
				return _spawn_enemy(position, definition, false),
			PerfSettings.get_value("arena_max_enemies"))
		arena.wave_started.connect(_on_arena_wave)
		arena.cleared.connect(_on_arena_cleared)

## ХВИЛІ ЗАСІДКИ: 1) половина тих, хто жив у залі; 2) решта разом з
## ордою дрібноти; 3) у великій залі — ще загін і ватажок.
func _plan_arena_waves(spawns: Array, rng: RandomNumberGenerator) -> Array:
	var entries: Array = []
	for spawn: Dictionary in spawns:
		var variants: Array = _level.enemies.get(spawn.symbol, [])
		if variants.is_empty():
			continue
		var definition: Dictionary = variants[rng.randi() % variants.size()]
		var group := int(definition.get("group", 1))
		for i in group:
			var offset := Vector3.ZERO
			if group > 1:
				offset = Vector3(cos(TAU * i / group), 0.0, sin(TAU * i / group)) * 1.1
			entries.append({"position": spawn.position + offset, "definition": definition})
	DungeonBuilder.shuffle(entries, rng)
	var half := ceili(entries.size() / 2.0)
	var waves: Array = [entries.slice(0, half), entries.slice(half)]
	for i in int(PerfSettings.get_value("horde_size")):
		waves[1].append({"position": Vector3.INF, "definition": _minion_definition(rng)})
	if spawns.size() >= 6:
		var last: Array = []
		for i in ceili(entries.size() / 3.0):
			var entry: Dictionary = entries[rng.randi() % entries.size()]
			last.append({"position": entry.position, "definition": entry.definition})
		last.append({"position": Vector3.INF, "definition": _champion_definition()})
		waves.append(last)
	return waves

## Дрібнота орди: звичайний боєць рівня, але менший і слабкий — гине з
## одного-двох ударів. Косити натовп — у цьому й сенс орди.
func _minion_definition(rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = _level.enemies.get("m", [])
	var base: Dictionary = pool[rng.randi() % pool.size()]
	var minion := base.duplicate()
	minion.hp = float(base.hp) * MINION_HP
	minion.damage = float(base.damage) * MINION_DAMAGE
	minion.height = float(base.height) * MINION_SIZE
	minion.speed = float(base.speed) * 1.15
	minion.xp = 1
	minion.erase("group")
	return minion

## Ватажок: найміцніший ближній боєць рівня, більший і вдвічі з гаком
## живучіший. Дає багато досвіду.
func _champion_definition() -> Dictionary:
	var best: Dictionary = {}
	for definition: Dictionary in _level.enemies.get("m", []):
		if definition.get("kind", "melee") == "melee" and (best.is_empty() or float(definition.hp) > float(best.hp)):
			best = definition
	if best.is_empty():
		best = _level.enemies.m[0]
	var champion := best.duplicate()
	champion.name = "Ватажок"
	champion.hp = float(best.hp) * CHAMPION_HP
	champion.damage = float(best.damage) * CHAMPION_DAMAGE
	champion.height = float(best.height) * CHAMPION_SIZE
	champion.xp = int(best.get("xp", 3)) * 5
	champion.erase("group")
	return champion

func _on_arena_wave(index: int, total: int) -> void:
	_arena_status = "засідка: хвиля %d/%d" % [index, total]
	if index == 1:
		_show_banner("Засідка!", "Виходи зачинено — вистояти %d хвилі" % total)
	else:
		_show_banner("Хвиля %d" % index, "остання!" if index == total else "")
	_update_status()

func _on_arena_cleared(center: Vector3) -> void:
	_arena_status = ""
	_show_banner("Засідку відбито!", "Скриня посеред зали")
	_update_status()
	var chest := RewardChest.new()
	chest.setup(player)
	add_child(chest)
	chest.global_position = center + Vector3(0, DungeonBuilder.FLOOR_TOP, 0)
	chest.opened.connect(_on_chest_opened)

## Нагорода засідки: золото, досвід і ще одна здібність на вибір.
func _on_chest_opened(position: Vector3) -> void:
	AudioManager.play(&"purchase")
	_loot.burst(position, LootSwarm.Kind.GOLD, int(round(ARENA_CHEST_GOLD * _gold_scale)), 10)
	_loot.burst(position, LootSwarm.Kind.XP, ARENA_CHEST_XP, 4)
	_offer_ability()

## Великий напис угорі посередині ("Засідка!", "Хвиля 2") — на пару
## секунд, потім тане.
func _show_banner(title: String, subtitle: String) -> void:
	if _banner != null and is_instance_valid(_banner):
		_banner.queue_free()
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 96.0
	holder.offset_bottom = 190.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	holder.add_child(column)
	var title_row := UiTheme.make_title(title, 36)
	for child in title_row.get_children():
		if child is Label:
			UiTheme.hud_text(child as Label, 36, UiTheme.HEADING)
	column.add_child(title_row)
	if subtitle != "":
		var label := Label.new()
		label.text = subtitle
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiTheme.hud_text(label, 17)
		column.add_child(label)
	hud.add_child(holder)
	hud.move_child(holder, 1)
	_banner = holder
	holder.modulate.a = 0.0
	var tween := holder.create_tween()
	tween.tween_property(holder, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.8)
	tween.tween_property(holder, "modulate:a", 0.0, 0.5)
	tween.tween_callback(holder.queue_free)

## Вибухові бочки, шипи й святилища — там, де їх розклав place_props.'''),
('''	_spawn_enemies(markers)
	_spawn_props()
''', '''	_spawn_enemies(markers)
	_spawn_props()
	_spawn_arenas()
'''),
('''	var state := "бос попереду" if not _boss_defeated else "вихід відчинено"''',
 '''	var state := "бос попереду" if not _boss_defeated else "вихід відчинено"
	if _arena_status != "":
		state = _arena_status'''),
('''	var models: Array = [EXIT_SCENE, ExplosiveBarrel.BARREL_SCENE, SpikeTrap.PLATE_SCENE,
		SpikeTrap.SPIKES_SCENE, Shrine.PEDESTAL_SCENE]''', '''	var models: Array = [EXIT_SCENE, ExplosiveBarrel.BARREL_SCENE, SpikeTrap.PLATE_SCENE,
		SpikeTrap.SPIKES_SCENE, Shrine.PEDESTAL_SCENE, ArenaAmbush.BARS_SCENE, RewardChest.CHEST_SCENE]'''),
])
print('ok')
