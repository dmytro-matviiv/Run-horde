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
## Вороги не проходять крізь стіни й не застрягають за кутами: у данжі
## будується карта прохідності (NavigationRegion3D), по якій вони
## рахують маршрут.

const LEVEL_UP_CHOICE_SCENE := preload("res://scenes/ui/level_up_choice.tscn")
const JOYSTICK_SCENE := preload("res://scenes/ui/virtual_joystick.tscn")
const CAMERA_TOUCH_SCENE := preload("res://scenes/ui/camera_touch.tscn")
const COMBAT_BUTTONS_SCRIPT := preload("res://scenes/ui/combat_buttons.gd")
const ENEMY_SCRIPT := preload("res://scenes/dungeon/enemy_3d.gd")
const EXIT_SCENE := preload("res://assets/models/dungeon/Arch_Door.fbx")

## Моделі ворогів під кожну роль.
const MELEE_MODELS := [
	preload("res://assets/models/monsters/Orc Enemy.glb"),
	preload("res://assets/models/monsters/Green Spiky Blob.glb"),
	preload("res://assets/models/monsters/Ghost Skull.glb"),
]
const RANGED_MODEL := preload("res://assets/models/monsters/Wizard.glb")
const BOSS_MODEL := preload("res://assets/models/monsters/Demon-LnfIziKv4o.glb")

const BASE_SCENE_PATH := "res://scenes/world/base_island.tscn"

## Скільки досвіду треба на наступний рівень героя в данжі.
const XP_PER_LEVEL := 12

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

## Збирання рівня розкладене на кілька кадрів і сховане за екраном
## завантаження (SceneLoader.hold): гравець бачить плавну смужку, а не
## застиглий екран. Карта прохідності печеться в окремому потоці.
func _ready() -> void:
	SceneLoader.hold()
	_level_index = GameState.dungeon_level
	var level := DungeonLevels.get_level(_level_index)
	_map_rows = level.map
	var markers := DungeonBuilder.build_base(level.map, level_root)
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
	while _build_next_visible_chunk():
		await get_tree().process_frame
	_update_streaming()
	if level_root.is_baking():
		await level_root.bake_finished

	_spawn_enemies(markers)
	_update_streaming()
	SceneLoader.release()

	# Вхідна кімната порожня, і перше, що робить гравець, — обирає
	# здібність. Далі вибір повторюється з кожним новим рівнем.
	await _offer_ability()

func _setup_hud(title: String) -> void:
	var joystick: Control = JOYSTICK_SCENE.instantiate()
	hud.add_child(joystick)
	joystick.direction_changed.connect(_on_joystick_moved)

	# Права половина екрана крутить камеру, короткий дотик по ній — удар.
	var camera_touch: Control = CAMERA_TOUCH_SCENE.instantiate()
	hud.add_child(camera_touch)
	$CameraRig.set_world_collision(false)
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

	hud.move_child(exit_button, hud.get_child_count() - 1)

	exit_button.visible = false
	exit_button.pressed.connect(_on_exit_pressed)
	_update_status(title)

## Підказка для ПК: які клавіші що роблять.
func _add_keyboard_hint() -> void:
	var hint := Label.new()
	hint.text = "Пробіл / ЛКМ — удар (утримуй — серія)   •   Shift — перекат   •   E — вихор   •   ПКМ — камера"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.position.y -= 8.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint)

func _spawn_enemies(markers: Dictionary) -> void:
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
	_alive_enemies += 1

func _on_enemy_died(_position: Vector3, xp_reward: int, kind: Enemy3D.Kind) -> void:
	_alive_enemies -= 1
	_add_xp(xp_reward)
	if kind == Enemy3D.Kind.BOSS:
		_boss_defeated = true
		_open_exit()

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
	var choices := UpgradePool.pick_choices({}, 0.0)
	if choices.is_empty():
		return
	get_tree().paused = true
	var choice_ui: Node = LEVEL_UP_CHOICE_SCENE.instantiate()
	choice_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(choice_ui)
	choice_ui.setup(_hero_level, choices, {})
	var picked: StringName = await choice_ui.upgrade_chosen
	choice_ui.queue_free()
	get_tree().paused = false
	player.apply_ability(picked)
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
	# Підійшов до відчиненого виходу — можна йти далі.
	exit_button.visible = player.global_position.distance_to(_exit_position) < 3.0

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
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"))
			built_one = true
		chunk.node.visible = chunk.built and distance < view_distance

	_update_lights(origin, view_distance)
	_update_enemies(origin)

## Під час завантаження: будує найближчий ще не збудований шматок, який
## опиниться в кадрі. Повертає false, коли таких не лишилось.
func _build_next_visible_chunk() -> bool:
	var origin := player.global_position
	var view_distance: float = PerfSettings.get_value("view_distance")
	for chunk: Dictionary in _chunks:
		if not chunk.built and _distance_to_chunk(origin, chunk) < view_distance:
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"))
			chunk.node.visible = true
			return true
	return false

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
	var state := "Бос попереду" if not _boss_defeated else "Вихід відчинено"
	status_label.text = "%s  •  рівень %d  •  досвід %d  •  ворогів %d  •  %s" % [
		level_title, _hero_level, _xp, _alive_enemies, state,
	]

## Герой загинув — це має бути видно, а не виглядати як "застряг".
func _on_player_died() -> void:
	status_label.text = "Ви загинули. Повертаємось на базу…"
	await get_tree().create_timer(2.0).timeout
	SceneLoader.change_scene(BASE_SCENE_PATH, "База")

func _on_player_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HP %d / %d" % [int(current), int(maximum)]

func _on_joystick_moved(direction: Vector2) -> void:
	player.set_move_input(Vector2(direction.x, -direction.y))

func _on_exit_pressed() -> void:
	# Пройшов данж — наступний рівень стає доступним.
	GameState.unlock_next_dungeon_level()
	SceneLoader.change_scene(BASE_SCENE_PATH, "База")

## Удар, перекат і вихір з клавіатури герой ловить сам (див. player_3d).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneLoader.change_scene(BASE_SCENE_PATH, "База")
