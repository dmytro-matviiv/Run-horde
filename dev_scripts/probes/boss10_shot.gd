extends Node
## Тимчасово (лише в test_env): Темний лицар у бою на 10-му рівні — кадри
## раз на 0.5 с (ходьба, удари, чари, стрибок) і смерть.
const SCENE := "res://scenes/dungeon/dungeon.tscn"
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		_player.max_hp = 99999.0
		_player.current_hp = 99999.0
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _ready() -> void:
	PerfSettings.persist_settings = false
	var lvl := 9
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="): lvl = a.get_slice("=", 1).to_int()
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, lvl)
	GameState.dungeon_level = lvl
	_dungeon = load(SCENE).instantiate()
	var dungeon := _dungeon
	add_child(dungeon)
	_player = dungeon.get_node("Player")
	var player := _player
	await _wait(2.0)
	var level: Dictionary = DungeonLevels.get_level(lvl)
	var arena: Rect2i = level.boss_arena
	player.global_position = DungeonBuilder.cell_center(arena.get_center() + Vector2i(0, 4)) + Vector3(0, 0.2, 0)
	await _wait(4.8)
	var boss: Enemy3D = dungeon.get("_boss")
	print("BOSS ", boss != null)
	if boss == null:
		get_tree().quit(1)
		return
	boss.alert()
	for i in 24:
		await _wait(0.5)
		await RenderingServer.frame_post_draw
		var anim: AnimationPlayer = boss.get("_animation")
		if OS.get_cmdline_user_args().has("--phases"):
			if i == 8:
				boss.current_hp = boss.max_hp * 0.45
			if i == 16:
				boss.current_hp = boss.max_hp * 0.2
		var clones := ""
		for e in _dungeon.find_children("*", "Enemy3D", true, false):
			if e != boss and e.is_alive():
				var ca: AnimationPlayer = e.get("_animation")
				clones += " клон[%s %.1f м]" % [ca.current_animation if ca else "-", e.global_position.distance_to(player.global_position)]
		print("FRAME %d phase %d anim %s%s" % [i, boss.phases.phase if boss.phases else 0, anim.current_animation if anim else "-", clones])
		get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/boss%d_%02d.png" % [lvl + 1, i])
	boss.call("take_damage", 1000000.0) if boss.has_method("take_damage") else null
	for i in 4:
		await _wait(0.7)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/boss%d_death_%d.png" % [lvl + 1, i])
	var alive := 0
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		if e.is_alive():
			alive += 1
	print("ALIVE after boss death: ", alive)
	print("SHOT ok")
	get_tree().quit(0)
