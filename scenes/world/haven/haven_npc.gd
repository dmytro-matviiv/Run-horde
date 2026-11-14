extends Node3D
class_name HavenNpc

## Житель Прихистку: модель (зібрана npc_builder), ім'я над головою,
## позначка квесту ("!" — є завдання, "?" — можна здати), зона розмови.
## Коли герой поруч — обертається до нього й киває; відійшов — повертається
## до своєї справи (своя анімація: кує, тримає ліхтар, спирається на ятку).

signal player_near(npc: HavenNpc)
signal player_left(npc: HavenNpc)

## Ролі: ім'я, що робить, напис дії, перші слова (вони ж — пояснення для
## новачка, що тут можна зробити).
const ROLES := {
	&"elder": {"name": "Старійшина Остап", "with": "зі Старійшиною Остапом", "to": "до Старійшини Остапа",
		"action": "", "button": "",
		"line": "Прихисток завжди радий мандрівникам. Тут ти відпочинеш, підготуєшся — і знову рушиш у підземелля."},
	&"mentor": {"name": "Наставниця Дарина", "with": "з Наставницею Дариною", "to": "до Наставниці Дарини",
		"action": "heroes", "button": "Обрати героя",
		"line": "У мене збираються герої Прихистку. Обери, ким вирушиш у похід, — у кожного свій бій і свої вміння."},
	&"smith": {"name": "Коваль Богдан", "with": "з Ковалем Богданом", "to": "до Коваля Богдана",
		"action": "weapons", "button": "Зброя",
		"line": "Добра зброя — половина перемоги. Купуй нову й обирай, з чим іти в бій."},
	&"sage": {"name": "Мудрець Велимир", "with": "з Мудрецем Велимиром", "to": "до Мудреця Велимира",
		"action": "talents", "button": "Таланти",
		"line": "Золото, здобуте в підземеллях, я перетворюю на силу. Тут прокачуються таланти твого героя."},
	&"merchant": {"name": "Торговка Олеся", "with": "з Торговкою Олесею", "to": "до Торговки Олесі",
		"action": "shop", "button": "Крамниця",
		"line": "Геми, скрині, набори — у мене є все, що допоможе в дорозі. Заходь частіше!"},
}

const TALK_RADIUS := 3.4
const TURN_SPEED := 5.0

var id: StringName
var info: Dictionary
var _model: Node3D
var _player_anim: AnimationPlayer
var _idle_anim := ""
var _home_yaw := 0.0
var _mark: Label3D
var _player: Node3D
var _near := false
## Чи жителя видно на екрані: поза кадром анімація стоїть (телефону не
## треба рахувати кістки тих, кого гравець не бачить).
var _on_screen: VisibleOnScreenNotifier3D

static func create(npc_id: StringName, scene: PackedScene) -> HavenNpc:
	var npc := HavenNpc.new()
	npc.id = npc_id
	npc.info = ROLES.get(npc_id, {"name": String(npc_id), "action": "", "button": "", "line": ""})
	npc._model = scene.instantiate()
	npc.add_child(npc._model)
	return npc

func _ready() -> void:
	name = "Npc_%s" % id
	_home_yaw = rotation.y
	_player_anim = _model.find_children("*", "AnimationPlayer", true, false)[0]
	_idle_anim = String(_model.get_meta(&"idle_anim", ""))
	if _idle_anim != "":
		_player_anim.play(_idle_anim)
		# Щоб сусіди не рухались в унісон.
		_player_anim.seek(randf() * 2.0, true)
	_player_anim.animation_finished.connect(_on_animation_finished)
	var label := Label3D.new()
	label.text = info.name
	label.font_size = 96
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1, 0.93, 0.7)
	label.outline_size = 22
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.position = Vector3(0, 2.25, 0)
	label.visibility_range_end = 18.0
	add_child(label)
	_mark = Label3D.new()
	_mark.font_size = 220
	_mark.pixel_size = 0.006
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.no_depth_test = true
	_mark.modulate = Color(1, 0.84, 0.2)
	_mark.outline_size = 36
	_mark.outline_modulate = Color(0.25, 0.12, 0, 0.9)
	_mark.position = Vector3(0, 2.85, 0)
	add_child(_mark)
	var bob := _mark.create_tween().set_loops()
	bob.tween_property(_mark, "position:y", 3.0, 0.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_mark, "position:y", 2.85, 0.6).set_trans(Tween.TRANS_SINE)
	refresh_mark()
	_on_screen = VisibleOnScreenNotifier3D.new()
	_on_screen.aabb = AABB(Vector3(-0.9, 0.0, -0.9), Vector3(1.8, 2.3, 1.8))
	add_child(_on_screen)

func set_player(player: Node3D) -> void:
	_player = player

## "!" — у цього NPC є нове завдання, "?" — є що здати.
func refresh_mark() -> void:
	if not QuestBook.ready_for(id).is_empty():
		_mark.text = "?"
		_mark.visible = true
	elif not QuestBook.available_for(id).is_empty():
		_mark.text = "!"
		_mark.visible = true
	else:
		_mark.visible = false

func _process(delta: float) -> void:
	var visible_now := _on_screen.is_on_screen()
	if _player_anim.active != visible_now:
		_player_anim.active = visible_now
	if _player == null:
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	var near := offset.length() < TALK_RADIUS
	if near != _near:
		_near = near
		if near:
			player_near.emit(self)
			_greet()
		else:
			player_left.emit(self)
	# Поруч — дивиться на героя; ні — на своє місце.
	var target := atan2(offset.x, offset.z) if near else _home_yaw
	rotation.y = lerp_angle(rotation.y, target, minf(delta * TURN_SPEED, 1.0))

## Кивнути при зустрічі й повернутись до своєї справи.
func _greet() -> void:
	if _player_anim.has_animation("Yes"):
		_player_anim.play("Yes", 0.2)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Yes" and _idle_anim != "":
		_player_anim.play(_idle_anim, 0.3)
