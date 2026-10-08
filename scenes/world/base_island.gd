extends Node3D

## Місто — база героя. Гравець ходить між будівлями: Зала героїв
## відкриває вибір героя, Збройня — зброю, Храм — таланти, Ринок —
## магазин, а арка в скелі на півночі веде в данж.
##
## Взаємодія за близькістю: підійшов — унизу з'явилась велика кнопка.
## На телефоні це зручніше, ніж цілитись пальцем у будинок під кутом
## камери, і водночас працює мишею на ПК.
##
## РЕДАГУВАННЯ. Усе місто — звичайні вузли, їх можна рухати в редакторі:
##   Buildings — будівлі з дією (разом із зонами дії);
##   Town/Houses, Town/Walls, Town/Plaza, Town/DungeonGate — те, у що
##     не можна зайти: фізика для них будується сама;
##   Town/Props — дрібний реквізит (теж твердий);
##   Nature — дерева, скелі, гори, ліс на пагорбах;
##   Effects — вогні жаровень (маркери Fire*) і прохід у данж.
## Доріжки й бруківка намальовані в assets/textures/town/town_paths.png.
##
## ОПТИМІЗАЦІЯ. Під час гри однакові моделі збираються в пакети
## (TownBatcher) — у редакторі цього не видно, а телефону легше в рази.

const JOYSTICK_SCENE := preload("res://scenes/ui/virtual_joystick.tscn")
const CAMERA_TOUCH_SCENE := preload("res://scenes/ui/camera_touch.tscn")
const DUNGEON_SELECT_SCRIPT := preload("res://scenes/ui/dungeon_select.gd")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
const DUNGEON_PATH := "res://scenes/dungeon/dungeon.tscn"
## Кнопка "Меню" (арт гравця) і її ширина: риски зліва + напис.
const MENU_BUTTON_ART := "res://assets/ui/theme/button_menu.png"
const MENU_BUTTON_WIDTH := 140.0

## Куди веде кожна будівля. Портал відкриває вибір рівня данжу.
const ACTION_SCENES := {
	"heroes": "res://scenes/ui/heroes.tscn",
	"weapons": "res://scenes/ui/weapons.tscn",
	"talents": "res://scenes/ui/meta_upgrades.tscn",
	"shop": "res://scenes/ui/shop.tscn",
}

## Групи міста, які стають твердими, і наскільки зменшити їхню коробку
## (дахи й ґанки виступають — повна коробка не пускала б до дверей).
const SOLID_GROUPS := {
	"Buildings": 0.72,
	"Town/Houses": 0.78,
	"Town/Walls": 0.95,
	"Town/Plaza": 0.7,
	"Town/DungeonGate": 0.85,
	"Town/Props": 0.8,
	"Nature/Trees": 0.3,
}

## Групи, які пакуються для телефона, і розмір ділянки пакування: місто
## видно майже все одразу — одна ділянка; ліс і гори — дрібніші, щоб
## те, що позаду камери, не малювалось.
const BATCH_GROUPS := {"Town": 0.0, "Buildings": 0.0, "Nature": 40.0}

@onready var player: CharacterBody3D = $Player
@onready var action_button: Button = $HUD/ActionButton
@onready var gold_label: Label = $HUD/GoldLabel
var _gold_badge: CurrencyBadge
var _gems_badge: CurrencyBadge

var _nearby: Interactable
var _select: Control

func _ready() -> void:
	SceneLoader.hold()
	player.set_torch_enabled(false)
	# Повернулись з екрана будівлі — стоїмо там, де стояли біля її дверей
	# (а не на вході в місто). Саме там, де стояв герой: центр зони
	# будівлі може бути впритул до стіни.
	if GameState.town_return_spot != Vector3.INF:
		player.global_position = GameState.town_return_spot + Vector3.UP * 0.05
		GameState.town_return_spot = Vector3.INF
		$CameraRig.snap_to_target()
	# У місті пробіл — "зайти в будівлю", бій з клавіатури тут вимкнено.
	player.combat_input_enabled = false

	var joystick: Control = JOYSTICK_SCENE.instantiate()
	$HUD.add_child(joystick)
	joystick.direction_changed.connect(_on_joystick_moved)

	# Права половина екрана крутить камеру, короткий дотик по ній — удар.
	var camera_touch: Control = CAMERA_TOUCH_SCENE.instantiate()
	$HUD.add_child(camera_touch)
	camera_touch.rotate_requested.connect($CameraRig.rotate_by)
	camera_touch.pitch_requested.connect($CameraRig.pitch_by)
	camera_touch.attack_held_changed.connect(player.set_attack_held)
	# Кнопка дії має бути ПОВЕРХ джойстика, інакше дотик по ній
	# сприймався б як спроба рухатись.
	$HUD.move_child(action_button, $HUD.get_child_count() - 1)

	$HUD/MenuButton.pressed.connect(_on_menu_pressed)
	action_button.pressed.connect(_on_action_pressed)
	action_button.visible = false
	_style_hud()

	for node in $Buildings.find_children("*", "Interactable", true, false):
		var interactable := node as Interactable
		interactable.player_entered.connect(_on_player_entered)
		interactable.player_exited.connect(_on_player_exited)

	_gold_badge.set_amount(GameState.gold)
	_gems_badge.set_amount(GameState.gems)

	# Важке — під екраном завантаження: фізика будівель, пакування,
	# вогні. Гравець бачить смужку, а не ривки першої секунди.
	await get_tree().process_frame
	_build_colliders()
	await get_tree().process_frame
	for group: String in BATCH_GROUPS:
		if has_node(group):
			TownBatcher.batch(get_node(group) as Node3D, BATCH_GROUPS[group])
	_light_fires()
	SceneLoader.release()

## Оформлення (UiTheme): золото й підказка — на напівпрозорій панелі в
## рамці, "Меню" — з іконкою набору, кнопка входу в будівлю — світла,
## головна дія екрана.
func _style_hud() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.hud_box())
	panel.position = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	$HUD.add_child(panel)
	$HUD.move_child(panel, 0)
	# Золото й геми — значками з монетою й гемом, а не рядком тексту.
	gold_label.visible = false
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 16)
	wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(wallet)
	_gold_badge = CurrencyBadge.new(&"gold", 18, false)
	wallet.add_child(_gold_badge)
	_gems_badge = CurrencyBadge.new(&"gem", 18, false)
	wallet.add_child(_gems_badge)
	# Підказку "Джойстик — рух..." гравець бачить щоразу — вона лише
	# захаращує кут з валютою. Будівлі й так підписані над дахом.
	($HUD/HintLabel as Label).visible = false

	# "Меню" — синя плашка з рисками зліва (арт гравця); риски — частина
	# картинки, тож окрема іконка не потрібна. Ширша за сцену, щоб напис
	# не заходив на риски.
	var menu := $HUD/MenuButton as Button
	menu.icon = null
	menu.offset_left = -16.0 - MENU_BUTTON_WIDTH
	UiTheme.art_button(menu, MENU_BUTTON_ART, 54, 23, "", 14)
	# Вхід у будівлю — зелена кнопка з рунами, як "Обрати" в Залі героїв.
	UiTheme.art_primary(action_button)

## Прості коробки замість точної форми кожної моделі: для телефона це
## в рази дешевше, а гравцеві різниці не видно.
func _build_colliders() -> void:
	var body := StaticBody3D.new()
	body.name = "TownColliders"
	add_child(body)
	for group: String in SOLID_GROUPS:
		if has_node(group):
			TownBatcher.add_box_colliders(get_node(group) as Node3D, body, SOLID_GROUPS[group])

## Вогонь на жаровнях: кілька частинок і світна "серцевина" без
## справжнього джерела світла — телефону його не треба рахувати.
func _light_fires() -> void:
	if not has_node("Effects"):
		return
	for marker in $Effects.get_children():
		if not String(marker.name).begins_with("Fire"):
			continue
		(marker as Node3D).add_child(_make_flame())

static func _make_flame() -> Node3D:
	var flame := CPUParticles3D.new()
	flame.amount = 14
	flame.lifetime = 0.7
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.22
	flame.direction = Vector3.UP
	flame.spread = 12.0
	flame.gravity = Vector3(0, 1.6, 0)
	flame.initial_velocity_min = 0.6
	flame.initial_velocity_max = 1.3
	flame.scale_amount_min = 0.7
	flame.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	flame.scale_amount_curve = curve
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.35))
	gradient.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	flame.color_ramp = gradient
	var quad := QuadMesh.new()
	quad.size = Vector2(0.32, 0.32)
	flame.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	flame.material_override = material
	return flame

## Джойстик дає напрямок в екранних координатах (вниз — це +Y), а рух
## уперед — це -Z у 3D, тож вісь Y перевертаємо.
func _on_joystick_moved(direction: Vector2) -> void:
	player.set_move_input(Vector2(direction.x, -direction.y))

func _on_player_entered(interactable: Interactable) -> void:
	_nearby = interactable
	action_button.text = interactable.title
	action_button.visible = true

## Виходимо з зони — кнопка зникає. Перевірка на "ту саму будівлю"
## потрібна, бо зони можуть перекриватись.
func _on_player_exited(interactable: Interactable) -> void:
	if _nearby == interactable:
		_nearby = null
		action_button.visible = false

func _on_action_pressed() -> void:
	if _nearby == null:
		return
	if _nearby.action == "portal":
		_open_dungeon_select()
		return
	var path: String = ACTION_SCENES.get(_nearby.action, "")
	if path != "":
		# "Назад" на екрані будівлі поверне героя сюди ж, до її дверей.
		GameState.open_from_town(path, player.global_position)

## Вибір рівня данжу: наступний відкривається, лише коли пройдено
## попередній.
func _open_dungeon_select() -> void:
	if _select != null and is_instance_valid(_select):
		return
	_select = DUNGEON_SELECT_SCRIPT.new()
	$HUD.add_child(_select)
	_select.level_chosen.connect(_on_level_chosen)

func _on_level_chosen(index: int) -> void:
	GameState.select_dungeon_level(index)
	SceneLoader.change_scene(DUNGEON_PATH, DungeonLevels.get_level(index).title)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _unhandled_input(event: InputEvent) -> void:
	if _select != null and is_instance_valid(_select):
		return
	if event.is_action_pressed("ui_accept"):
		# Пробіл: якщо стоїмо біля будівлі — заходимо, інакше б'ємо.
		if _nearby != null:
			_on_action_pressed()
		else:
			player.attack()
	elif event.is_action_pressed("ui_cancel"):
		_on_menu_pressed()

## Кнопка "назад" на Android повертає в меню.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_menu_pressed()
