extends Area3D
class_name Interactable

## Будівля, з якою можна взаємодіяти: казарма відкриває героїв, кузня —
## зброю, храм — таланти, портал веде в данж.
##
## Працює за близькістю, а не за кліком по моделі: на телефоні влучити
## пальцем у будинок під кутом камери незручно, а підійти — природно.
## Коли герой поруч, унизу екрана з'являється велика кнопка дії.
##
## Напис над будівлею показує, що це таке, ще здалеку.

signal player_entered(interactable: Interactable)
signal player_exited(interactable: Interactable)

## Що робить ця будівля. Екран гри відкриває base_island.gd — сама
## будівля про сцени нічого не знає.
@export_enum("heroes", "weapons", "talents", "shop", "portal") var action: String = "heroes"

## Підпис над будівлею й на кнопці дії.
@export var title: String = "Будівля"
## Висота напису. Камера дивиться згори вниз, тому все, що піднято
## вище за неї, вилітає за верхній край екрана — тримаємо підписи на
## рівні голови героя, а не над дахом.
@export var label_height := 2.4
@export var label_color: Color = Color(1, 0.92, 0.6)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_add_label()

## Напис завжди повернутий до камери (billboard), тож читається з
## будь-якого боку.
func _add_label() -> void:
	var label := Label3D.new()
	label.text = title
	# Розмір підібраний так, щоб напис читався з відстані, з якої
	# гравець бачить будівлю цілком (приблизно 2 метри заввишки).
	label.font_size = 128
	label.pixel_size = 0.0055
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = label_color
	label.outline_size = 28
	label.outline_modulate = Color(0, 0, 0, 0.75)
	label.position = Vector3(0, label_height, 0)
	# Напис видно лише поблизу: у великому місті підписи всіх будівель
	# одночасно захаращували б екран і просвічували крізь стіни.
	label.visibility_range_end = 20.0
	label.visibility_range_end_margin = 4.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(label)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_entered.emit(self)

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_exited.emit(self)
