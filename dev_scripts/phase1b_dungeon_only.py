import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:80])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


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
