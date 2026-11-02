extends Node
## Тимчасово (test_env): скільки здоров'я забирає вир 10-го боса —
## (1) герой одразу тікає, (2) стоїть на місці весь час.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _ready() -> void:
	PerfSettings.persist_settings = false
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, 9)
	GameState.dungeon_level = 9
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.0)
	var level: Dictionary = DungeonLevels.get_level(9)
	var center := DungeonBuilder.cell_center(level.boss_arena.get_center())
	var tick: float = 35.0 * preload("res://scenes/dungeon/abilities/void_rift_ability.gd").TICK_DAMAGE_SHARE
	# Бос і вороги — геть: міряємо лише вир.
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		e.queue_free()
	await _wait(0.2)
	for run in ["тікає", "стоїть", "без виру"]:
		_player.max_hp = 500.0
		_player.current_hp = 500.0
		_player.global_position = center + Vector3(0.3, 0.2, 0.0)
		await _wait(0.3)
		print("PROBE старт hp %.1f / %.1f" % [_player.current_hp, _player.max_hp])
		if run != "без виру":
			HazardRift.spawn(_dungeon, center, _player, 4.5, 3.4, tick, 6.5)
		if run == "тікає":
			_player.set_move_input(Vector2(1, 0))
		await _wait(7.0)
		_player.set_move_input(Vector2.ZERO)
		print("PROBE %s: втратив %.1f з 500 (дотик ядра %.1f)" % [run, 500.0 - _player.current_hp, tick])
	get_tree().quit(0)
