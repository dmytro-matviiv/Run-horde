import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:80])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


edit('scenes/dungeon/enemy_3d.gd', [
('''## Фази боса (лише в боса).
var phases: BossPhases
''', '''## Фази боса (лише в боса).
var phases: BossPhases
## Ворог за ґратами засідки: поки вона триває, героя він не помічає — не
## біжить до ґраток і не збирається там юрбою, а після бою не вривається
## в залу всією кімнатою. Вмикає й вимикає данж.
var shut_out := false
'''),
('''func _update_aggro(distance: float) -> void:
	if _player.has_method("is_targetable") and not _player.is_targetable():''', '''func _update_aggro(distance: float) -> void:
	if shut_out or (_player.has_method("is_targetable") and not _player.is_targetable()):'''),
])

edit('scenes/dungeon/arena_ambush.gd', [
('''func is_active() -> bool:
	return _state == State.FIGHTING
''', '''func is_active() -> bool:
	return _state == State.FIGHTING

## Чи стоїть точка всередині зали засідки.
func contains(position: Vector3) -> bool:
	return _rect.has_point(DungeonBuilder.cell_of(position))
'''),
])

edit('scenes/dungeon/dungeon.gd', [
('''		arena.wave_started.connect(_on_arena_wave)
		arena.cleared.connect(_on_arena_cleared)
''', '''		arena.started.connect(_shut_out_around.bind(arena))
		arena.wave_started.connect(_on_arena_wave)
		arena.cleared.connect(_on_arena_cleared)

## Засідка почалась: вороги поза залою героя "не чують", доки вона триває,
## — інакше сусідня кімната збігалась до ґраток. Ті, хто встиг забігти
## в залу, б'ються разом із хвилями.
func _shut_out_around(arena: ArenaAmbush) -> void:
	for node in enemies_root.get_children():
		var enemy := node as Enemy3D
		if enemy != null and enemy.is_alive():
			enemy.shut_out = not arena.contains(enemy.global_position)

func _release_shut_out() -> void:
	for node in enemies_root.get_children():
		var enemy := node as Enemy3D
		if enemy != null:
			enemy.shut_out = false
'''),
('''func _on_arena_cleared(center: Vector3) -> void:
	_arena_status = ""''', '''func _on_arena_cleared(center: Vector3) -> void:
	_arena_status = ""
	_release_shut_out()'''),
])

edit('tools/arena_probe.gd', [
('''	var rect: Rect2i = arena.get("_rect")
	var center := DungeonBuilder.cell_center(rect.get_center()) + Vector3(0, 0.3, 0)
	_player.global_position = center''', '''	var rect: Rect2i = arena.get("_rect")
	var center := DungeonBuilder.cell_center(rect.get_center()) + Vector3(0, 0.3, 0)
	# Сусід за ґратами: ворог просто за першим виходом із зали. Поки засідка
	# триває, він не має бігти до героя.
	var edges: Array = arena.get("_edges")
	var first_edge: Dictionary = edges[0]
	var outward: Vector3 = first_edge.center - DungeonBuilder.cell_center(rect.get_center())
	outward.y = 0.0
	var outside_spot: Vector3 = first_edge.center + outward.normalized() * 3.0
	var neighbour_def: Dictionary = DungeonLevels.get_level(GameState.dungeon_level).enemies.m[0].duplicate()
	neighbour_def.no_elite = true
	var neighbour: Enemy3D = _dungeon.call("_spawn_enemy", outside_spot, neighbour_def, false)
	neighbour.max_hp = 100000.0
	neighbour.current_hp = 100000.0
	_player.global_position = center'''),
('''	await _test_barrier(arena, rect)
''', '''	await _test_barrier(arena, rect)
	# Герой стоїть біля ґратки, за якою сусід, — сусід не рушає з місця.
	var neighbour_start := neighbour.global_position
	await _wait(2.5)
	var neighbour_moved := neighbour.global_position.distance_to(neighbour_start)
	print("PROBE сусід за ґратами: зрушив на %.2f м, помітив героя: %s" % [neighbour_moved, neighbour.get("_aggro")])
	if neighbour_moved > 0.5 or neighbour.get("_aggro"):
		_failed = true
'''),
('''	await _wait(1.0)
	var body: Variant = arena.get("_barrier_body")''', '''	await _wait(1.0)
	print("PROBE після засідки сусід знову чує героя: %s" % (not neighbour.shut_out))
	if neighbour.shut_out:
		_failed = true
	var body: Variant = arena.get("_barrier_body")'''),
])
print('ok')
