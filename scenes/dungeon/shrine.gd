extends Node3D
class_name Shrine

## СВЯТИЛИЩЕ. П'єдестал зі світною руною посеред зали. Підійшов — сила
## святилища твоя на півхвилини (або одразу зцілення), а руна гасне:
## святилище одноразове. Лють найкорисніша, коли попереду бій, — тож
## святилище штовхає гравця йти вперед, а не відсиджуватись.

signal activated(kind: StringName)

const PEDESTAL_SCENE := preload("res://assets/models/dungeon/Pedestal2.fbx")
## П'єдестал з набору на зріст людини — зменшуємо до пояса.
const PEDESTAL_SCALE := 0.5
const RUNE_HEIGHT := 1.65
const TOUCH_DISTANCE := 1.7
const BUFF_SECONDS := 30.0
## Скільки здоров'я повертає джерело життя — частка від найбільшого.
const LIFE_HEAL := 0.5

const KINDS := {
	&"fury": {"title": "Святилище люті", "text": "+50% шкоди на 30 с", "color": Color(1.0, 0.38, 0.28)},
	&"haste": {"title": "Святилище вітру", "text": "швидше б'єш і бігаєш 30 с", "color": Color(0.45, 0.95, 1.0)},
	&"guard": {"title": "Святилище каменю", "text": "на 40% менше шкоди 30 с", "color": Color(1.0, 0.82, 0.38)},
	&"life": {"title": "Джерело життя", "text": "зцілює половину здоров'я", "color": Color(0.45, 1.0, 0.5)},
}

var kind: StringName = &"fury"
var _player: Node3D
var _used := false
var _rune: MeshInstance3D
var _label: Label3D

func setup(player: Node3D, shrine_kind: StringName) -> void:
	_player = player
	kind = shrine_kind

func _ready() -> void:
	var info: Dictionary = KINDS[kind]
	var pedestal: Node3D = PEDESTAL_SCENE.instantiate()
	pedestal.scale = Vector3.ONE * PEDESTAL_SCALE
	add_child(pedestal)

	# Руна — гранчастий самоцвіт кольору святилища, що ширяє й крутиться.
	_rune = MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = 0.28
	gem.height = 0.7
	gem.radial_segments = 4
	gem.rings = 2
	_rune.mesh = gem
	_rune.material_override = CombatVfx.get_glow_material(info.color)
	_rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rune.position.y = RUNE_HEIGHT
	add_child(_rune)
	var spin := _rune.create_tween().set_loops()
	spin.tween_property(_rune, "rotation:y", TAU, 2.4).from(0.0)
	var bob := _rune.create_tween().set_loops()
	bob.tween_property(_rune, "position:y", RUNE_HEIGHT + 0.18, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_rune, "position:y", RUNE_HEIGHT, 0.9).set_trans(Tween.TRANS_SINE)

	# Напис, як над будівлями міста: що це і що дасть.
	_label = Label3D.new()
	_label.text = "%s\n%s" % [info.title, info.text]
	_label.font_size = 80
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = info.color
	_label.outline_size = 20
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	_label.position.y = RUNE_HEIGHT + 0.75
	_label.visibility_range_end = 16.0
	add_child(_label)

func _physics_process(_delta: float) -> void:
	if _used or _player == null:
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() <= TOUCH_DISTANCE:
		_activate()

func _activate() -> void:
	_used = true
	var info: Dictionary = KINDS[kind]
	if kind == &"life":
		_player.heal(_player.max_hp * LIFE_HEAL)
	else:
		_player.add_shrine_buff(kind, BUFF_SECONDS)
	var parent := get_parent()
	CombatVfx.sky_beam(parent, global_position, info.color)
	CombatVfx.shockwave(parent, global_position, 2.6, info.color, 0.5)
	AudioManager.play(&"level_up")
	# Руна згасає, напис лишається блідим — святилище вже порожнє.
	var fade := _rune.create_tween()
	fade.tween_property(_rune, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_label.text = info.title
	_label.modulate = Color(0.6, 0.6, 0.62, 0.7)
	activated.emit(kind)
