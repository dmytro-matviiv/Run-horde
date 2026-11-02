extends Node3D
class_name ArenaAmbush

## ЗАСІДКА. Зала, яка зачиняється, щойно герой ступить усередину: виходи
## перекриває рунна ґратка, а вороги вилазять із порталів хвилями —
## спершу ті, що жили в цій залі, потім решта разом з ордою дрібноти, а
## у великій залі наостанок ще загін із ватажком. Прорвався — ґратки
## ховаються, посеред зали з'являється скриня (це вже справа данжу:
## сигнал cleared).
##
## Хвилі складає данж (Dungeon._plan_arena_waves) і передає сюди. Скільки
## ворогів живе одночасно, обмежує якість графіки (arena_max_enemies у
## PerfSettings): решта хвилі чекає, поки хтось упаде.

signal started
signal wave_started(index: int, total: int)
signal cleared(center: Vector3)

const BARS_SCENE := preload("res://assets/models/dungeon/Arch_bars.fbx")
const PORTAL_COLOR := Color(0.78, 0.38, 1.0, 0.9)
## Колір рунної пелени в ґратках — той самий червоний, що й у воротах до
## боса (BossGate): ґрати в данжі всі однакові.
const BARRIER_GLOW := Color(0.85, 0.16, 0.2)
const BARRIER_HEIGHT := 2.2
## Ґратки ховаються під підлогою й виринають за мить.
const BARRIER_HIDDEN_Y := -2.5
const BARRIER_MOVE_TIME := 0.3
## Портал світиться стільки, перш ніж із нього вилізе ворог, — гравець
## бачить, звідки чекати.
const PORTAL_TIME := 0.6
const EMERGE_TIME := 0.5
## Між появами ворогів: навантаження на телефон розкладене на кадри.
const SPAWN_GAP := 0.15
const WAVE_PAUSE := 1.4
## Дрібнота й ватажок не з'являються впритул до героя.
const MIN_SPAWN_DISTANCE := 4.5

enum State {WAITING, FIGHTING, CLEARED}

var _player: Node3D
var _map_rows: Array
var _rect: Rect2i
var _spawn: Callable
var _waves: Array = []
var _max_alive := 9
var _state := State.WAITING
var _wave := -1
var _queue: Array = []
var _alive := 0
var _portals := 0
var _spawn_left := 0.0
var _next_wave_left := -1.0
var _edges: Array[Dictionary] = []
var _barrier: Node3D
var _barrier_body: StaticBody3D
var _rng := RandomNumberGenerator.new()

## rect — зала в клітинках карти; waves — [[{position, definition}], ...]
## (position = Vector3.INF — будь-де в залі, подалі від героя);
## spawn(position, definition) -> Enemy3D — створює ворога.
func setup(player: Node3D, map_rows: Array, rect: Rect2i, waves: Array, spawn: Callable, max_alive: int) -> void:
	_player = player
	_map_rows = map_rows
	_rect = rect
	_waves = waves
	_spawn = spawn
	_max_alive = max_alive
	_rng.seed = rect.position.x * 92821 + rect.position.y * 68917
	_find_edges()
	_build_barrier()

func is_active() -> bool:
	return _state == State.FIGHTING

## Чи стоїть точка всередині зали засідки.
func contains(position: Vector3) -> bool:
	return _rect.has_point(DungeonBuilder.cell_of(position))

## Межі зали, через які можна вийти: сторона клітинки всередині, за якою
## прохідна клітинка ззовні. На кожну таку сторону — секція ґратки.
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

## Ґратка — два пакети (залізні прути й світна рунна пелена): скільки б
## не було виходів, це два виклики малювання.
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
	var material := CombatVfx.get_glow_material(BARRIER_GLOW).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_instance.material_override = material
	glow_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_barrier.add_child(glow_instance)

func _physics_process(delta: float) -> void:
	match _state:
		State.WAITING:
			# Починається, коли герой зайшов у залу хоч на клітинку вглиб —
			# ґратка не закриється в нього під ногами.
			if _player != null and _rect.grow(-1).has_point(DungeonBuilder.cell_of(_player.global_position)):
				_begin()
		State.FIGHTING:
			_fight(delta)

func _begin() -> void:
	_state = State.FIGHTING
	_close_barrier()
	started.emit()
	_start_wave(0)

func _start_wave(index: int) -> void:
	_wave = index
	_queue = (_waves[index] as Array).duplicate()
	_spawn_left = 0.3
	_next_wave_left = -1.0
	wave_started.emit(index + 1, _waves.size())

func _fight(delta: float) -> void:
	if _next_wave_left >= 0.0:
		_next_wave_left -= delta
		if _next_wave_left <= 0.0:
			_start_wave(_wave + 1)
		return
	_spawn_left -= delta
	if not _queue.is_empty() and _spawn_left <= 0.0 and _alive + _portals < _max_alive:
		_open_portal(_queue.pop_front())
		_spawn_left = SPAWN_GAP
	if _queue.is_empty() and _alive == 0 and _portals == 0:
		if _wave + 1 < _waves.size():
			_next_wave_left = WAVE_PAUSE
		else:
			_finish()

## Портал на підлозі, за мить із нього вилазить ворог.
func _open_portal(entry: Dictionary) -> void:
	var position: Vector3 = entry.position
	if position == Vector3.INF:
		position = _free_spot()
	_portals += 1
	var marker := CombatVfx.make_ground_marker(PORTAL_COLOR, 1.1)
	add_child(marker)
	marker.global_position = position + Vector3(0, DungeonBuilder.FLOOR_TOP + 0.04, 0)
	var tween := marker.create_tween()
	tween.tween_method(func(value: float) -> void:
		CombatVfx.set_param(marker, &"progress", value), 0.0, 1.0, PORTAL_TIME)
	tween.tween_callback(func() -> void:
		marker.queue_free()
		_portals -= 1
		_emerge(position, entry.definition))

func _emerge(position: Vector3, definition: Dictionary) -> void:
	CombatVfx.shockwave(self, position, 1.4, PORTAL_COLOR, 0.35)
	CombatVfx.impact(self, position + Vector3.UP * 0.4, PORTAL_COLOR, false)
	var enemy: Enemy3D = _spawn.call(position, definition)
	enemy.hunting = true
	enemy.emerge(EMERGE_TIME)
	_alive += 1
	enemy.died.connect(func(_position: Vector3, _xp: int) -> void: _alive -= 1)

## Клітинка зали подалі від героя — для дрібноти й ватажка.
func _free_spot() -> Vector3:
	var best := DungeonBuilder.cell_center(_rect.get_center())
	var best_distance := -1.0
	for attempt in 14:
		var cell := Vector2i(_rng.randi_range(_rect.position.x + 1, _rect.end.x - 2),
			_rng.randi_range(_rect.position.y + 1, _rect.end.y - 2))
		if not DungeonBuilder.is_walkable(_map_rows, cell.x, cell.y):
			continue
		var spot := DungeonBuilder.cell_center(cell)
		var distance := spot.distance_to(_player.global_position)
		if distance >= MIN_SPAWN_DISTANCE:
			return spot
		if distance > best_distance:
			best = spot
			best_distance = distance
	return best

func _finish() -> void:
	_state = State.CLEARED
	_open_barrier()
	cleared.emit(_chest_spot())

## Скриня стає на прохідну клітинку, найближчу до середини зали.
func _chest_spot() -> Vector3:
	var center := _rect.get_center()
	var best := DungeonBuilder.cell_center(center)
	var best_distance := INF
	for z in range(_rect.position.y, _rect.end.y):
		for x in range(_rect.position.x, _rect.end.x):
			if not DungeonBuilder.is_walkable(_map_rows, x, z):
				continue
			var distance := Vector2(x - center.x, z - center.y).length()
			if distance < best_distance:
				best_distance = distance
				best = DungeonBuilder.cell_center(Vector2i(x, z))
	return best

func _close_barrier() -> void:
	_barrier.visible = true
	var tween := _barrier.create_tween()
	tween.tween_property(_barrier, "position:y", 0.0, BARRIER_MOVE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Непрохідна стіна в кожному виході — і для героя, і для ворогів.
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
		rig.shake(0.12)

func _open_barrier() -> void:
	if _barrier_body != null:
		_barrier_body.queue_free()
		_barrier_body = null
	var tween := _barrier.create_tween()
	tween.tween_property(_barrier, "position:y", BARRIER_HIDDEN_Y, BARRIER_MOVE_TIME * 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _barrier.visible = false)
