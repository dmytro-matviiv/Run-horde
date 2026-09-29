extends Node3D

## Данж: побудований рівень, а не арена з напливом ворогів.
##
## Порядок такий, як просив замовник:
##  1. Герой заходить у порожню кімнату — на вході ворогів немає.
##  2. Одразу вибирає ОДНУ здібність із трьох.
##  3. Іде коридорами, б'є ворогів, збирає з них досвід; на новому
##     рівні знову вибирає здібність.
##  4. У кінці — бос, а за ним вихід: на базу або на наступний рівень.
##
## РІВНІ (DungeonLevels) різні не лише картою: у кожного своя тема
## (колір каменю, туман, світло, прикраси), свої вороги й бос, і кожен
## наступний міцніший (множники stats: здоров'я, шкода, золото).
##
## Вороги не проходять крізь стіни й не застрягають за кутами: у данжі
## будується карта прохідності (NavigationRegion3D), по якій вони
## рахують маршрут.

const LEVEL_UP_CHOICE_SCENE := preload("res://scenes/ui/level_up_choice.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const JOYSTICK_SCENE := preload("res://scenes/ui/virtual_joystick.tscn")
const CAMERA_TOUCH_SCENE := preload("res://scenes/ui/camera_touch.tscn")
const COMBAT_BUTTONS_SCRIPT := preload("res://scenes/ui/combat_buttons.gd")
const ENEMY_SCRIPT := preload("res://scenes/dungeon/enemy_3d.gd")
const EXIT_SCENE := preload("res://assets/models/dungeon/Arch_Door.fbx")

## Скільки підмоги Грибного Короля може бути живою одночасно —
## і складність, і запобіжник для слабкого телефона.
const MAX_SUMMONS := 6

const BASE_SCENE_PATH := "res://scenes/world/base_island.tscn"

## Скільки досвіду треба на наступний рівень героя в данжі.
const XP_PER_LEVEL := 12

## КАМЕРА. У данжі вона дивиться круто згори і не нахиляється пологіше
## за CAMERA_MAX_PITCH: з пологого кута було видно горизонт, далекі зали
## й темряву між ними. Гравцеві потрібна його зала, а не весь рівень.
const CAMERA_PITCH := -54.0
const CAMERA_MIN_PITCH := -66.0
const CAMERA_MAX_PITCH := -46.0

## ЗОЛОТО ЗА ПОХІД (числа тимчасові — баланс підженемо, коли буде більше
## рівнів). Талант "Приріст золота" додає свої відсотки, а талант
## "Удача" покращує вибір здібностей, "Стартовий рівень" дає зайвий
## вибір на вході.
const GOLD_PER_KILL := 4
const GOLD_PER_BOSS := 60
const GOLD_FOR_CLEAR := 120
const TALENT_GOLD_PER_LEVEL := 0.07
const TALENT_LUCK_PER_LEVEL := 0.04

## ПОТОКОВЕ ПІДВАНТАЖЕННЯ
##
## Данж ріжеться на шматки (див. DungeonBuilder). Тут вирішується, який
## шматок збудувати, а який сховати. Відстані залежать від якості
## графіки (PerfSettings): на слабкому телефоні видно трохи ближче, але
## завжди далі, ніж захоплює камера, тож "дірок" гравець не бачить.
##   view_distance        — далі за це (від краю шматка) шматок ховається;
##   + BUILD_AHEAD         — на цій відстані шматок починають будувати,
##                           щоб гравець підійшов уже до готового.
## Перевіряємо не щокадру, а раз на STREAM_INTERVAL — цього вистачає,
## бо герой не встигає пробігти шматок за чверть секунди.
const BUILD_AHEAD := 12.0
const STREAM_INTERVAL := 0.25

## Вороги ближче за це анімуються щокадру, далі — через кадр: на такій
## відстані різниці не видно, а скелетна анімація найдорожча на телефоні.
const ENEMY_FULL_DETAIL_DISTANCE := 13.0

@onready var player: CharacterBody3D = $Player
@onready var level_root: Node3D = $NavigationRegion3D
@onready var enemies_root: Node3D = $Enemies
@onready var hud: CanvasLayer = $HUD
@onready var status_label: Label = $HUD/StatusLabel
@onready var health_label: Label = $HUD/HealthLabel
@onready var exit_button: Button = $HUD/ExitButton

var _level_index := 0
var _xp := 0
var _hero_level := 1
var _alive_enemies := 0
var _boss_defeated := false
var _exit_position := Vector3.ZERO
var _exit_open := false
var _map_rows: Array = []
var _chunks: Array = []
var _lights: Array = []
var _stream_left := 0.0
var _run_gold := 0
var _level: Dictionary = {}
var _theme: Dictionary = {}
var _hp_scale := 1.0
var _damage_scale := 1.0
var _gold_scale := 1.0
var _models: Dictionary = {}
var _alive_summons := 0
var _exit_choice: Control
## Що герой уже взяв у цьому поході: id здібності -> рівень.
var _run_upgrades: Dictionary = {}
var _buff_bar: HFlowContainer
var _hud_title: Label
var _health_bar: ProgressBar
var _xp_bar: ProgressBar
var _pause_menu: Control
var _run_over := false

## Збирання рівня розкладене на кілька кадрів і сховане за екраном
## завантаження (SceneLoader.hold): гравець бачить плавну смужку, а не
## застиглий екран. Карта прохідності печеться в окремому потоці.
func _ready() -> void:
	SceneLoader.hold()
	_level_index = GameState.dungeon_level
	var level := DungeonLevels.get_level(_level_index)
	_level = level
	_theme = level.get("theme", DungeonBuilder.DEFAULT_THEME)
	_hp_scale = float(level.stats.hp)
	_damage_scale = float(level.stats.damage)
	_gold_scale = float(level.stats.gold)
	_apply_theme()
	_map_rows = level.map
	var markers := DungeonBuilder.build_base(level.map, level_root, _theme)
	_chunks = markers.chunks
	_lights = markers.lights

	player.global_position = markers.start + Vector3(0, 0.2, 0)
	_exit_position = markers.exit
	_setup_hud(level.title)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	PerfSettings.quality_changed.connect(_on_quality_changed)

	# Карту прохідності печемо ПІСЛЯ того, як перешкоди створено: інакше
	# ворогам не буде по чому рахувати маршрут. Печеться у фоні — тим
	# часом по одному шматку за кадр збираємо найближчі зали.
	level_root.bake_navigation_mesh(true)
	# Збираємо ВСІ шматки одразу, по одному за кадр, поки гравець дивиться
	# на смужку завантаження. На слабкому телефоні збирання шматка посеред
	# гри давало ривок щоразу, як герой заходив у нову залу; тепер під
	# час гри шматки лише ховаються й показуються — це безкоштовно.
	while _build_next_chunk():
		await get_tree().process_frame
	_update_streaming()
	if level_root.is_baking():
		await level_root.bake_finished

	_spawn_enemies(markers)
	await _warm_up_rendering()
	_update_streaming()
	SceneLoader.release()

	# Вхідна кімната порожня, і перше, що робить гравець, — обирає
	# здібність. Талант "Стартовий рівень" дає зайві вибори одразу.
	var start_picks := 1 + GameState.get_meta_level(GameState.selected_hero_id, &"meta_start_level")
	for i in start_picks:
		await _offer_ability()

func _setup_hud(title: String) -> void:
	_style_hud()
	var joystick: Control = JOYSTICK_SCENE.instantiate()
	hud.add_child(joystick)
	joystick.direction_changed.connect(_on_joystick_moved)

	# Права половина екрана крутить камеру, короткий дотик по ній — удар.
	var camera_touch: Control = CAMERA_TOUCH_SCENE.instantiate()
	hud.add_child(camera_touch)
	$CameraRig.set_world_collision(false)
	$CameraRig.set_pitch_limits(CAMERA_MIN_PITCH, CAMERA_MAX_PITCH, CAMERA_PITCH)
	camera_touch.rotate_requested.connect($CameraRig.rotate_by)
	camera_touch.pitch_requested.connect($CameraRig.pitch_by)
	camera_touch.tap_attack.connect(player.attack)
	camera_touch.attack_held_changed.connect(player.set_attack_held)

	# Бойові кнопки — поверх зони камери: дотик по кнопці забирає кнопка.
	var combat_buttons: Control = COMBAT_BUTTONS_SCRIPT.new()
	hud.add_child(combat_buttons)
	combat_buttons.setup(player)
	if not OS.has_feature("mobile"):
		_add_keyboard_hint()
	_add_pause_button()

	hud.move_child(exit_button, hud.get_child_count() - 1)

	UiTheme.make_primary(exit_button)
	exit_button.visible = false
	exit_button.pressed.connect(_on_exit_pressed)
	_update_status(title)
	_on_player_health_changed(player.current_hp, player.max_hp)

## Лівий верхній кут — панель у рамці теми (UiTheme): назва рівня й
## рівень героя, смуги здоров'я й досвіду, під ними золото, вороги й стан
## виходу. Узяті в поході здібності — плашками одразу під панеллю.
func _style_hud() -> void:
	var corner := VBoxContainer.new()
	corner.position = Vector2(12, 12)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_theme_constant_override("separation", 6)
	hud.add_child(corner)
	hud.move_child(corner, 0)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.hud_box())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)

	_hud_title = Label.new()
	UiTheme.hud_text(_hud_title, 18, UiTheme.HEADING)
	column.add_child(_hud_title)

	_health_bar = UiTheme.make_bar(Color(0.74, 0.18, 0.2), Vector2(300, 24))
	column.add_child(_health_bar)
	health_label.reparent(_health_bar, false)
	health_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.hud_text(health_label, 15)

	_xp_bar = UiTheme.make_bar(UiTheme.HEADING, Vector2(300, 7))
	column.add_child(_xp_bar)

	status_label.reparent(column, false)
	UiTheme.hud_text(status_label, 15, UiTheme.TEXT_DIM.lightened(0.25))

	_buff_bar = HFlowContainer.new()
	_buff_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_bar.add_theme_constant_override("h_separation", 6)
	_buff_bar.add_theme_constant_override("v_separation", 4)
	corner.add_child(_buff_bar)

## Пауза — угорі праворуч, іконка з набору. На ПК те саме робить Esc, на
## телефоні — ще й системна кнопка "назад".
func _add_pause_button() -> void:
	var button := UiTheme.make_icon_button("pause", 56.0, "Пауза")
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -68.0
	button.offset_right = -12.0
	button.offset_top = 12.0
	button.offset_bottom = 68.0
	button.pressed.connect(_open_pause)
	hud.add_child(button)

func _open_pause() -> void:
	if _run_over or get_tree().paused or _pause_menu != null or _exit_choice != null:
		return
	get_tree().paused = true
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(_pause_menu)
	# У данжі золото зараховується одразу — вихід забирає лише здібності
	# цього походу, тож і попередження інше, ніж у старому рані.
	_pause_menu.configure("Бій зупинено. Золото з цього походу вже твоє.",
		"Покинути данж",
		"Здібності цього походу зникнуть, золото лишиться. Вийти в місто?",
		"Так, у місто")
	_pause_menu.resumed.connect(_close_pause)
	_pause_menu.quit_confirmed.connect(func() -> void:
		_close_pause()
		_run_over = true
		SceneLoader.change_scene(BASE_SCENE_PATH, "Місто"))

func _close_pause() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	get_tree().paused = false

## Узяті в поході здібності — плашками під здоров'ям: видно, що вже
## прокачано й на якому рівні. Особисті здібності героя — його кольором.
func _update_buffs() -> void:
	for child in _buff_bar.get_children():
		child.queue_free()
	for upgrade: Dictionary in RunUpgrades.UPGRADES:
		var level := int(_run_upgrades.get(upgrade.id, 0))
		if level <= 0:
			continue
		var personal: bool = not (upgrade.scope in ["any", "melee", "ranged", "spell"])
		var box := UiTheme.make_box(Color(UiTheme.PANEL, 0.82), 3, 1,
			player.hero_def.color if personal else Color(UiTheme.LINE, 0.45))
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 2
		box.content_margin_bottom = 2
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", box)
		var label := Label.new()
		label.text = upgrade.title if level == 1 else "%s ×%d" % [upgrade.title, level]
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", UiTheme.TEXT)
		chip.add_child(label)
		_buff_bar.add_child(chip)

## Підказка для ПК: які клавіші що роблять.
func _add_keyboard_hint() -> void:
	var hint := Label.new()
	# Підписи — з того, що вміє саме цей герой: у Чарівниці не "вихор".
	var action := "чари" if player.is_caster() else ("постріл" if player.is_ranged() else "удар")
	var parts: Array[String] = ["Пробіл / ЛКМ — %s (утримуй — серія)" % action, "Shift — перекат"]
	var skills: Array = player.get_skills()
	for index in mini(skills.size(), 2):
		parts.append("%s — %s" % [["E", "Q"][index], (skills[index] as HeroSkill3D).title.to_lower()])
	parts.append("ПКМ — камера")
	parts.append("Esc — пауза")
	hint.text = "   •   ".join(parts)
	UiTheme.hud_text(hint, 15, Color(UiTheme.TEXT, 0.7))
	# Угорі між панеллю здоров'я і паузою: унизу рядок налазив на підписи
	# бойових кнопок.
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_left = 360.0
	hint.offset_right = -84.0
	hint.offset_top = 26.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint)

## Тема рівня: туман, загальне світло, тло. Колір каменю й прикраси
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
		CombatVfx.impact(level_root, spot + Vector3.UP * 0.5, Color(0.5, 1.0, 0.4), false)

func _on_enemy_died(_position: Vector3, xp_reward: int, kind: Enemy3D.Kind) -> void:
	_alive_enemies -= 1
	_add_gold(int(round((GOLD_PER_BOSS if kind == Enemy3D.Kind.BOSS else GOLD_PER_KILL) * _gold_scale)))
	_add_xp(xp_reward)
	if kind == Enemy3D.Kind.BOSS:
		_boss_defeated = true
		_open_exit()

## Золото з походу. Талант "Приріст золота" множить здобич, а
## зараховується вона одразу — щоб прогрес не пропав, якщо гравець
## загине на виході.
func _add_gold(amount: int) -> void:
	var levels := GameState.get_meta_level(GameState.selected_hero_id, &"meta_gold_gain")
	var total := int(round(amount * (1.0 + TALENT_GOLD_PER_LEVEL * levels)))
	_run_gold += total
	GameState.add_gold(total)
	_update_status()

## Досвід збирається з ворогів; за кожен рівень — нова здібність.
func _add_xp(amount: int) -> void:
	_xp += amount
	while _xp >= XP_PER_LEVEL * _hero_level:
		_xp -= XP_PER_LEVEL * _hero_level
		_hero_level += 1
		await _offer_ability()
	_update_status()

## Вибір здібності зупиняє гру — як і в меню рівня 2D-частини.
func _offer_ability() -> void:
	var luck := TALENT_LUCK_PER_LEVEL * GameState.get_meta_level(GameState.selected_hero_id, &"meta_luck")
	# Здібності підбираються під ГЕРОЯ та його зброю: стрільцю — набої й
	# перезарядка, мечниці — замахи й лють.
	var choices := RunUpgrades.pick(player, _run_upgrades, luck)
	if choices.is_empty():
		return
	get_tree().paused = true
	var choice_ui: Node = LEVEL_UP_CHOICE_SCENE.instantiate()
	choice_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(choice_ui)
	choice_ui.setup_cards(_hero_level, choices)
	var picked: StringName = await choice_ui.upgrade_chosen
	choice_ui.queue_free()
	get_tree().paused = false
	_run_upgrades[picked] = int(_run_upgrades.get(picked, 0)) + 1
	_update_buffs()
	player.apply_run_upgrade(picked)
	_update_status()

## Вихід відчиняється лише після боса.
func _open_exit() -> void:
	_exit_open = true
	var door: Node3D = EXIT_SCENE.instantiate()
	door.position = _exit_position + Vector3(0, 0, 0)
	level_root.add_child(door)

	var glow := OmniLight3D.new()
	glow.light_color = Color(0.6, 1.0, 0.7)
	glow.light_energy = 5.0
	glow.omni_range = 10.0
	glow.position = _exit_position + Vector3(0, 1.5, 0)
	level_root.add_child(glow)
	_update_status()

func _process(delta: float) -> void:
	_stream_left -= delta
	if _stream_left <= 0.0:
		_stream_left = STREAM_INTERVAL
		_update_streaming()

	if not _exit_open:
		return
	# Підійшов до відчиненого виходу — можна йти далі. Коли вже обирає,
	# куди йти, кнопка не потрібна.
	exit_button.visible = _exit_choice == null and player.global_position.distance_to(_exit_position) < 3.0

## Будує те, що попереду, ховає те, що позаду, і присипляє далеких
## ворогів. Гравець цього не помічає: він просто йде коридором.
func _update_streaming() -> void:
	var origin := player.global_position
	var view_distance: float = PerfSettings.get_value("view_distance")
	var built_one := false
	for chunk: Dictionary in _chunks:
		var distance := _distance_to_chunk(origin, chunk)
		if not chunk.built and distance < view_distance + BUILD_AHEAD and not built_one:
			# За раз будуємо лише один шматок: так навіть найповільніший
			# телефон не отримає ривка посеред бігу.
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"), _theme)
			built_one = true
		chunk.node.visible = chunk.built and distance < view_distance

	_update_lights(origin, view_distance)
	_update_enemies(origin)

## Під час завантаження: будує наступний ще не збудований шматок.
## Повертає false, коли всі зібрані.
func _build_next_chunk() -> bool:
	for chunk: Dictionary in _chunks:
		if not chunk.built:
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"), _theme)
			return true
	return false

## ПРОГРІВ ГРАФІКИ.
##
## Відеочип готує програму малювання (шейдер) для кожного виду об'єкта
## тоді, коли вперше бачить його в кадрі. На слабкому телефоні це
## десяті частки секунди — саме такі "зависання" бували на першому ударі,
## першому снаряді, першій зустрічі з босом.
##
## Тож поки на екрані смужка завантаження, ми на кілька кадрів ставимо
## перед камерою по одному зразку всього, що з'явиться в данжі: кожного
## ворога, боса, двері виходу, всі прикраси, всі ефекти бою. Гравець
## цього не бачить (екран завантаження зверху), а шейдери вже готові.
func _warm_up_rendering() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var center := player.global_position + Vector3(0, 1.0, 0)
	var models: Array = [EXIT_SCENE]
	for symbol: String in _level.enemies:
		for definition: Dictionary in _level.enemies[symbol]:
			models.append(_model(definition.model))
	models.append(_model(_level.boss.model))
	if _level.boss.has("summon"):
		models.append(_model(_level.boss.summon.model))
	var step := 0
	for scene: PackedScene in models:
		var model: Node3D = scene.instantiate()
		holder.add_child(model)
		model.global_position = center + Vector3((step % 3 - 1) * 0.6, -0.8, (step / 3) * 0.6)
		model.scale = Vector3.ONE * 0.3
		step += 1
		CombatVfx.flash_model(model, Color.WHITE, 0.5)

	# Прикраси малюються пакетами (MultiMesh) — у пакета свій варіант
	# шейдера, тож і прогріваємо пакетом.
	var batcher := MeshBatcher.new()
	for scene: PackedScene in DungeonBuilder.all_decor_scenes():
		batcher.add(scene, Transform3D(Basis().scaled(Vector3.ONE * 0.3), center + Vector3(0, -0.8, 0)))
	batcher.flush(holder)

	CombatVfx.slash(holder, center, 0.0, 2.0, 150.0, Color(0.72, 0.87, 1.0), false, 0.0, 0.5)
	CombatVfx.impact(holder, center, Color(1.0, 0.65, 0.25), true)
	CombatVfx.damage_number(holder, center, 12.0, true)
	CombatVfx.shockwave(holder, center, 1.5, Color(0.35, 0.95, 1.0), 0.5)
	var marker := CombatVfx.make_ground_marker(Color(1.0, 0.22, 0.15, 0.85), 1.0, 1.0)
	holder.add_child(marker)
	marker.global_position = center - Vector3(0, 0.9, 0)
	var line := CombatVfx.make_line_marker(Color(1.0, 0.3, 0.2, 0.85), 2.0, 1.0)
	holder.add_child(line)
	line.global_position = center - Vector3(0, 0.9, 0)
	var shot := EnemyProjectile.create(0.0)
	holder.add_child(shot)
	shot.global_position = center
	var bar: HealthBar3D = HealthBar3D.new()
	holder.add_child(bar)
	bar.setup(Color(0.95, 0.25, 0.25), 0.5, true)
	bar.global_position = center

	for i in 4:
		await get_tree().process_frame
	holder.queue_free()

## Відстань від героя до найближчої точки шматка на площині.
func _distance_to_chunk(origin: Vector3, chunk: Dictionary) -> float:
	var bounds: Rect2 = chunk.bounds
	var point := Vector2(origin.x, origin.z)
	var closest := point.clamp(bounds.position, bounds.end)
	return point.distance_to(closest)

## Світять лише кілька НАЙБЛИЖЧИХ смолоскипів — скільки саме, вирішує
## якість графіки. Кожне увімкнене джерело світла телефон рахує для
## кожного пікселя, тож далекі гасимо: гравець їх однаково не бачить.
func _update_lights(origin: Vector3, view_distance: float) -> void:
	var allowed: int = PerfSettings.get_value("dungeon_lights")
	var by_distance := _lights.duplicate()
	by_distance.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	for i in by_distance.size():
		var light: OmniLight3D = by_distance[i]
		light.visible = i < allowed and origin.distance_to(light.global_position) < view_distance + 10.0

## Далекі вороги сплять, середні анімуються рідше, близькі — щокадру.
func _update_enemies(origin: Vector3) -> void:
	var awake_distance: float = PerfSettings.get_value("enemy_awake")
	for enemy in enemies_root.get_children():
		if not enemy is Enemy3D:
			continue
		var distance := origin.distance_to((enemy as Node3D).global_position)
		(enemy as Enemy3D).set_sleeping(distance > awake_distance)
		(enemy as Enemy3D).set_animation_step(1 if distance < ENEMY_FULL_DETAIL_DISTANCE else 2)

## Якість змінилась (гравець у меню або автоматика) — одразу
## перераховуємо світло й дальність, не чекаючи наступної перевірки.
func _on_quality_changed(_quality: int) -> void:
	_update_streaming()

func _update_status(title: String = "") -> void:
	if title != "":
		status_label.set_meta("title", title)
	var level_title: String = status_label.get_meta("title", "Данж")
	var state := "бос попереду" if not _boss_defeated else "вихід відчинено"
	_hud_title.text = "%s  •  рівень героя %d" % [level_title, _hero_level]
	status_label.text = "Золото %d   •   ворогів %d   •   %s" % [_run_gold, _alive_enemies, state]
	# Смужка досвіду — скільки лишилось до наступного вибору здібності.
	_xp_bar.max_value = XP_PER_LEVEL * _hero_level
	_xp_bar.value = _xp

## Герой загинув — це має бути видно, а не виглядати як "застряг".
func _on_player_died() -> void:
	_run_over = true
	status_label.text = "Ви загинули. Повертаємось на базу…"
	await get_tree().create_timer(2.0).timeout
	SceneLoader.change_scene(BASE_SCENE_PATH, "База")

func _on_player_health_changed(current: float, maximum: float) -> void:
	health_label.text = "%d / %d" % [ceili(current), int(maximum)]
	_health_bar.max_value = maximum
	_health_bar.value = current

func _on_joystick_moved(direction: Vector2) -> void:
	player.set_move_input(Vector2(direction.x, -direction.y))

## Біля відчиненого виходу: нагорода за рівень і вибір — повернутись у
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
	# Затемнення на весь екран: гра позаду не відволікає, а випадковий
	# дотик повз панель не рушить героя.
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UiTheme.make_title("%s — пройдено!" % _level.title, 24))
	var reward := Label.new()
	reward.text = "Золота за похід: %d" % _run_gold
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_font_size_override("font_size", 20)
	reward.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(reward)
	var next_index := _level_index + 1
	if next_index < DungeonLevels.get_level_count():
		var next := Button.new()
		next.text = "Далі: %s" % DungeonLevels.get_level(next_index).title
		UiTheme.make_primary(next)
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
	return shade

## Удар, перекат і вихір з клавіатури герой ловить сам (див. player_3d).
## Esc — пауза (закриває її саме меню паузи: на паузі сюди нічого не
## доходить).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause()

## Системна кнопка "назад" на Android — теж пауза, а не миттєвий вихід.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_open_pause()
