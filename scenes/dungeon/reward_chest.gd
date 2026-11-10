extends Node3D
class_name RewardChest

## СКРИНЯ ЗА ЗАСІДКУ. З'являється посеред зали, коли остання хвиля
## впала: ЗАКРИТА золота скриня, що світиться (м'яке сяйво, золоті іскри
## й коло на підлозі) — видно, куди йти. Підійшов — вона відкривається
## (модель відкритої скрині), гасне й розсипає здобич (сигнал opened:
## золото, досвід і ще одну здібність на вибір дає данж).

signal opened(position: Vector3)

const CHEST_SCENE := preload("res://assets/models/dungeon/Chest_Gold.fbx")
const OPEN_SCENE := preload("res://assets/models/treasure/chest.glb")
const GLOW_COLOR := Color(1.0, 0.8, 0.3, 0.85)
const TOUCH_DISTANCE := 1.8

var _player: Node3D
var _opened := false
var _chest: Node3D
var _ring: MeshInstance3D
var _glow: MeshInstance3D
var _motes: CPUParticles3D

func setup(player: Node3D) -> void:
	_player = player

func _ready() -> void:
	_chest = CHEST_SCENE.instantiate()
	add_child(_chest)
	_ring = CombatVfx.make_ground_marker(GLOW_COLOR, 1.4)
	CombatVfx.set_param(_ring, &"progress", 1.0)
	_ring.position.y = 0.04
	add_child(_ring)
	# Сяйво закритої скрині: м'яка золота пляма, що дихає, і іскри, які
	# повільно здіймаються.
	_glow = Fx.make_sprite("light_02", Color(1.0, 0.82, 0.4, 0.55), false, true)
	add_child(_glow)
	_glow.position.y = 0.6
	_glow.scale = Vector3.ONE * 2.2
	var pulse := _glow.create_tween().set_loops()
	pulse.tween_property(_glow, "scale", Vector3.ONE * 2.6, 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_glow, "scale", Vector3.ONE * 2.1, 0.7).set_trans(Tween.TRANS_SINE)
	_motes = CombatVfx.make_motes(GLOW_COLOR, 10, 0.6, 1.2, 0.14)
	add_child(_motes)
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
	_chest.scale = Vector3.ONE
	# Закриту скриню замінює відкрита — того ж розміру й так само повернута.
	var closed_size := _footprint(_chest)
	var open_chest: Node3D = OPEN_SCENE.instantiate()
	add_child(open_chest)
	var open_size := _footprint(open_chest)
	if closed_size > 0.01 and open_size > 0.01:
		open_chest.scale = Vector3.ONE * (closed_size / open_size)
	open_chest.rotation = _chest.rotation
	_chest.queue_free()
	_chest = open_chest
	var tween := _chest.create_tween()
	tween.tween_property(_chest, "position:y", 0.25, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(_chest, "position:y", 0.0, 0.18).set_ease(Tween.EASE_IN)
	# Відкрилась — більше не світиться.
	_motes.emitting = false
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_ring, "transparency", 1.0, 0.5)
	fade.tween_property(_glow, "transparency", 1.0, 0.4)
	fade.chain().tween_callback(func() -> void:
		_ring.queue_free()
		_glow.queue_free())
	CombatVfx.impact(get_parent(), global_position + Vector3.UP * 0.7, GLOW_COLOR, true)
	opened.emit(global_position)

## Найбільший горизонтальний розмір моделі (м) — щоб підігнати відкриту
## скриню під закриту.
func _footprint(root: Node3D) -> float:
	var box := AABB()
	var first := true
	var inverse := global_transform.affine_inverse()
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var local: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return maxf(box.size.x, box.size.z)
