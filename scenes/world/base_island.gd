extends Node3D

## Стартовий острів — база героя. Тут гравець ходить між будівлями:
## казарма відкриває вибір героя, кузня — зброю, храм — таланти,
## ринок — магазин, а портал веде в данж.
##
## Взаємодія за близькістю: підійшов — унизу з'явилась велика кнопка.
## На телефоні це зручніше, ніж цілитись пальцем у будинок під кутом
## камери, і водночас працює мишею на ПК.
##
## Розставляти світ можна просто в редакторі: перетягніть будь-яку
## модель з assets/models/environment у вузол Buildings або Nature —
## код про них нічого не знає, фізику для них він побудує сам.

const JOYSTICK_SCENE := preload("res://scenes/ui/virtual_joystick.tscn")
const CAMERA_TOUCH_SCENE := preload("res://scenes/ui/camera_touch.tscn")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"

## Куди веде кожна будівля.
const ACTION_SCENES := {
	"heroes": "res://scenes/ui/heroes.tscn",
	"weapons": "res://scenes/ui/weapons.tscn",
	"talents": "res://scenes/ui/meta_upgrades.tscn",
	"shop": "res://scenes/ui/shop.tscn",
	"portal": "res://scenes/dungeon/dungeon.tscn",
}

@onready var player: CharacterBody3D = $Player
@onready var action_button: Button = $HUD/ActionButton
@onready var gold_label: Label = $HUD/GoldLabel

var _nearby: Interactable

func _ready() -> void:
	SceneLoader.hold()
	player.set_torch_enabled(false)

	var joystick: Control = JOYSTICK_SCENE.instantiate()
	$HUD.add_child(joystick)
	joystick.direction_changed.connect(_on_joystick_moved)

	# Права половина екрана крутить камеру, короткий дотик по ній — удар.
	var camera_touch: Control = CAMERA_TOUCH_SCENE.instantiate()
	$HUD.add_child(camera_touch)
	camera_touch.rotate_requested.connect($CameraRig.rotate_by)
	camera_touch.pitch_requested.connect($CameraRig.pitch_by)
	camera_touch.tap_attack.connect(player.attack)
	# Кнопка дії має бути ПОВЕРХ джойстика, інакше дотик по ній
	# сприймався б як спроба рухатись.
	$HUD.move_child(action_button, $HUD.get_child_count() - 1)

	$HUD/MenuButton.pressed.connect(_on_menu_pressed)
	action_button.pressed.connect(_on_action_pressed)
	action_button.visible = false

	for node in $Buildings.find_children("*", "Interactable", true, false):
		var interactable := node as Interactable
		interactable.player_entered.connect(_on_player_entered)
		interactable.player_exited.connect(_on_player_exited)

	gold_label.text = "Золото: %d    Геми: %d" % [GameState.gold, GameState.gems]

	# Моделі з наборів приходять без фізики, тож стінки будуємо самі по
	# формі мешів. Так будь-яка модель, яку ви перетягнете в редакторі,
	# одразу стає твердою — без ручного налаштування.
	await _build_collisions([$Buildings, $Nature])
	SceneLoader.release()

## Створює фізичні стінки для всіх мешів усередині вузлів. Будуємо по
## кілька за кадр, поки на екрані завантаження: на слабкому телефоні
## фізика великих будівель за один кадр давала помітний ривок.
func _build_collisions(roots: Array) -> void:
	var built := 0
	for root: Node in roots:
		for child in root.find_children("*", "MeshInstance3D", true, false):
			(child as MeshInstance3D).create_trimesh_collision()
			built += 1
			if built % 4 == 0:
				await get_tree().process_frame

## Джойстик дає напрямок в екранних координатах (вниз — це +Y), а рух
## уперед — це -Z у 3D, тож вісь Y перевертаємо.
func _on_joystick_moved(direction: Vector2) -> void:
	player.set_move_input(Vector2(direction.x, -direction.y))

func _on_player_entered(interactable: Interactable) -> void:
	_nearby = interactable
	action_button.text = interactable.title
	action_button.visible = true

## Виходимо з зони — кнопка зникає. Перевірка на "ту саму будівлю"
## потрібна, бо зони можуть перекриватись: вийшовши з однієї, гравець
## може вже стояти в іншій.
func _on_player_exited(interactable: Interactable) -> void:
	if _nearby == interactable:
		_nearby = null
		action_button.visible = false

func _on_action_pressed() -> void:
	if _nearby == null:
		return
	var path: String = ACTION_SCENES.get(_nearby.action, "")
	if path == "":
		return
	# У данж — через екран завантаження: це найважча сцена гри, і на
	# слабкому телефоні пряме завантаження "заморожувало" екран.
	if _nearby.action == "portal":
		SceneLoader.change_scene(path, "Забуті склепи")
	else:
		get_tree().change_scene_to_file(path)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		# Пробіл: якщо стоїмо біля будівлі — заходимо, інакше б'ємо мечем.
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
