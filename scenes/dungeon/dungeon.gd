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
## Портал виходу — та сама арка з вихровою пеленою, що й прохід у данж у
## місті (base_island: Town/DungeonGate/Arch + Effects/Portal).
const EXIT_ARCH_SCENE := preload("res://assets/models/dungeon/Arch.fbx")
const PORTAL_SHADER := preload("res://scenes/world/portal.gdshader")
## Арка в данжі менша, ніж у місті (там 1.75): стіни тут по 2 м.
const EXIT_ARCH_SCALE := 0.9
## Пелена в арці міста — 4.4 x 5.9 м при масштабі арки 1.75.
const PORTAL_SIZE := Vector2(4.4, 5.9) / 1.75 * EXIT_ARCH_SCALE
## Підійшов ближче — з'являється кнопка виходу.
const EXIT_REACH := 3.0
## Наскільки арка відступає від межі клітинок у кімнату: стіни данжу
## стоять на межі й виступають у кімнату до ~0.35 м, арка завглибшки
## ~0.9 м — так її спина впирається в лице стіни, а пелена вся перед нею.
const PORTAL_WALL_OFFSET := 0.8

## Скільки підмоги Грибного Короля може бути живою одночасно —
## і складність, і запобіжник для слабкого телефона.
const MAX_SUMMONS := 6

const BASE_SCENE_PATH := "res://scenes/world/base_island.tscn"
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
## Воскресіння за відео: частка здоров'я й щит (с). Раз за похід.
const REVIVE_HP := 0.8
const REVIVE_SHIELD := 3.0

## Скільки досвіду треба на наступний рівень героя в данжі.
const XP_PER_LEVEL := 12

## ПРЕДМЕТИ В ЗАЛАХ: сила вибуху бочки й удару шипів — з силою рівня
## (по ворогах множиться на їхнє здоров'я, по герою — на шкоду рівня).
const BARREL_BLAST := 45.0
const BARREL_HERO_DAMAGE := 12.0
const TRAP_ENEMY_DAMAGE := 22.0
const TRAP_HERO_DAMAGE := 10.0

## ЗАСІДКИ: нагорода зі скрині (золото множиться на золотість рівня).
const ARENA_CHEST_GOLD := 45
const ARENA_CHEST_XP := 8
## Дрібнота орди й ватажок: частки від звичайного ворога рівня.
const MINION_HP := 0.3
const MINION_DAMAGE := 0.5
const MINION_SIZE := 0.72
## Ватажок ще й еліта з двома рисами — тож власні множники скромні.
const CHAMPION_HP := 1.4
const CHAMPION_DAMAGE := 1.1
const CHAMPION_SIZE := 1.1

## ЕЛІТА: шанс, що звичайний ворог рівня виявиться елітним (EliteAffixes),
## і скільки золота дає елітний ворог порівняно зі звичайним.
const ELITE_CHANCE := [0.07, 0.1, 0.13]
const ELITE_GOLD := 3

## СЕРІЯ УДАРІВ (ComboMeter): нагороди на порогах 10 / 25 / 50 ударів
## без пропущеного удару по собі.
const COMBO_ATTACK_SPEED := 1.15
const COMBO_DAMAGE := 1.3
const COMBO_HEAL := 0.15
const COMBO_BUFF_TIME := 6.0
const COMBO_COLOR := Color(1.0, 0.86, 0.4)
const PERFECT_DODGE_COLOR := Color(0.5, 0.95, 1.0)

## СФЕРИ ЗДОРОВ'Я (HealthOrb): шанс, що випаде зі звичайного ворога й з еліти.
const HEALTH_ORB_CHANCE := 0.1
const HEALTH_ORB_ELITE_CHANCE := 0.7

## ВІДЧУТТЯ ВБИВСТВА. Кожне вбивство на мить пригальмовує гру, а бос —
## майже на секунду: перемога має відчуватись.
const KILL_HITSTOP := 0.05
const BOSS_SLOWMO_SECONDS := 0.9
const BOSS_SLOWMO_SCALE := 0.3

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
var _boss_spot := Vector3.ZERO
## Скільки секунд триває похід (для підсумків) і чи вже воскресали.
var _run_time := 0.0
var _revive_used := false
var _results: RunResults
var _exit_guide: ExitGuide
var _map_rows: Array = []
var _chunks: Array = []
var _lights: Array = []
var _stream_left := 0.0
var _run_gold := 0
var _level: Dictionary = {}
var _theme: Dictionary = {}
var _hp_scale := 1.0
## Звичайні вороги (не боси) міцніші: з 1-2 ударів падати не мають.
const MOB_HP_FACTOR := 1.7
var _damage_scale := 1.0
var _gold_scale := 1.0
var _models: Dictionary = {}
var _alive_summons := 0
## Що герой уже взяв у цьому поході: id здібності -> рівень.
var _run_upgrades: Dictionary = {}
var _buff_bar: HFlowContainer
var _loot: LootSwarm
## Розкладка бочок, пасток і святилищ (DungeonBuilder.place_props).
var _props_plan: Dictionary = {}
var _shrine_label: Label
## Мітки ворогів усередині засідок: такі вороги не стоять із самого
## початку, а вилазять хвилями.
var _arena_spawns: Array = []
var _arena_status := ""
var _banner: Control
var _callout: Control
var _combo: ComboMeter
var _last_hp := 0.0
var _offering_ability := false
## Бос рівня і його велика смуга здоров'я внизу екрана.
var _boss: Enemy3D
## Темрява в залі боса ("darkness" в описі, остання фаза): факели згасли.
var _darkness := false
var _ambient_energy := 1.0
const DARK_AMBIENT := 0.12
var _boss_panel: Control
var _boss_bar: ProgressBar
## Мега-бос (boss_gate у описі рівня): бос не стоїть від початку, а чекає,
## поки ворота зачиняться й відгримить вступне кіно (BossIntro).
var _boss_gate: BossGate
var _pending_boss_position := Vector3.ZERO
var _hud_title: Label
var _hud_gold: CurrencyBadge
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
	# Де стоятимуть бочки, пастки й святилища — до збирання шматків, щоб
	# прикраси не лягли на ті самі клітинки.
	_props_plan = DungeonBuilder.place_props(level.map, markers, 7919 * (_level_index + 1),
		1 if _level_index == 0 else 2)
	_chunks = markers.chunks
	_lights = markers.lights

	player.global_position = markers.start + Vector3(0, 0.2, 0)
	_exit_position = markers.exit
	_boss_spot = markers.boss
	_setup_hud(level.title)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	# Здобич з убитих ворогів летить до героя й зараховується, коли долетить.
	_loot = LootSwarm.new()
	add_child(_loot)
	_loot.setup(player)
	_loot.collected.connect(_on_loot_collected)
	PerfSettings.quality_changed.connect(_on_quality_changed)

	# Карту прохідності печемо ПІСЛЯ того, як перешкоди створено: інакше
	# ворогам не буде по чому рахувати маршрут. Печеться у фоні — тим
	# часом по одному шматку за кадр збираємо найближчі зали.
	# Меблі, скрині, мотлох завбільшки з бочку — тверді (і на карті
	# прохідності теж: вороги їх обходять, а не застрягають).
	DungeonBuilder.add_decor_obstacles(level_root.get_node("Obstacles") as StaticBody3D, _map_rows, _chunks,
		PerfSettings.get_value("decor_density"), _theme, _props_plan.reserved)
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
	_spawn_props()
	_spawn_arenas()
	_spawn_boss_gate()
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
	camera_touch.attack_held_changed.connect(player.set_attack_held)

	# Бойові кнопки — поверх зони камери: дотик по кнопці забирає кнопка.
	var combat_buttons: Control = COMBAT_BUTTONS_SCRIPT.new()
	hud.add_child(combat_buttons)
	combat_buttons.setup(player)
	_build_boss_bar()
	# Серія ударів — праворуч над бойовими кнопками.
	_combo = ComboMeter.new()
	hud.add_child(_combo)
	_combo.tier_reached.connect(_on_combo_tier)
	player.hit_landed.connect(func(_amount: float, _crit: bool) -> void: _combo.add_hit())
	player.perfect_dodge.connect(_on_perfect_dodge)
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

	# Сила святилища, поки діє: назва й скільки секунд лишилось.
	_shrine_label = Label.new()
	UiTheme.hud_text(_shrine_label, 15)
	_shrine_label.visible = false

	# Золото походу — монетою поруч зі станом данжу, не словом у рядку.
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(status_row)
	_hud_gold = CurrencyBadge.new(&"gold", 15, false)
	status_row.add_child(_hud_gold)
	status_label.reparent(status_row, false)
	UiTheme.hud_text(status_label, 15, UiTheme.TEXT_DIM.lightened(0.25))

	corner.add_child(_shrine_label)
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
	if _run_over or get_tree().paused or _pause_menu != null or _results != null:
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
	var arenas: Array = _level.get("arenas", [])
	_arena_spawns.clear()
	for i in arenas.size():
		_arena_spawns.append([])
	for spawn: Dictionary in markers.spawns:
		var arena_index := _arena_at(DungeonBuilder.cell_of(spawn.position))
		if arena_index >= 0:
			_arena_spawns[arena_index].append(spawn)
			continue
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
		if _level.get("boss_gate", false):
			# Мега-бос не виходить одразу: чекає за воротами (_spawn_boss_gate).
			_pending_boss_position = markers.boss
		else:
			_spawn_enemy(markers.boss, _level.boss, true)

func _arena_at(cell: Vector2i) -> int:
	var arenas: Array = _level.get("arenas", [])
	for i in arenas.size():
		if (arenas[i] as Rect2i).has_point(cell):
			return i
	return -1

## Мега-бос (рівень з "boss_gate"): ворота на всю залу з босом — герой
## заходить, виходи зачиняються, а сам бос виходить лише після вступного
## кіно (_start_boss_encounter).
func _spawn_boss_gate() -> void:
	if not _level.get("boss_gate", false) or _pending_boss_position == Vector3.ZERO:
		return
	var rect: Rect2i = _level.get("boss_arena", Rect2i())
	_boss_gate = BossGate.new()
	add_child(_boss_gate)
	_boss_gate.setup(player, _map_rows, rect)
	_boss_gate.sealed.connect(_start_boss_encounter)

## Ворота щойно зачинились: пауза, вступне кіно (модель боса й агресивний
## напис), і лише тоді бос виринає з підлоги в бій.
func _start_boss_encounter() -> void:
	var boss_def: Dictionary = _level.boss
	get_tree().paused = true
	var intro := BossIntro.new()
	intro.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(intro)
	intro.setup(_model(boss_def.model), boss_def.get("tint", Color.WHITE), boss_def.get("glow", Color.BLACK),
		_level.get("boss_title", boss_def.get("name", "Бос")), _level.get("boss_flavor", ""))
	await intro.finished
	intro.queue_free()
	get_tree().paused = false
	var boss := _spawn_enemy(_pending_boss_position, boss_def, true)
	var reveal_color: Color = boss_def.get("tint", Color(0.85, 0.16, 0.2))
	if reveal_color == Color.WHITE:
		reveal_color = Color(0.85, 0.16, 0.2)
	CombatVfx.shockwave(self, boss.global_position, 3.5, reveal_color, 0.5)
	CombatVfx.impact(self, boss.global_position + Vector3.UP * boss.target_height * 0.6, reveal_color, true)
	boss.emerge(1.1)
	player.shake_camera(0.2)

## Засідки: зали, що зачиняються, щойно герой зайде, і вороги вилазять
## хвилями (ArenaAmbush).
func _spawn_arenas() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4201 + _level_index
	var arenas: Array = _level.get("arenas", [])
	for i in arenas.size():
		var arena := ArenaAmbush.new()
		add_child(arena)
		# Остання засідка рівня (з другого рівня) — завжди з ватажком.
		var final := i == arenas.size() - 1 and _level_index > 0
		arena.setup(player, _map_rows, arenas[i], _plan_arena_waves(_arena_spawns[i], rng, final),
			func(position: Vector3, definition: Dictionary) -> Enemy3D:
				return _spawn_enemy(position, definition, false),
			PerfSettings.get_value("arena_max_enemies"))
		arena.started.connect(_shut_out_around.bind(arena))
		arena.wave_started.connect(_on_arena_wave)
		arena.cleared.connect(_on_arena_cleared)

## Засідка почалась: вороги поза залою героя "не чують", доки вона триває,
## — інакше сусідня кімната збігалась до ґраток. Ті, хто встиг забігти
## в залу, б'ються разом із хвилями.
func _shut_out_around(arena: ArenaAmbush) -> void:
	for node in enemies_root.get_children():
		var enemy := node as Enemy3D
		if enemy != null and enemy.is_alive():
			enemy.shut_out = not arena.contains(enemy.global_position)
			# Ті, хто вже в залі, б'ються з хвилями — і теж ідуть на героя.
			if not enemy.shut_out:
				enemy.hunting = true
				enemy.alert()

func _release_shut_out() -> void:
	for node in enemies_root.get_children():
		var enemy := node as Enemy3D
		if enemy != null:
			enemy.shut_out = false
			enemy.hunting = false

## ХВИЛІ ЗАСІДКИ: 1) половина тих, хто жив у залі; 2) решта разом з
## ордою дрібноти; 3) у великій залі чи в останній засідці рівня — ще
## загін і ватажок.
func _plan_arena_waves(spawns: Array, rng: RandomNumberGenerator, final: bool) -> Array:
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
	if (spawns.size() >= 6 or final) and not entries.is_empty():
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
	minion.no_elite = true
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
	champion.xp = int(best.get("xp", 3)) * 3
	champion.elite = 2
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
	_release_shut_out()
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

## Вільне місце для ворога поруч із бажаним: стіл, саркофаг чи колона на
## місці появи — шукаємо найближче вільне по колах довкола.
func _clear_spot(position: Vector3) -> Vector3:
	var world := get_world_3d()
	if Enemy3D.is_spot_clear(world, position):
		return position
	for ring in [0.9, 1.6, 2.4, 3.2]:
		for i in 8:
			var angle := TAU * i / 8.0
			var spot: Vector3 = position + Vector3(cos(angle), 0.0, sin(angle)) * ring
			var cell := DungeonBuilder.cell_of(spot)
			if DungeonBuilder.is_walkable(_map_rows, cell.x, cell.y) and Enemy3D.is_spot_clear(world, spot):
				return spot
	return position

## Бос перейшов у нову фазу — великий напис.
func _on_boss_phase(phase: int, title: String) -> void:
	_show_banner(title, "швидший і небезпечніший" if phase == 2 else "останній ривок!")
	if phase == 3 and _boss != null and is_instance_valid(_boss) and _boss.definition.get("darkness", false):
		_set_darkness()

## Рев гасить факели: загальне світло й факели згасають, світиться лише
## ліхтар героя та свічки на плечі боса.
func _set_darkness() -> void:
	_darkness = true
	var environment: Environment = $WorldEnvironment.environment
	_ambient_energy = environment.ambient_light_energy
	var tween := create_tween().set_parallel(true)
	tween.tween_property(environment, "ambient_light_energy", DARK_AMBIENT, 0.8)
	for light: OmniLight3D in _lights:
		if not light.has_meta("energy"):
			light.set_meta("energy", light.light_energy)
		tween.tween_property(light, "light_energy", 0.0, 0.5 + randf() * 0.4)
	player.set_torch_enabled(true)
	_boss.light_candles()

## Бос упав у темряві — факели спалахують знову, один за одним.
func _relight(center: Vector3) -> void:
	_darkness = false
	var environment: Environment = $WorldEnvironment.environment
	var tween := create_tween().set_parallel(true)
	tween.tween_property(environment, "ambient_light_energy", _ambient_energy, 1.6).set_delay(0.3)
	for light: OmniLight3D in _lights:
		var delay := 0.3 + light.global_position.distance_to(center) * 0.04
		var energy: float = light.get_meta("energy", 1.0)
		tween.tween_property(light, "light_energy", energy * 1.8, 0.25).set_delay(delay)
		tween.chain().tween_property(light, "light_energy", energy, 0.6)
	CombatVfx.shockwave(self, center, 12.0, Color(1.0, 0.75, 0.35), 1.2)

## Смуга здоров'я боса внизу посередині: видно, щойно бій почався.
func _build_boss_bar() -> void:
	_boss_panel = VBoxContainer.new()
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_panel.offset_left = -230.0
	_boss_panel.offset_right = 230.0
	_boss_panel.offset_top = -78.0
	_boss_panel.offset_bottom = -30.0
	_boss_panel.add_theme_constant_override("separation", 2)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.hud_text(name_label, 18, UiTheme.HEADING)
	_boss_panel.add_child(name_label)
	_boss_bar = UiTheme.make_bar(Color(0.8, 0.16, 0.2), Vector2(460, 16))
	_boss_panel.add_child(_boss_bar)
	# Позначки фаз: на половині й чверті здоров'я бос змінюється.
	for threshold: float in BossPhases.THRESHOLDS:
		var tick := ColorRect.new()
		tick.color = Color(UiTheme.LINE, 0.8)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.size = Vector2(2, 16)
		tick.position = Vector2(460.0 * threshold - 1.0, 0)
		_boss_bar.add_child(tick)
	_boss_panel.visible = false
	hud.add_child(_boss_panel)

func _update_boss_bar() -> void:
	if _boss_panel == null:
		return
	var shown := _boss != null and is_instance_valid(_boss) and _boss.is_aggro()
	_boss_panel.visible = shown
	if shown:
		(_boss_panel.get_node("Name") as Label).text = _boss.display_name
		_boss_bar.max_value = _boss.max_hp
		_boss_bar.value = _boss.current_hp

func _on_combo_tier(tier: int, title: String) -> void:
	var reward := ""
	match tier:
		1:
			player.add_attack_speed(COMBO_ATTACK_SPEED, COMBO_BUFF_TIME)
			reward = "удари швидші"
		2:
			player.add_damage_buff(COMBO_DAMAGE, COMBO_BUFF_TIME)
			reward = "+30% шкоди"
		3:
			player.heal(player.max_hp * COMBO_HEAL)
			reward = "+15% здоров'я"
	_show_callout(title, reward, COMBO_COLOR)

func _on_perfect_dodge() -> void:
	_show_callout("Ідеально!", "2 с усі удари критичні", PERFECT_DODGE_COLOR)

## Короткий напис посеред екрана ("Ідеально!", "Серія!") — вискакує й
## тане за секунду, не заважаючи бою.
func _show_callout(title: String, subtitle: String, color: Color) -> void:
	if _callout != null and is_instance_valid(_callout):
		_callout.queue_free()
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.hud_text(heading, 32, color)
	column.add_child(heading)
	if subtitle != "":
		var line := Label.new()
		line.text = subtitle
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiTheme.hud_text(line, 16)
		column.add_child(line)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	holder.offset_top = -150.0
	holder.offset_bottom = -70.0
	holder.add_child(column)
	hud.add_child(holder)
	_callout = holder
	holder.pivot_offset = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 40)
	holder.scale = Vector2.ONE * 1.35
	var tween := holder.create_tween()
	tween.tween_property(holder, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.7)
	tween.tween_property(holder, "modulate:a", 0.0, 0.35)
	tween.tween_callback(holder.queue_free)

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

## Вибухові бочки, шипи й святилища — там, де їх розклав place_props.
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

func _spawn_enemy(position: Vector3, definition: Dictionary, is_boss: bool) -> Enemy3D:
	var enemy: Enemy3D = ENEMY_SCRIPT.new()
	enemy.collision_layer = 4
	enemy.collision_mask = 1
	if is_boss:
		enemy.configure_boss(definition, _hp_scale, _damage_scale)
	else:
		enemy.configure(definition, _hp_scale * MOB_HP_FACTOR, _damage_scale)
		# Еліта: риси задані в описі ("affixes"), або їх кількість ("elite"),
		# або випадок (ELITE_CHANCE). "no_elite" — ніколи (дрібнота орди).
		var affixes: Array = definition.get("affixes", [])
		var affix_count := int(definition.get("elite", 0))
		if affixes.is_empty() and affix_count == 0 and not definition.get("no_elite", false) \
				and randf() < ELITE_CHANCE[mini(_level_index, ELITE_CHANCE.size() - 1)]:
			affix_count = 1
		if affixes.is_empty() and affix_count > 0:
			affixes = EliteAffixes.INFO.keys()
			affixes.shuffle()
			affixes = affixes.slice(0, affix_count)
		if not affixes.is_empty():
			enemy.make_elite(affixes)

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
	enemy.global_position = _clear_spot(position) + Vector3(0, 0.2, 0)
	enemy.setup(player, _model(definition.model))
	enemy.died.connect(_on_enemy_died.bind(enemy.kind, enemy.elite != null))
	enemy.spawn_requested.connect(_on_spawn_requested)
	enemy.ward_broken.connect(_on_ward_broken.bind(enemy))
	if is_boss:
		enemy.summon_requested.connect(_on_summon_requested)
		enemy.phases.phase_changed.connect(_on_boss_phase)
		_boss = enemy
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

## Здібність кличе істоту (RaiseDead — мерців, Split — половинки слизу,
## Pylons — пілони довкола боса). source рахує своїх живих (summons_alive)
## — Pylons так дізнається, коли впав останній.
func _on_spawn_requested(position: Vector3, definition: Dictionary, source: Enemy3D) -> void:
	var enemy := _spawn_enemy(position, definition, false)
	if source != null and is_instance_valid(source):
		source.summons_alive += 1
		enemy.died.connect(func(_p: Vector3, _xp: int) -> void:
			if is_instance_valid(source):
				source.summons_alive -= 1)
		# Двійники живуть, лише поки живий їхній господар.
		if definition.get("kind", "") == "decoy":
			source.died.connect(func(_p: Vector3, _xp: int) -> void:
				if is_instance_valid(enemy) and enemy.is_alive():
					enemy.take_damage(1.0e9))

## Пілони боса всі впали — він на кілька секунд відкритий для ударів.
func _on_ward_broken(boss: Enemy3D) -> void:
	_show_banner("%s знесилений!" % boss.display_name, "б'є щосили")

func _on_enemy_died(position: Vector3, xp_reward: int, kind: Enemy3D.Kind, is_elite: bool) -> void:
	_alive_enemies -= 1
	var is_boss := kind == Enemy3D.Kind.BOSS
	# Золото й досвід вилітають фонтаном і зараховуються, коли долетять до
	# героя (_on_loot_collected). Еліта сипле втричі щедріше.
	var gold := int(round((GOLD_PER_BOSS if is_boss else GOLD_PER_KILL) * _gold_scale * (ELITE_GOLD if is_elite else 1)))
	var pieces := 12 if is_boss else (8 if is_elite else clampi(gold / 3, 1, 4))
	_loot.burst(position, LootSwarm.Kind.GOLD, gold, pieces)
	_loot.burst(position, LootSwarm.Kind.XP, xp_reward, 6 if is_boss or is_elite else clampi(xp_reward, 1, 3))
	if not is_boss and randf() < (HEALTH_ORB_ELITE_CHANCE if is_elite else HEALTH_ORB_CHANCE):
		var orb := HealthOrb.new()
		orb.setup(player)
		add_child(orb)
		orb.global_position = position + Vector3(0, DungeonBuilder.FLOOR_TOP, 0)
	if is_boss:
		_boss_defeated = true
		if _darkness:
			_relight(position)
		_celebrate_boss(position)
		_open_exit()
		if _boss_gate != null:
			_boss_gate.open()
	elif is_elite:
		# Упала еліта — довша зупинка кадру й золота хвиля.
		CombatVfx.hitstop(get_tree(), KILL_HITSTOP * 2.0)
		CombatVfx.shockwave(self, position, 3.0, Enemy3D.ELITE_BAR_COLOR, 0.45)
		player.shake_camera(0.12)
	else:
		CombatVfx.hitstop(get_tree(), KILL_HITSTOP)
	_update_status()

func _on_loot_collected(kind: int, amount: int) -> void:
	if kind == LootSwarm.Kind.GOLD:
		AudioManager.play(&"gold")
		_add_gold(amount)
	else:
		AudioManager.play(&"pickup")
		_add_xp(amount)

## Бос упав: сповільнення, велика хвиля й трус камери.
func _celebrate_boss(position: Vector3) -> void:
	CombatVfx.hitstop(get_tree(), BOSS_SLOWMO_SECONDS, BOSS_SLOWMO_SCALE)
	CombatVfx.shockwave(self, position, 7.0, Color(1.0, 0.78, 0.4), 0.8)
	CombatVfx.impact(self, position + Vector3.UP * 1.6, Color(1.0, 0.85, 0.45), true)
	player.shake_camera(0.35)

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
	# Вікна вибору йдуть по черзі: здібність зі скрині засідки й новий
	# рівень від досвіду, що саме долетів, можуть збігтися. Два вікна
	# одночасно зняли б паузу, поки друге ще відкрите.
	while _offering_ability:
		await get_tree().process_frame
	_offering_ability = true
	await _show_ability_choice()
	_offering_ability = false

func _show_ability_choice() -> void:
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

## Вихід відчиняється лише після боса: у стіні кімнати боса розкривається
## портал (як прохід у данж у місті), а довкола героя з'являється
## стрілка, що веде до нього (ExitGuide).
func _open_exit() -> void:
	_exit_open = true
	var face := _exit_position
	var inward := Vector3.BACK
	var spot := _boss_spot if _boss_spot != Vector3.ZERO else _exit_position
	var wall := DungeonBuilder.portal_wall(_map_rows, DungeonBuilder.cell_of(spot))
	if not wall.is_empty():
		face = wall.face
		inward = wall.inward
	var gate := _make_exit_portal()
	level_root.add_child(gate)
	gate.position = Vector3(face.x, 0.0, face.z) + inward * PORTAL_WALL_OFFSET
	gate.rotation.y = atan2(inward.x, inward.z)
	# Кнопка виходу — коли герой стоїть перед порталом.
	_exit_position = gate.position + inward * 1.2
	# Портал розкривається: виростає з нуля.
	gate.scale = Vector3(1.0, 0.05, 1.0)
	var tween := gate.create_tween()
	tween.tween_property(gate, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	CombatVfx.shockwave(self, _exit_position, 2.4, Color(0.66, 0.45, 1.0), 0.6)

	_exit_guide = ExitGuide.new()
	add_child(_exit_guide)
	_exit_guide.setup(player, _exit_position)
	_update_status()

## Арка з вихровою пеленою й фіолетовим сяйвом — дивиться вздовж +Z.
func _make_exit_portal() -> Node3D:
	var gate := Node3D.new()
	gate.name = "ExitPortal"
	var arch: Node3D = EXIT_ARCH_SCENE.instantiate()
	arch.scale = Vector3.ONE * EXIT_ARCH_SCALE
	gate.add_child(arch)
	var veil := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PORTAL_SIZE
	veil.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = PORTAL_SHADER
	veil.material_override = material
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	veil.position = Vector3(0.0, PORTAL_SIZE.y * 0.5 + 0.06, 0.12)
	gate.add_child(veil)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.66, 0.45, 1.0)
	glow.light_energy = 3.0
	glow.omni_range = 9.0
	glow.position = Vector3(0.0, 1.8, 1.6)
	gate.add_child(glow)
	return gate

func _process(delta: float) -> void:
	if not _run_over:
		_run_time += delta
	_update_shrine_label()
	_update_boss_bar()
	_stream_left -= delta
	if _stream_left <= 0.0:
		_stream_left = STREAM_INTERVAL
		_update_streaming()

	if not _exit_open:
		return
	# Підійшов до відчиненого виходу — можна йти далі. Коли вже обирає,
	# куди йти, кнопка не потрібна.
	var offset := player.global_position - _exit_position
	offset.y = 0.0
	exit_button.visible = _results == null and offset.length() < EXIT_REACH

func _update_shrine_label() -> void:
	var buff: Dictionary = player.get_shrine_buff()
	var text := ""
	if not buff.is_empty():
		var info: Dictionary = Shrine.KINDS[buff.kind]
		text = "%s — ще %d с" % [info.title, ceili(buff.left)]
		_shrine_label.add_theme_color_override("font_color", info.color)
	if text != _shrine_label.text:
		_shrine_label.text = text
		_shrine_label.visible = text != ""

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
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"), _theme,
				_props_plan.get("reserved", {}))
			built_one = true
		chunk.node.visible = chunk.built and distance < view_distance

	_update_lights(origin, view_distance)
	_update_enemies(origin)

## Під час завантаження: будує наступний ще не збудований шматок.
## Повертає false, коли всі зібрані.
func _build_next_chunk() -> bool:
	for chunk: Dictionary in _chunks:
		if not chunk.built:
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"), _theme,
				_props_plan.get("reserved", {}))
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
	var models: Array = [EXIT_ARCH_SCENE, ExplosiveBarrel.BARREL_SCENE, SpikeTrap.PLATE_SCENE,
		SpikeTrap.SPIKES_SCENE, Shrine.PEDESTAL_SCENE, ArenaAmbush.BARS_SCENE, RewardChest.CHEST_SCENE]
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
	_loot.warm_up(center)
	var marker := CombatVfx.make_ground_marker(Color(1.0, 0.22, 0.15, 0.85), 1.0, 1.0)
	holder.add_child(marker)
	marker.global_position = center - Vector3(0, 0.9, 0)
	var line := CombatVfx.make_line_marker(Color(1.0, 0.3, 0.2, 0.85), 2.0, 1.0)
	holder.add_child(line)
	line.global_position = center - Vector3(0, 0.9, 0)
	var telegraph := CombatVfx.make_telegraph(Color(1.0, 0.22, 0.15, 0.85), 1.2, PI, true)
	holder.add_child(telegraph)
	telegraph.global_position = center - Vector3(0, 0.9, 0)
	var strip := CombatVfx.make_line_telegraph(Color(1.0, 0.3, 0.2, 0.85), 2.0, 1.0)
	holder.add_child(strip)
	strip.global_position = center - Vector3(0, 0.9, 0)
	CombatVfx.impact_decal(holder, center - Vector3(0, 0.9, 0), 1.0, Color(1.0, 0.45, 0.1))
	var portal := _make_exit_portal()
	holder.add_child(portal)
	portal.global_position = center - Vector3(0, 0.9, 0)
	portal.scale = Vector3.ONE * 0.2
	var guide := ExitGuide.new()
	holder.add_child(guide)
	guide.setup(player, center + Vector3(0, 0, 20))
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
		# Ворог засідки не спить, хоч би як далеко був у великій залі: інакше
		# частина хвилі завмирала б, і героя змушувало б її шукати.
		(enemy as Enemy3D).set_sleeping(distance > awake_distance and not (enemy as Enemy3D).hunting)
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
	if _arena_status != "":
		state = _arena_status
	_hud_title.text = "%s  •  рівень героя %d" % [level_title, _hero_level]
	_hud_gold.set_amount(_run_gold)
	status_label.text = "•   ворогів %d   •   %s" % [_alive_enemies, state]
	# Смужка досвіду — скільки лишилось до наступного вибору здібності.
	_xp_bar.max_value = XP_PER_LEVEL * _hero_level
	_xp_bar.value = _xp

## Герой загинув — це має бути видно, а не виглядати як "застряг".
## Герой упав. Раз за похід можна повернутись у бій за відео (80%
## здоров'я й щит на 3 с); відмовився — підсумки поразки.
func _on_player_died() -> void:
	# Мить на анімацію падіння, а вже тоді вікно.
	await get_tree().create_timer(1.1).timeout
	if _revive_used:
		_show_results(false)
		return
	_offer_revive()

func _offer_revive() -> void:
	get_tree().paused = true
	var dialog := OrnateDialog.new("Ти впав!", null, Color(1.0, 0.4, 0.35), 560.0, "Останній шанс")
	dialog.closable = false
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.add_text("Переглянь коротке відео — і повернешся в бій з 80% здоров'я та золотим щитом на 3 секунди.")
	dialog.add_text("Перезарядка здібностей лишиться, як була, а перекат буде готовий одразу.", 15,
		Color(1, 1, 1, 0.75))
	dialog.add_button("Відео: воскреснути", true, func() -> void:
		dialog.close()
		AdsManager.show_rewarded_ad(_on_revive_watched, _on_revive_skipped), 300.0)
	dialog.add_button("Здатися", false, func() -> void:
		dialog.close()
		_show_results(false), 200.0)
	hud.add_child(dialog)

func _on_revive_watched() -> void:
	_revive_used = true
	get_tree().paused = false
	player.revive(REVIVE_HP, REVIVE_SHIELD)
	_show_banner("Знову в бою!", "щит на %d с" % int(REVIVE_SHIELD))

## Відео закрили раніше — пропозиція лишається (можна передумати й здатись).
func _on_revive_skipped() -> void:
	_offer_revive()

## ПІДСУМКИ ПОХОДУ (RunResults): табличка перемоги чи поразки — шкода
## героя, золото, час, дві здібності й зброя.
func _show_results(victory: bool) -> void:
	if _results != null:
		return
	_run_over = true
	get_tree().paused = true
	_results = RunResults.new()
	_results.process_mode = Node.PROCESS_MODE_ALWAYS
	_results.setup(_results_data(victory))
	_results.home_pressed.connect(_leave_to.bind(MAIN_MENU_PATH, "Меню"))
	_results.town_pressed.connect(_leave_to.bind(BASE_SCENE_PATH, "Місто"))
	_results.double_pressed.connect(_on_double_gold_pressed)
	hud.add_child(_results)

func _results_data(victory: bool) -> Dictionary:
	var meter: Dictionary = player.damage_by_source
	var total := 0.0
	for value: float in meter.values():
		total += value
	var rows: Array = []
	var skills: Array = player.get_skills()
	for i in mini(skills.size(), 2):
		var skill: HeroSkill3D = skills[i]
		var icon := ArtSlots.skill_icon(skill.id)
		if icon == null:
			icon = ArtSlots.combat_icon(skill.icon_kind)
		rows.append({"title": skill.title, "icon": ArtSlots.icon_or_placeholder(icon, skill.color),
			"damage": float(meter.get(skill.id, 0.0)), "color": skill.color})
	var weapon: WeaponDef = player.weapon_def
	if weapon != null:
		rows.append({"title": weapon.title,
			"icon": ArtSlots.icon_or_placeholder(ArtSlots.weapon_icon(weapon.id, weapon.icon), weapon.color),
			"damage": float(meter.get(&"weapon", 0.0)), "color": weapon.color})
	return {
		"victory": victory,
		"level_title": _level.title,
		"seconds": int(_run_time),
		"gold": _run_gold,
		"total_damage": total,
		"hero_id": player.hero_def.id if player.hero_def != null else &"",
		"rows": rows,
		"can_double": _run_gold > 0,
	}

## Жовта кнопка: відео — і золото походу ще раз.
func _on_double_gold_pressed() -> void:
	AdsManager.show_rewarded_ad(func() -> void:
		GameState.add_gold(_run_gold)
		_run_gold *= 2
		if _results != null:
			_results.set_double_done(true, _run_gold),
		func() -> void:
			if _results != null:
				_results.allow_double_again())

func _leave_to(path: String, title: String) -> void:
	get_tree().paused = false
	SceneLoader.change_scene(path, title)

func _on_player_health_changed(current: float, maximum: float) -> void:
	# Пропустив удар — серія згорає.
	if _combo != null and current < _last_hp - 0.01:
		_combo.reset()
	_last_hp = current
	health_label.text = "%d / %d" % [ceili(current), int(maximum)]
	_health_bar.max_value = maximum
	_health_bar.value = current

func _on_joystick_moved(direction: Vector2) -> void:
	player.set_move_input(Vector2(direction.x, -direction.y))

## Біля порталу виходу: нагорода за рівень і табличка перемоги.
func _on_exit_pressed() -> void:
	if _results != null:
		return
	_add_gold(int(round(GOLD_FOR_CLEAR * _gold_scale)))
	GameState.unlock_next_dungeon_level()
	exit_button.visible = false
	_show_results(true)

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
