# -*- coding: utf-8 -*-
# Данж: теми, вороги з опису рівня, підмога боса, вибір на виході.
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:80])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


patch('scenes/dungeon/dungeon.gd', [
    ('''##  4. У кінці — бос, а за ним вихід: на базу або на наступний рівень.''',
     '''##  4. У кінці — бос, а за ним вихід: на базу або на наступний рівень.
##
## РІВНІ (DungeonLevels) різні не лише картою: у кожного своя тема
## (колір каменю, туман, світло, прикраси), свої вороги й бос, і кожен
## наступний міцніший (множники stats: здоров'я, шкода, золото).'''),
    ('''## Моделі ворогів під кожну роль.
const MELEE_MODELS := [
	preload("res://assets/models/monsters/Orc Enemy.glb"),
	preload("res://assets/models/monsters/Green Spiky Blob.glb"),
	preload("res://assets/models/monsters/Ghost Skull.glb"),
]
const RANGED_MODEL := preload("res://assets/models/monsters/Wizard.glb")
const BOSS_MODEL := preload("res://assets/models/monsters/Demon-LnfIziKv4o.glb")
''',
     '''## Скільки підмоги Грибного Короля може бути живою одночасно —
## і складність, і запобіжник для слабкого телефона.
const MAX_SUMMONS := 6
'''),
    ('''var _run_gold := 0''',
     '''var _run_gold := 0
var _level: Dictionary = {}
var _theme: Dictionary = {}
var _hp_scale := 1.0
var _damage_scale := 1.0
var _gold_scale := 1.0
var _models: Dictionary = {}
var _alive_summons := 0
var _exit_choice: Control'''),
    ('''	_level_index = GameState.dungeon_level
	var level := DungeonLevels.get_level(_level_index)
	_map_rows = level.map
	var markers := DungeonBuilder.build_base(level.map, level_root)''',
     '''	_level_index = GameState.dungeon_level
	var level := DungeonLevels.get_level(_level_index)
	_level = level
	_theme = level.get("theme", DungeonBuilder.DEFAULT_THEME)
	_hp_scale = float(level.stats.hp)
	_damage_scale = float(level.stats.damage)
	_gold_scale = float(level.stats.gold)
	_apply_theme()
	_map_rows = level.map
	var markers := DungeonBuilder.build_base(level.map, level_root, _theme)'''),
    ('''func _spawn_enemies(markers: Dictionary) -> void:
	for position: Vector3 in markers.melee:
		_spawn_enemy(position, Enemy3D.Kind.MELEE, MELEE_MODELS[randi() % MELEE_MODELS.size()])
	for position: Vector3 in markers.ranged:
		_spawn_enemy(position, Enemy3D.Kind.RANGED, RANGED_MODEL)
	if markers.boss != Vector3.ZERO:
		_spawn_enemy(markers.boss, Enemy3D.Kind.BOSS, BOSS_MODEL)

func _spawn_enemy(position: Vector3, kind: Enemy3D.Kind, model: PackedScene) -> void:
	var enemy: CharacterBody3D = ENEMY_SCRIPT.new()
	enemy.collision_layer = 4
	enemy.collision_mask = 1
	enemy.kind = kind
	# Складність росте з рівнем данжу: ті самі вороги, але міцніші.
	var scale_factor := 1.0 + 0.35 * _level_index
	match kind:
		Enemy3D.Kind.MELEE:
			enemy.max_hp = 30.0 * scale_factor
			enemy.damage = 8.0 * scale_factor
		Enemy3D.Kind.RANGED:
			enemy.max_hp = 22.0 * scale_factor
			enemy.damage = 6.0 * scale_factor
			enemy.attack_range = 9.0
			enemy.aggro_range = 16.0
			enemy.move_speed = 2.2
			enemy.xp_reward = 4
		Enemy3D.Kind.BOSS:
			enemy.max_hp = 220.0 * scale_factor
			enemy.damage = 16.0 * scale_factor
			enemy.move_speed = 3.2
			enemy.aggro_range = 18.0
			enemy.xp_reward = 25
			enemy.attack_range = 3.0
			enemy.target_height = 3.4   # бос помітно вищий за решту

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	enemy.add_child(shape)

	enemies_root.add_child(enemy)
	enemy.global_position = position + Vector3(0, 0.2, 0)
	enemy.setup(player, model)
	enemy.died.connect(_on_enemy_died.bind(kind))
	_alive_enemies += 1''',
     '''## Тема рівня: туман, загальне світло, тло. Колір каменю й прикраси
## задає будівельник (DungeonBuilder) — тут лише повітря й світло.
func _apply_theme() -> void:
	var environment: Environment = $WorldEnvironment.environment.duplicate()
	environment.background_color = _theme.get("background", environment.background_color)
	environment.fog_light_color = _theme.get("fog", environment.fog_light_color)
	environment.fog_density = float(_theme.get("fog_density", environment.fog_density))
	environment.ambient_light_color = _theme.get("ambient", environment.ambient_light_color)
	environment.ambient_light_energy = float(_theme.get("ambient_energy", environment.ambient_light_energy))
	$WorldEnvironment.environment = environment

## Вороги за мітками карти. Хто саме стоїть на мітці — вирішує опис
## рівня: "m" у склепах — орк, у печерах — грибовик.
func _spawn_enemies(markers: Dictionary) -> void:
	var enemies: Dictionary = _level.enemies
	for spawn: Dictionary in markers.spawns:
		var variants: Array = enemies.get(spawn.symbol, [])
		if variants.is_empty():
			continue
		var definition: Dictionary = variants[randi() % variants.size()]
		var group := int(definition.get("group", 1))
		for i in group:
			# Рій стоїть купкою навколо мітки, а не в одній точці.
			var offset := Vector3.ZERO
			if group > 1:
				var angle := TAU * i / group
				offset = Vector3(cos(angle), 0.0, sin(angle)) * 1.1
			_spawn_enemy(spawn.position + offset, definition, false)
	if markers.boss != Vector3.ZERO:
		_spawn_enemy(markers.boss, _level.boss, true)

func _spawn_enemy(position: Vector3, definition: Dictionary, is_boss: bool) -> Enemy3D:
	var enemy: Enemy3D = ENEMY_SCRIPT.new()
	enemy.collision_layer = 4
	enemy.collision_mask = 1
	if is_boss:
		enemy.configure_boss(definition, _hp_scale, _damage_scale)
	else:
		enemy.configure(definition, _hp_scale, _damage_scale)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	# Капсула за зростом: великий голем не має бути "тонким" для ударів.
	var height: float = maxf(enemy.target_height, 1.0)
	capsule.radius = clampf(height * 0.28, 0.35, 0.9)
	capsule.height = maxf(height, capsule.radius * 2.0)
	shape.shape = capsule
	shape.position = Vector3(0, capsule.height * 0.5, 0)
	enemy.add_child(shape)

	enemies_root.add_child(enemy)
	enemy.global_position = position + Vector3(0, 0.2, 0)
	enemy.setup(player, _model(definition.model))
	enemy.died.connect(_on_enemy_died.bind(enemy.kind))
	if is_boss:
		enemy.summon_requested.connect(_on_summon_requested)
	_alive_enemies += 1
	return enemy

func _model(path: String) -> PackedScene:
	if not _models.has(path):
		_models[path] = load(path)
	return _models[path]

## Грибний Король кличе підмогу: кілька грибочків довкола нього. Скільки
## їх може бути живими водночас — обмежено, щоб бій лишався чесним, а
## телефон — живим.
func _on_summon_requested(position: Vector3, count: int) -> void:
	var definition: Dictionary = _level.boss.get("summon", {})
	if definition.is_empty():
		return
	for i in count:
		if _alive_summons >= MAX_SUMMONS:
			return
		var angle := TAU * i / count + randf() * 0.5
		var spot := position + Vector3(cos(angle), 0.0, sin(angle)) * 2.2
		var enemy := _spawn_enemy(spot, definition, false)
		enemy.died.connect(func(_p: Vector3, _xp: int) -> void: _alive_summons -= 1)
		_alive_summons += 1
		CombatVfx.impact(level_root, spot + Vector3.UP * 0.5, Color(0.5, 1.0, 0.4), false)'''),
    ('''	_add_gold(GOLD_PER_BOSS if kind == Enemy3D.Kind.BOSS else GOLD_PER_KILL)''',
     '''	_add_gold(int(round((GOLD_PER_BOSS if kind == Enemy3D.Kind.BOSS else GOLD_PER_KILL) * _gold_scale)))'''),
    # --- прогрів: моделі саме цього рівня ---
    ('''	var models: Array = MELEE_MODELS.duplicate()
	models.append_array([RANGED_MODEL, BOSS_MODEL, EXIT_SCENE])''',
     '''	var models: Array = [EXIT_SCENE]
	for symbol: String in _level.enemies:
		for definition: Dictionary in _level.enemies[symbol]:
			models.append(_model(definition.model))
	models.append(_model(_level.boss.model))
	if _level.boss.has("summon"):
		models.append(_model(_level.boss.summon.model))'''),
    ('''	var marker := CombatVfx.make_ground_marker(Color(1.0, 0.22, 0.15, 0.85), 1.0, 1.0)
	holder.add_child(marker)
	marker.global_position = center - Vector3(0, 0.9, 0)''',
     '''	var marker := CombatVfx.make_ground_marker(Color(1.0, 0.22, 0.15, 0.85), 1.0, 1.0)
	holder.add_child(marker)
	marker.global_position = center - Vector3(0, 0.9, 0)
	var line := CombatVfx.make_line_marker(Color(1.0, 0.3, 0.2, 0.85), 2.0, 1.0)
	holder.add_child(line)
	line.global_position = center - Vector3(0, 0.9, 0)'''),
    # --- шматки з темою ---
    ('''			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"))
			built_one = true''',
     '''			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"), _theme)
			built_one = true'''),
    ('''		if not chunk.built:
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"))
			return true''',
     '''		if not chunk.built:
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"), _theme)
			return true'''),
    # --- вихід: на базу або далі ---
    ('''func _on_exit_pressed() -> void:
	# Пройшов данж — наступний рівень стає доступним, плюс нагорода.
	_add_gold(GOLD_FOR_CLEAR * (1 + _level_index))
	GameState.unlock_next_dungeon_level()
	SceneLoader.change_scene(BASE_SCENE_PATH, "База")''',
     '''## Біля відчиненого виходу: нагорода за рівень і вибір — повернутись у
## місто чи одразу йти на наступний (якщо він є).
func _on_exit_pressed() -> void:
	if _exit_choice != null:
		return
	_add_gold(int(round(GOLD_FOR_CLEAR * _gold_scale)))
	GameState.unlock_next_dungeon_level()
	exit_button.visible = false
	_exit_choice = _build_exit_choice()
	hud.add_child(_exit_choice)

func _build_exit_choice() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", UiTheme.make_box(UiTheme.PANEL, 12, 2, UiTheme.ACCENT))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "%s — пройдено!\\nЗолота за похід: %d" % [_level.title, _run_gold]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var next_index := _level_index + 1
	if next_index < DungeonLevels.get_level_count():
		var next := Button.new()
		next.text = "Далі: %s" % DungeonLevels.get_level(next_index).title
		next.custom_minimum_size = Vector2(320, 56)
		next.add_theme_font_size_override("font_size", 20)
		next.pressed.connect(func() -> void:
			GameState.select_dungeon_level(next_index)
			SceneLoader.change_scene("res://scenes/dungeon/dungeon.tscn", DungeonLevels.get_level(next_index).title))
		box.add_child(next)
	var home := Button.new()
	home.text = "Повернутись у місто"
	home.custom_minimum_size = Vector2(320, 56)
	home.add_theme_font_size_override("font_size", 20)
	home.pressed.connect(func() -> void: SceneLoader.change_scene(BASE_SCENE_PATH, "Місто"))
	box.add_child(home)
	# Панель стоїть по центру: розмір відомий після першої розкладки.
	panel.position -= panel.get_combined_minimum_size() * 0.5
	return panel'''),
])
