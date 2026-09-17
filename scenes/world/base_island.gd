extends Node3D

## Стартовий острів — база героя. Поки що це "пісочниця": зелений
## ландшафт, кілька будівель і дерев із набору RTS, герой і камера.
##
## Далі сюди додаються клікабельні будівлі (вибір героя, зброя, таланти)
## і портал у данж. Розставляти об'єкти можна просто в редакторі Godot:
## перетягніть будь-яку модель з assets/models/environment у вузол
## Buildings або Nature — код про них нічого не знає й нічого не зламає.
##
## Джойстик той самий, що й у 2D-частині гри: на телефоні керування
## пальцем, на ПК — стрілки.

const JOYSTICK_SCENE := preload("res://scenes/ui/virtual_joystick.tscn")

@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	# Моделі з наборів приходять без фізики, тож стінки будуємо самі: по
	# формі кожного меша. Інакше герой проходив би крізь будинки й гори.
	# Робимо це кодом, щоб будь-яка модель, яку ви перетягнете в редакторі,
	# одразу стала твердою — без ручного налаштування.
	_build_collisions($Buildings)
	_build_collisions($Nature)

	var joystick: Control = JOYSTICK_SCENE.instantiate()
	$HUD.add_child(joystick)
	joystick.direction_changed.connect(_on_joystick_moved)

## Джойстик дає напрямок в екранних координатах (вниз — це +Y), а рух
## уперед — це -Z у 3D, тож вісь Y перевертаємо.
## Створює фізичні стінки для всіх мешів усередині вузла.
func _build_collisions(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).create_trimesh_collision()

func _on_joystick_moved(direction: Vector2) -> void:
	player.set_move_input(Vector2(direction.x, -direction.y))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		player.attack()
