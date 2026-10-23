extends Node3D
class_name BossGate

## ВОРОТА МЕГА-БОСА: герой проходить коридором у велику залу — і щойно
## заходить углиб, усі виходи перекриває та сама ґратка, що й у засідках
## (ArenaAmbush), лише без хвиль: тут не орда вилазить із порталів, а
## один-єдиний бій, який починається видовищно (Dungeon._play_boss_intro).
## Ворота відкриває сам данж, коли бос впаде (open()).

signal sealed

const BARS_SCENE := ArenaAmbush.BARS_SCENE
const BARRIER_COLOR := ArenaAmbush.BARRIER_GLOW
const BARRIER_HEIGHT := 2.4
const BARRIER_HIDDEN_Y := -2.5
const BARRIER_MOVE_TIME := 0.35

enum State {WAITING, SEALED, OPENED}

var _player: Node3D
var _map_rows: Array
var _rect: Rect2i
var _state := State.WAITING
var _edges: Array[Dictionary] = []
var _barrier: Node3D
var _barrier_body: StaticBody3D

func setup(player: Node3D, map_rows: Array, rect: Rect2i) -> void:
	_player = player
	_map_rows = map_rows
	_rect = rect
	_find_edges()
	_build_barrier()

func contains(position: Vector3) -> bool:
	return _rect.has_point(DungeonBuilder.cell_of(position))

func _find_edges() -> void:
	var half := DungeonBuilder.CELL * 0.5
	for z in range(_rect.position.y, _rect.end.y):
		for x in range(_rect.position.x, _rect.end.x):
			if not DungeonBuilder.is_walkable(_map_rows, x, z):
				continue
			for step: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var outside := Vector2i(x, z) + step
				if _rect.has_point(outside) or not DungeonBuilder.is_walkable(_map_rows, outside.x, outside.y):
					continue
				var center := DungeonBuilder.cell_center(Vector2i(x, z)) + Vector3(step.x, 0.0, step.y) * half
				_edges.append({"center": center, "along_x": step.y != 0})

func _build_barrier() -> void:
	_barrier = Node3D.new()
	_barrier.position.y = BARRIER_HIDDEN_Y
	_barrier.visible = false
	add_child(_barrier)
	var batcher := MeshBatcher.new()
	var glow := MultiMesh.new()
	glow.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(DungeonBuilder.CELL, BARRIER_HEIGHT)
	glow.mesh = quad
	glow.instance_count = _edges.size()
	var bars_scale := Vector3(DungeonBuilder.CELL / 2.48, BARRIER_HEIGHT / 3.39, 1.0)
	for i in _edges.size():
		var edge: Dictionary = _edges[i]
		var turn := 0.0 if edge.along_x else PI * 0.5
		var basis := Basis(Vector3.UP, turn)
		batcher.add(BARS_SCENE, Transform3D(basis.scaled(bars_scale), edge.center))
		glow.set_instance_transform(i, Transform3D(basis, edge.center + Vector3(0, BARRIER_HEIGHT * 0.5, 0)))
	batcher.flush(_barrier)
	var glow_instance := MultiMeshInstance3D.new()
	glow_instance.multimesh = glow
	var material := CombatVfx.get_glow_material(BARRIER_COLOR).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_instance.material_override = material
	glow_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_barrier.add_child(glow_instance)

func _physics_process(_delta: float) -> void:
	if _state == State.WAITING and _player != null \
			and _rect.grow(-1).has_point(DungeonBuilder.cell_of(_player.global_position)):
		_seal()

func _seal() -> void:
	_state = State.SEALED
	_barrier.visible = true
	var tween := _barrier.create_tween()
	tween.tween_property(_barrier, "position:y", 0.0, BARRIER_MOVE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_barrier_body = StaticBody3D.new()
	_barrier_body.collision_layer = 1
	_barrier_body.collision_mask = 0
	for edge: Dictionary in _edges:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(DungeonBuilder.CELL, BARRIER_HEIGHT, 0.4) if edge.along_x else Vector3(0.4, BARRIER_HEIGHT, DungeonBuilder.CELL)
		shape.shape = box
		shape.position = edge.center + Vector3(0, BARRIER_HEIGHT * 0.5, 0)
		_barrier_body.add_child(shape)
	add_child(_barrier_body)
	AudioManager.play(&"explosion", 0.05)
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.15)
	sealed.emit()

## Бос упав — ворота більше нема сенсу тримати.
func open() -> void:
	_state = State.OPENED
	if _barrier_body != null:
		_barrier_body.queue_free()
		_barrier_body = null
	var tween := _barrier.create_tween()
	tween.tween_property(_barrier, "position:y", BARRIER_HIDDEN_Y, BARRIER_MOVE_TIME * 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _barrier.visible = false)
