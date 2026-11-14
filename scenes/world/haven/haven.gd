extends Node3D

## ПРИХИСТОК — стартова локація героя (замість старого міста). Пагорби й
## тераси, площа з жителями (замість будівель): Наставниця героїв, Коваль
## (зброя), Мудрець (таланти), Торговка (крамниця) і Старійшина з
## квестами. Гай і кам'янистий пагорб — ресурси для квестів. Портал у
## данж — на верхній терасі.
##
## Новачка веде навчання: угорі підказка, що робити, над потрібним
## жителем чи ресурсом — стрілка, під ногами — вказівник напрямку. Навчання
## — це перші квести (QuestBook): познайомся з усіма, нарубай дров, збери
## трави, пройди перший рівень.
##
## ЩО ДАЮТЬ РЕСУРСИ (Boons). Квести тут не закінчуються золотом —
## принесене міняє Прихисток: дрова розпалюють багаття в таборі (біля
## нього тепер вечеряють перед походом: більше здоров'я), камінь лагодить
## точило Коваля (гостріння: більше шкоди), трави наповнюють казан
## Мудреця (зілля, що рятує в бою). Плюс п'ять загублених скринь Торговки
## по всій долині і щоденне доручення Старійшини.
##
## Сцену складає будівник (dev_scripts/haven/haven_builder.gd) за планом
## HavenLayout; тут — те, що оживає в грі.
##
## ЯКІСТЬ. Основа (ця сцена) — земля, фізика, жителі, ресурси. Стіни,
## сходи, будинки й природа лежать окремо у двох варіантах:
##   haven_detail.tscn — звичайні моделі (середня/висока якість);
##   haven_lite.tscn   — те саме, злите у великі шматки з легкими
##                       матеріалами (низька якість, слабкий телефон).
## Потрібний варіант підвантажується під поточну якість (_load_detail).

const JOYSTICK_SCENE := preload("res://scenes/ui/virtual_joystick.tscn")
const CAMERA_TOUCH_SCENE := preload("res://scenes/ui/camera_touch.tscn")
const DUNGEON_SELECT_SCRIPT := preload("res://scenes/ui/dungeon_select.gd")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
const DUNGEON_PATH := "res://scenes/dungeon/dungeon.tscn"
const NPC_DIR := "res://scenes/world/haven/npcs/"
const MENU_BUTTON_ART := "res://assets/ui/theme/button_menu.png"
const MENU_BUTTON_WIDTH := 140.0

## Куди ведуть дії жителів.
const ACTION_SCENES := {
	"heroes": "res://scenes/ui/heroes.tscn",
	"weapons": "res://scenes/ui/weapons.tscn",
	"talents": "res://scenes/ui/meta_upgrades.tscn",
	"shop": "res://scenes/ui/shop.tscn",
}
const RESOURCE_NAMES := {"wood": "Дерево", "stone": "Камінь", "herb": "Трави"}

## Камера як у Death's Door: вища й далі, під гарним кутом на північ.
const CAMERA_DISTANCE := 11.5
const CAMERA_PITCH := -42.0

const DETAIL_SCENE := "res://scenes/world/haven/haven_detail.tscn"
const LITE_SCENE := "res://scenes/world/haven/haven_lite.tscn"
## Повні деталі пакуються на ходу (однакові моделі — одна команда), і
## розмір ділянки пакування: дрібніші — те, що поза кадром, не малюється.
## Місця підготовки до походу: id переваги (Boons) -> де стоїть.
## Багаття — у таборі біля місця появи; точило — ковадло Коваля; казан —
## у Мудреця (так само, як їх ставить будівник).
const CAMP_FIRE := Vector3(4.5, 0.0, 31.0)
## Загублені скрині Торговки: за возом, на західному пагорбі, на краю гаю,
## за порталом, на південно-східній галявині.
const CACHES := {
	"wagon": Vector2(-8.5, 28.5), "hill": Vector2(-42.0, 0.0), "grove": Vector2(44.0, 18.0),
	"portal": Vector2(6.5, -28.0), "meadow": Vector2(16.0, 38.0),
}
const CACHE_GOLD := 120
const CHEST_MODEL := "res://assets/models/haven/props/Chest_Wood.gltf"
const BATCH_GROUPS := {"Architecture": 0.0, "Nature": 40.0}
## Як часто перераховувати, куди веде навчання (сама стрілка рухається
## щокадру, а мета міняється рідко).
const GUIDE_REFRESH := 0.25

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var hud: CanvasLayer = $HUD

var _action_button: Button
var _gold_badge: CurrencyBadge
var _gems_badge: CurrencyBadge
var _tracker: VBoxContainer
var _hint: Label
var _hint_panel: PanelContainer
var _toast: Label
var _dialog: NpcDialog
var _select: Control

var _npcs := {}
var _gatherables: Array[Gatherable] = []
var _portal: HavenPortal
## Що поруч (жителі, ресурси, портал): найближче — на кнопці дії.
var _nearby: Array = []
var _talking: HavenNpc

var _spots: Array[HavenSpot] = []
var _camp_fire: Node3D
var _bag: Label

var _guide_marker: Label3D
var _guide_arrow: MeshInstance3D
var _guide_goal_cache: Array = []
var _guide_wait := 0.0

## Підвантажені деталі (стіни, будинки, природа) і чи це легкий варіант.
var _detail: Node3D
var _detail_lite := false

func _ready() -> void:
	SceneLoader.hold()
	player.set_torch_enabled(false)
	player.combat_input_enabled = false
	_setup_camera()
	if GameState.town_return_spot != Vector3.INF:
		player.global_position = GameState.town_return_spot + Vector3.UP * 0.05
		GameState.town_return_spot = Vector3.INF
	else:
		player.global_position = ($SpawnSpot as Node3D).global_position
	camera_rig.snap_to_target()
	_build_hud()
	_spawn_npcs()
	_spawn_portal()
	_wrap_resources()
	_build_spots()
	_build_caches()
	_build_guide()
	GameState.quests_changed.connect(_on_quests_changed)
	_on_quests_changed()

	_light_fires()
	_refresh_spots()
	await get_tree().process_frame
	_load_detail()
	PerfSettings.quality_changed.connect(_on_quality_changed)
	await get_tree().process_frame
	SceneLoader.release()

## Стіни, сходи, будинки й природа — у варіанті під поточну якість.
func _load_detail() -> void:
	var lite := PerfSettings.quality == PerfSettings.Quality.LOW
	if _detail != null and lite == _detail_lite:
		return
	if _detail != null:
		_detail.queue_free()
	_detail_lite = lite
	_detail = (load(LITE_SCENE if lite else DETAIL_SCENE) as PackedScene).instantiate()
	add_child(_detail)
	if not lite:
		for group: String in BATCH_GROUPS:
			if _detail.has_node(group):
				TownBatcher.batch(_detail.get_node(group) as Node3D, BATCH_GROUPS[group])
	# Дерева на зруб, каміння й трави — окремі вузли: їм легкі матеріали.
	if has_node("Resources"):
		HavenLite.apply($Resources, lite)

## Гра сама опустила якість посеред локації (телефон не встигав) —
## міняємо деталі на легкий варіант.
func _on_quality_changed(_quality: int) -> void:
	_load_detail()

func _setup_camera() -> void:
	camera_rig.distance = CAMERA_DISTANCE
	camera_rig.spring_arm.spring_length = CAMERA_DISTANCE
	camera_rig.set("_pitch", deg_to_rad(CAMERA_PITCH))
	camera_rig.spring_arm.rotation_degrees.x = CAMERA_PITCH
	camera_rig.camera.fov = 44.0
	# Ближня й дальня межі камери щільніші за стандартні: точніша глибина —
	# близькі поверхні (бруківка на землі) не мерехтять одна крізь одну.
	camera_rig.camera.near = 0.3
	camera_rig.camera.far = 260.0
	camera_rig.set_world_collision(false)

# --- світ ---

func _spawn_npcs() -> void:
	for marker: Node3D in $Npcs.get_children():
		var id: StringName = marker.get_meta(&"npc", &"")
		var path := NPC_DIR + String(id) + ".scn"
		if id == &"" or not ResourceLoader.exists(path):
			continue
		var npc := HavenNpc.create(id, load(path))
		$Npcs.add_child(npc)
		npc.global_position = marker.global_position
		npc.rotation.y = marker.rotation.y
		npc.set_player(player)
		npc.player_near.connect(_on_near)
		npc.player_left.connect(_on_left)
		_npcs[id] = npc
	# Тверді: жителі не пропускають героя крізь себе.
	var body := StaticBody3D.new()
	add_child(body)
	for npc: HavenNpc in _npcs.values():
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.8
		shape.shape = capsule
		body.add_child(shape)
		shape.global_position = npc.global_position + Vector3.UP * 0.9

func _spawn_portal() -> void:
	_portal = HavenPortal.new()
	add_child(_portal)
	_portal.global_position = ($PortalSpot as Node3D).global_position
	_portal.set_player(player)
	_portal.player_near.connect(func() -> void: _on_near(_portal))
	_portal.player_left.connect(func() -> void: _on_left(_portal))

func _wrap_resources() -> void:
	if not has_node("Resources"):
		return
	for group in $Resources.get_children():
		for model: Node3D in group.get_children().duplicate():
			var kind: String = model.get_meta(&"resource", "")
			if kind == "":
				continue
			var node := Gatherable.wrap(model, kind)
			node.remember_pose()
			node.set_player(player)
			node.player_near.connect(_on_near)
			node.player_left.connect(_on_left)
			_gatherables.append(node)

## Вогонь у багатті й на стовпцях біля сходів: язики полум'я й теплий
## відсвіт — без справжнього світла (телефону його не рахувати).
func _light_fires() -> void:
	if not has_node("Effects"):
		return
	for marker: Node3D in $Effects.get_children():
		var fire := Fx.make_particles("flame_05", Color(1.0, 0.52, 0.18), PerfSettings.scaled_count(16), 0.55, 0.8, true, true)
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.emission_sphere_radius = 0.16
		fire.direction = Vector3.UP
		fire.spread = 10.0
		fire.initial_velocity_min = 0.5
		fire.initial_velocity_max = 1.1
		fire.gravity = Vector3(0, 1.3, 0)
		marker.add_child(fire)
		var spot := Vector2(marker.global_position.x, marker.global_position.z)
		if spot.distance_to(Vector2(CAMP_FIRE.x, CAMP_FIRE.z)) < 1.0:
			_camp_fire = fire

# --- підготовка до походу і загублені скрині ---

## Де стоїть місце переваги: багаття, ковадло Коваля, казан Мудреця.
func _boon_position(id: String) -> Vector3:
	match id:
		"meal":
			return Vector3(CAMP_FIRE.x, HavenLayout.height(CAMP_FIRE.x, CAMP_FIRE.z), CAMP_FIRE.z)
		"sharp":
			return _station_point(&"smith", Vector3(0.0, 0, 1.4))
		_:
			return _station_point(&"sage", Vector3(-2.4, 0, -1.0))

func _station_point(npc: StringName, local: Vector3) -> Vector3:
	var info: Array = HavenLayout.NPCS[npc]
	return (info[0] as Vector3) + Basis(Vector3.UP, float(info[1])) * local

func _build_spots() -> void:
	for id: String in Boons.BOONS:
		var spot := HavenSpot.new()
		spot.id = id
		spot.kind = "boon"
		spot.radius = 2.8 if id == "meal" else 2.4
		add_child(spot)
		spot.global_position = _boon_position(id)
		_add_spot(spot)

func _build_caches() -> void:
	var found := QuestBook.found_caches()
	for id: String in CACHES:
		if found.has(id):
			continue
		var at: Vector2 = CACHES[id]
		var spot := HavenSpot.new()
		spot.id = id
		spot.kind = "cache"
		spot.label = "Відкрити скриню"
		spot.radius = 2.5
		add_child(spot)
		spot.global_position = Vector3(at.x, HavenLayout.height(at.x, at.y), at.y)
		spot.rotation.y = randf() * TAU
		var chest: Node3D = (load(CHEST_MODEL) as PackedScene).instantiate()
		chest.scale = Vector3.ONE * 1.3
		spot.add_child(chest)
		HavenLite.apply(chest, PerfSettings.quality == PerfSettings.Quality.LOW)
		# Поблискує — щоб знайти здалеку.
		var shine := Fx.make_particles("star_04", Color(1.0, 0.85, 0.35), PerfSettings.scaled_count(6), 1.2, 0.35, true, true)
		shine.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		shine.emission_sphere_radius = 0.6
		shine.direction = Vector3.UP
		shine.initial_velocity_min = 0.2
		shine.initial_velocity_max = 0.5
		shine.gravity = Vector3.ZERO
		shine.position = Vector3.UP * 0.7
		spot.add_child(shine)
		_add_spot(spot)

func _add_spot(spot: HavenSpot) -> void:
	spot.set_player(player)
	spot.player_near.connect(_on_near)
	spot.player_left.connect(_on_left)
	_spots.append(spot)

## Хто що вміє зараз: місця переваг — лише відкриті квестом; багаття
## горить, коли квест із дровами здано.
func _refresh_spots() -> void:
	for spot in _spots:
		if spot.kind != "boon":
			continue
		spot.enabled = Boons.is_unlocked(spot.id)
		spot.label = "%s (%s)" % [Boons.BOONS[spot.id].verb, Boons.cost_text(spot.id)]
	if _camp_fire != null:
		_camp_fire.visible = Boons.is_unlocked("meal")
	_refresh_action()

func _use_spot(spot: HavenSpot) -> void:
	if spot.kind == "cache":
		_open_cache(spot)
		return
	var boon: Dictionary = Boons.BOONS[spot.id]
	var problem := Boons.problem(spot.id)
	if problem != "":
		_show_toast(problem, Color(1.0, 0.7, 0.55))
		return
	Boons.craft(spot.id)
	player.play_work(spot.global_position)
	var color := {"meal": Color(1.0, 0.6, 0.25), "sharp": Color(0.8, 0.9, 1.0), "potion": Color(0.45, 1.0, 0.5)}[spot.id] as Color
	Fx.wave(self, spot.global_position + Vector3.UP * 0.1, 1.8, color, 0.5)
	Fx.puff(self, spot.global_position + Vector3.UP * 0.8, color, 0.7, 0.2)
	_show_toast(String(boon.done), UiTheme.GOLD)
	_refresh_bag()

func _open_cache(spot: HavenSpot) -> void:
	QuestBook.found_caches().append(spot.id)
	GameState.add_gold(CACHE_GOLD)
	QuestBook.report("chest")
	SaveManager.save_game()
	spot.enabled = false
	_spots.erase(spot)
	Fx.wave(self, spot.global_position + Vector3.UP * 0.1, 1.6, UiTheme.GOLD, 0.45)
	Fx.puff(self, spot.global_position + Vector3.UP * 0.6, Color(1.0, 0.85, 0.4), 0.8, 0.2)
	var tween := spot.create_tween()
	tween.tween_property(spot, "scale", Vector3.ONE * 1.15, 0.12)
	tween.tween_property(spot, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(spot.queue_free)
	var left := CACHES.size() - QuestBook.found_caches().size()
	_show_toast("Загублена скриня! +%d золота%s" % [CACHE_GOLD, ("  (лишилось %d)" % left) if left > 0 else "  — усі знайдено!"], UiTheme.GOLD)
	_gold_badge.set_amount(GameState.gold)

## Торба: ресурси й що герой бере в похід.
func _refresh_bag() -> void:
	if _bag == null:
		return
	var parts := PackedStringArray()
	for resource: String in Boons.RESOURCE_TITLES:
		parts.append("%s %d" % [Boons.RESOURCE_TITLES[resource], int(GameState.resources.get(resource, 0))])
	var text := "  ".join(parts)
	var ready := Boons.summary()
	if ready != "":
		text += "\nУ похід: " + ready
	_bag.text = text

# --- інтерфейс ---

func _build_hud() -> void:
	var joystick: Control = JOYSTICK_SCENE.instantiate()
	hud.add_child(joystick)
	joystick.direction_changed.connect(_on_joystick_moved)
	var camera_touch: Control = CAMERA_TOUCH_SCENE.instantiate()
	hud.add_child(camera_touch)
	camera_touch.rotate_requested.connect(camera_rig.rotate_by)
	camera_touch.pitch_requested.connect(camera_rig.pitch_by)

	# Гаманець і квести — ліворуч угорі.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.hud_box())
	panel.position = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 16)
	column.add_child(wallet)
	_gold_badge = CurrencyBadge.new(&"gold", 18, false)
	wallet.add_child(_gold_badge)
	_gems_badge = CurrencyBadge.new(&"gem", 18, false)
	wallet.add_child(_gems_badge)
	_bag = Label.new()
	UiTheme.hud_text(_bag, 15, Color(0.85, 0.95, 0.8))
	column.add_child(_bag)
	_tracker = VBoxContainer.new()
	_tracker.add_theme_constant_override("separation", 2)
	column.add_child(_tracker)
	_gold_badge.set_amount(GameState.gold)
	_gems_badge.set_amount(GameState.gems)

	# Підказка навчання — угорі посередині.
	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override("panel", UiTheme.hud_box())
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.offset_top = 14.0
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_hint_panel)
	_hint = Label.new()
	UiTheme.hud_text(_hint, 19, UiTheme.GOLD)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint)

	# Короткі повідомлення: "+1 Дерево", "Завдання виконано".
	_toast = Label.new()
	UiTheme.hud_text(_toast, 24, UiTheme.TEXT)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.3
	_toast.anchor_bottom = 0.3
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_toast)

	var menu := Button.new()
	menu.anchor_left = 1.0
	menu.anchor_right = 1.0
	menu.offset_left = -16.0 - MENU_BUTTON_WIDTH
	menu.offset_right = -16.0
	menu.offset_top = 16.0
	menu.offset_bottom = 64.0
	UiTheme.art_button(menu, MENU_BUTTON_ART, 54, 23, "", 14)
	menu.pressed.connect(_on_menu_pressed)
	hud.add_child(menu)

	# Кнопка дії — поверх джойстика.
	_action_button = Button.new()
	_action_button.anchor_left = 0.5
	_action_button.anchor_right = 0.5
	_action_button.anchor_top = 1.0
	_action_button.anchor_bottom = 1.0
	_action_button.offset_left = -150.0
	_action_button.offset_right = 150.0
	_action_button.offset_top = -100.0
	_action_button.offset_bottom = -30.0
	_action_button.add_theme_font_size_override("font_size", 24)
	UiTheme.art_primary(_action_button)
	_action_button.visible = false
	_action_button.pressed.connect(_on_action_pressed)
	hud.add_child(_action_button)

	_dialog = NpcDialog.new()
	_dialog.visible = false
	_dialog.choice_made.connect(_on_dialog_choice)
	hud.add_child(_dialog)

func _show_toast(text: String, color: Color = UiTheme.TEXT) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	var tween := _toast.create_tween()
	_toast.modulate.a = 1.0
	_toast.position.y = 0.0
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6).set_delay(1.4)

## Квести в кутку: що зараз треба зробити.
func _refresh_tracker() -> void:
	for child in _tracker.get_children():
		child.queue_free()
	var shown := 0
	for quest: Dictionary in QuestBook.active_quests():
		if shown >= 2:
			break
		shown += 1
		var title := Label.new()
		UiTheme.hud_text(title, 16, UiTheme.GOLD)
		title.text = quest.title
		_tracker.add_child(title)
		if QuestBook.state_of(quest.id) == "ready":
			var line := Label.new()
			UiTheme.hud_text(line, 15, Color(0.6, 1.0, 0.6))
			line.text = "✔ Повернись %s" % HavenNpc.ROLES[quest.giver].to
			_tracker.add_child(line)
			continue
		for i in quest.objectives.size():
			var objective: Dictionary = quest.objectives[i]
			var have := QuestBook.objective_progress(quest.id, i)
			var line := Label.new()
			var done := have >= int(objective.count)
			UiTheme.hud_text(line, 15, Color(0.6, 1.0, 0.6) if done else UiTheme.TEXT)
			line.text = ("✔ " if done else "• ") + String(objective.label) + \
				("" if int(objective.count) == 1 else "  %d/%d" % [have, int(objective.count)])
			_tracker.add_child(line)

# --- поруч / кнопка дії ---

func _on_near(thing: Object) -> void:
	if not _nearby.has(thing):
		_nearby.append(thing)
	_refresh_action()

func _on_left(thing: Object) -> void:
	_nearby.erase(thing)
	_refresh_action()

func _closest() -> Object:
	var best: Object = null
	var best_d := INF
	for thing: Object in _nearby:
		var d := (thing as Node3D).global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = thing
	return best

func _refresh_action() -> void:
	var thing := _closest()
	if thing == null or _dialog.visible:
		_action_button.visible = false
		return
	if thing is HavenNpc:
		_action_button.text = "Говорити"
	elif thing is Gatherable:
		_action_button.text = (thing as Gatherable).verb()
	elif thing is HavenSpot:
		_action_button.text = (thing as HavenSpot).label
	else:
		_action_button.text = "У данж"
	_action_button.visible = true

func _on_action_pressed() -> void:
	var thing := _closest()
	if thing is HavenNpc:
		_talk(thing as HavenNpc)
	elif thing is Gatherable:
		var node := thing as Gatherable
		player.play_work(node.global_position)
		if node.work():
			GameState.add_resource(node.kind)
			_show_toast("+1 %s" % RESOURCE_NAMES.get(node.kind, node.kind), Color(0.85, 1.0, 0.7))
			_refresh_bag()
	elif thing is HavenSpot:
		_use_spot(thing as HavenSpot)
	elif thing == _portal:
		_open_dungeon_select()

func _process(delta: float) -> void:
	_guide_wait -= delta
	if _guide_wait <= 0.0:
		_guide_wait = GUIDE_REFRESH
		_guide_goal_cache = _guide_goal()
	_update_guide()

# --- розмова ---

func _talk(npc: HavenNpc) -> void:
	_talking = npc
	QuestBook.report("talk", 1, npc.id)
	var choices: Array = []
	var text: String = npc.info.line
	var ready := QuestBook.ready_for(npc.id)
	var offer := QuestBook.available_for(npc.id)
	if not ready.is_empty():
		text = String(ready.done_text)
		choices.append(["claim:" + String(ready.id), "Здати (%s)" % QuestBook.reward_text(ready), true])
	elif not offer.is_empty():
		text = String(offer.text)
		choices.append(["accept:" + String(offer.id), "Взяти завдання", true])
	if npc.info.action != "":
		choices.append(["open", String(npc.info.button), choices.is_empty()])
	choices.append(["bye", "До побачення", false])
	_dialog.show_line(String(npc.info.name), text, choices)
	_action_button.visible = false

func _on_dialog_choice(choice: String) -> void:
	var npc := _talking
	if choice.begins_with("accept:"):
		var id := choice.get_slice(":", 1)
		QuestBook.accept(id)
		_show_toast("Нове завдання: %s" % QuestBook.get_quest(id).title, UiTheme.GOLD)
		_dialog.visible = false
	elif choice.begins_with("claim:"):
		var reward := QuestBook.complete(choice.get_slice(":", 1))
		_gold_badge.set_amount(GameState.gold)
		_gems_badge.set_amount(GameState.gems)
		var boon := String(reward.get("boon", ""))
		if boon != "":
			_show_toast("Відкрито: %s — %s" % [Boons.BOONS[boon].title, Boons.BOONS[boon].effect], UiTheme.GOLD)
		else:
			_show_toast("Завдання виконано! %s" % QuestBook.reward_text(QuestBook.get_quest(choice.get_slice(":", 1))), UiTheme.GOLD)
		# Одразу — наступне завдання цього ж жителя, якщо є.
		if npc != null:
			_talk(npc)
			return
	elif choice == "open" and npc != null:
		var path: String = ACTION_SCENES.get(npc.info.action, "")
		if path != "":
			GameState.open_from_town(path, player.global_position)
			return
	else:
		_dialog.visible = false
	_refresh_action()

func _on_quests_changed() -> void:
	_guide_wait = 0.0
	for npc: HavenNpc in _npcs.values():
		npc.refresh_mark()
	_refresh_tracker()
	_refresh_spots()
	_refresh_bag()
	_gold_badge.set_amount(GameState.gold)
	_gems_badge.set_amount(GameState.gems)

# --- навчання: куди йти ---

func _build_guide() -> void:
	_guide_marker = Label3D.new()
	_guide_marker.text = "▼"
	_guide_marker.font_size = 200
	_guide_marker.pixel_size = 0.006
	_guide_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_guide_marker.no_depth_test = true
	_guide_marker.modulate = Color(0.55, 1.0, 0.6)
	_guide_marker.outline_size = 30
	_guide_marker.outline_modulate = Color(0, 0.2, 0.05, 0.9)
	_guide_marker.visible = false
	add_child(_guide_marker)
	# Вказівник під ногами героя — у бік мети.
	_guide_arrow = MeshInstance3D.new()
	var arrow := PlaneMesh.new()
	arrow.size = Vector2(1.6, 1.6)
	_guide_arrow.mesh = arrow
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _arrow_texture()
	material.albedo_color = Color(0.55, 1.0, 0.6, 0.85)
	_guide_arrow.material_override = material
	_guide_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_guide_arrow.visible = false
	add_child(_guide_arrow)

## Стрілка-шеврон (малюється один раз).
static func _arrow_texture() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			# Шеврон, що дивиться вгору (до -Z): дві смуги під кутом.
			var u := (x - 32.0) / 32.0
			var v := (y - 32.0) / 32.0
			var d := absf(v + absf(u) * 0.9 - 0.1)
			var a := clampf(1.0 - (d - 0.18) / 0.08, 0.0, 1.0) * float(absf(u) < 0.85)
			image.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(image)

## Мета навчання: перший незавершений квест — до кого чи до чого йти.
func _guide_goal() -> Array:
	for quest: Dictionary in QuestBook.active_quests():
		if QuestBook.state_of(quest.id) == "ready":
			return _npc_goal(quest.giver, "Завдання виконано — повернись %s" % HavenNpc.ROLES[quest.giver].to)
		for i in quest.objectives.size():
			var objective: Dictionary = quest.objectives[i]
			if QuestBook.objective_progress(quest.id, i) >= int(objective.count):
				continue
			match String(objective.kind):
				"talk":
					return _npc_goal(objective.target, String(objective.label))
				"wood", "stone", "herb":
					var node := _nearest_gatherable(String(objective.kind))
					if node != null:
						return [node.global_position + Vector3.UP * (5.5 if objective.kind == "wood" else 1.8), String(objective.label)]
				"clear", "kill", "potion":
					return [_portal.global_position + Vector3.UP * 5.5, String(objective.label)]
				"chest":
					var cache := _nearest_cache()
					if cache != null:
						return [cache.global_position + Vector3.UP * 2.2, String(objective.label)]
	for quest: Dictionary in QuestBook.all_quests():
		if QuestBook.is_available(quest):
			return _npc_goal(quest.giver, "Поговори %s — у нього є завдання" % HavenNpc.ROLES[quest.giver].with)
	return []

func _npc_goal(id: StringName, text: String) -> Array:
	var npc: HavenNpc = _npcs.get(id)
	if npc == null:
		return []
	return [npc.global_position + Vector3.UP * 3.4, text]

func _nearest_gatherable(kind: String) -> Gatherable:
	var best: Gatherable = null
	var best_d := INF
	for node in _gatherables:
		if node.kind != kind or node.get("_gone"):
			continue
		var d := node.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

func _nearest_cache() -> HavenSpot:
	var best: HavenSpot = null
	var best_d := INF
	for spot in _spots:
		if spot.kind != "cache" or not spot.enabled:
			continue
		var d := spot.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = spot
	return best

func _update_guide() -> void:
	var goal := _guide_goal_cache
	if goal.is_empty() or _dialog.visible:
		_guide_marker.visible = false
		_guide_arrow.visible = false
		_hint_panel.visible = not goal.is_empty() and not _dialog.visible
		return
	var target: Vector3 = goal[0]
	_hint.text = String(goal[1])
	_hint_panel.visible = true
	_guide_marker.visible = true
	var t := Time.get_ticks_msec() / 1000.0
	_guide_marker.global_position = target + Vector3.UP * (0.25 * sin(t * 3.0))
	var flat := target - player.global_position
	flat.y = 0.0
	_guide_arrow.visible = flat.length() > 5.0
	if _guide_arrow.visible:
		var dir := flat.normalized()
		_guide_arrow.global_position = player.global_position + dir * 1.6 + Vector3.UP * 0.08
		_guide_arrow.global_rotation = Vector3(0, atan2(dir.x, dir.z), 0)

# --- данж і меню ---

func _open_dungeon_select() -> void:
	if _select != null and is_instance_valid(_select):
		return
	_select = DUNGEON_SELECT_SCRIPT.new()
	hud.add_child(_select)
	_select.level_chosen.connect(_on_level_chosen)

func _on_level_chosen(index: int) -> void:
	GameState.select_dungeon_level(index)
	SceneLoader.change_scene(DUNGEON_PATH, DungeonLevels.get_level(index).title)

func _on_joystick_moved(direction: Vector2) -> void:
	player.set_move_input(Vector2(direction.x, -direction.y))

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _unhandled_input(event: InputEvent) -> void:
	if _select != null and is_instance_valid(_select):
		return
	if event.is_action_pressed("ui_accept") and _action_button.visible:
		_on_action_pressed()
	elif event.is_action_pressed("ui_cancel"):
		if _dialog.visible:
			_dialog.visible = false
			_refresh_action()
		else:
			_on_menu_pressed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_menu_pressed()
