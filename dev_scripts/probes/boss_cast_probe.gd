extends Node
## Тимчасово (test_env): каст боса — що його збиває.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	var first := true
	while first or Time.get_ticks_msec() < until:
		first = false
		await get_tree().physics_frame
		_player.max_hp = 99999.0
		_player.current_hp = 99999.0
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _start(boss: Enemy3D, special: String) -> void:
	boss.set("_windup_left", 0.0)
	boss.set("_stagger_left", 0.0)
	boss.set("_frozen_left", 0.0)
	boss.begin_special(special, 5.0, Color(1, 1, 1, 0), 0.1)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, 2)
	GameState.dungeon_level = 2
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.0)
	var boss: Enemy3D = _dungeon.get("_boss")
	var results := []
	_start(boss, "frost_breath")
	_player.deal_damage(boss, 0.01, Vector3.ZERO, true)
	boss.stun(1.0)
	boss.freeze(1.0)
	results.append("зброя+оглушення+заморозка: каст %s" % (boss.get("_windup_left") > 0.0))
	_player.deal_damage(boss, 0.01, Vector3.ZERO, true, &"whirlwind")
	results.append("суперудар: каст %s" % (boss.get("_windup_left") > 0.0))
	_start(boss, "frost_breath")
	boss.freeze(1.0, true)
	results.append("суперзаморозка: каст %s" % (boss.get("_windup_left") > 0.0))
	for a in boss.abilities:
		results.append("%s uninterruptible=%s" % [a.id, a.uninterruptible])
	for a in boss.abilities:
		if a.id == "sky_fall":
			a.uninterruptible = true
	_start(boss, "sky_fall")
	_player.deal_damage(boss, 0.01, Vector3.ZERO, true, &"whirlwind")
	results.append("перехідний каст + суперудар: каст %s" % (boss.get("_windup_left") > 0.0))
	print("PROBE ", "\nPROBE ".join(results))
	get_tree().quit(0)
