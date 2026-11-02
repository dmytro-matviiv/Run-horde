extends Node3D
class_name RewardChest

## СКРИНЯ ЗА ЗАСІДКУ. З'являється посеред зали, коли остання хвиля
## впала: золота скриня в світному колі. Підійшов — вона підскакує й
## розсипає здобич (сигнал opened: золото, досвід і ще одну здібність
## на вибір дає данж).

signal opened(position: Vector3)

const CHEST_SCENE := preload("res://assets/models/dungeon/Chest_Gold.fbx")
const GLOW_COLOR := Color(1.0, 0.8, 0.3, 0.85)
const TOUCH_DISTANCE := 1.8

var _player: Node3D
var _opened := false
var _chest: Node3D
var _ring: MeshInstance3D

func setup(player: Node3D) -> void:
	_player = player

func _ready() -> void:
	_chest = CHEST_SCENE.instantiate()
	add_child(_chest)
	_ring = CombatVfx.make_ground_marker(GLOW_COLOR, 1.4)
	CombatVfx.set_param(_ring, &"progress", 1.0)
	_ring.position.y = 0.04
	add_child(_ring)
	# Скриня "падає" з неба в промені світла — видно, куди йти.
	CombatVfx.sky_beam(get_parent(), global_position, GLOW_COLOR)
	_chest.scale = Vector3.ONE * 0.01
	var tween := _chest.create_tween()
	tween.tween_property(_chest, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(_delta: float) -> void:
	if _opened or _player == null:
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() <= TOUCH_DISTANCE:
		_open()

func _open() -> void:
	_opened = true
	var tween := _chest.create_tween()
	tween.tween_property(_chest, "position:y", 0.5, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(_chest, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
	var fade := _ring.create_tween()
	fade.tween_property(_ring, "transparency", 1.0, 0.6)
	CombatVfx.impact(get_parent(), global_position + Vector3.UP * 0.7, GLOW_COLOR, true)
	CombatVfx.shockwave(get_parent(), global_position, 2.4, GLOW_COLOR, 0.45)
	opened.emit(global_position)
