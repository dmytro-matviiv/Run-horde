extends Node

## Перевірка предметів у залах: вибухові бочки (ланцюжок, шкода ворогам),
## шипи (ранять героя), святилища (дають силу).
##   godot --path . res://tools/props_probe.tscn -- [--level=N] [--shots=D:/папка]
## Пише рядки "PROBE ..." і в кінці "RESULT: OK" або "RESULT: FAIL".

const ProbeUtil := preload("res://tools/probe_util.gd")
const SCENE := "res://scenes/dungeon/dungeon.tscn"

var _failed := false
var _dungeon: Node
var _player: CharacterBody3D
var _shots := ""

func _ready() -> void:
	PerfSettings.persist_settings = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, argument.get_slice("=", 1).to_int())
			GameState.dungeon_level = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--shots="):
			_shots = argument.get_slice("=", 1)
	_dungeon = load(SCENE).instantiate()
	add_child(_dungeon)
	await _wait(3.0)
	_player = _dungeon.get_node("Player")
	var props: Node = _dungeon.get_node("Props")
	var barrels := props.get_children().filter(func(n: Node) -> bool: return n is ExplosiveBarrel)
	var traps := props.get_children().filter(func(n: Node) -> bool: return n is SpikeTrap)
	var shrines := props.get_children().filter(func(n: Node) -> bool: return n is Shrine)
	print("PROBE рівень %d: бочок %d, плит шипів %d, святилищ %d" % [
		GameState.dungeon_level, barrels.size(), traps.size(), shrines.size()])
	if barrels.is_empty() or traps.is_empty() or shrines.is_empty():
		_failed = true
	# Герой має вціліти під час перевірки бочок і шипів.
	_player.max_hp = 5000.0
	_player.current_hp = 5000.0

	if barrels.size() >= 2:
		await _test_barrels(barrels[0], barrels[1])
	if not traps.is_empty():
		await _test_trap(traps[0])
	if not shrines.is_empty():
		await _test_shrine(shrines[0])
	print("RESULT: ", "FAIL" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)

## Дві бочки поруч і двоє ворогів біля першої: удар по першій має
## підірвати обидві й поранити ворогів.
func _test_barrels(first: ExplosiveBarrel, second: ExplosiveBarrel) -> void:
	second.global_position = first.global_position + Vector3(2.0, 0, 0)
	var victims: Array[Enemy3D] = []
	for node in _dungeon.get_node("Enemies").get_children():
		var enemy := node as Enemy3D
		if enemy != null and enemy.is_alive() and enemy.kind != Enemy3D.Kind.BOSS and victims.size() < 2:
			victims.append(enemy)
	var hp_before: Array[float] = []
	for i in victims.size():
		victims[i].global_position = first.global_position + Vector3(-1.5, 0.2, 1.0 - 2.0 * i)
		# Оглушені: інакше швидкий ворог устигає вибігти з-під вибуху.
		victims[i].stun(3.0)
		hp_before.append(victims[i].current_hp)
	_player.global_position = first.global_position + Vector3(0, 0.2, 6.0)
	await _wait(0.6)
	await _shot("barrel_before")
	first.take_damage(1.0)
	await _wait(0.3)
	await _shot("barrel_fuse")
	await _wait(0.45)
	await _shot("barrel_blast")
	await _wait(0.8)
	var hurt := 0
	for i in victims.size():
		if not is_instance_valid(victims[i]) or not victims[i].is_alive() or victims[i].current_hp < hp_before[i]:
			hurt += 1
	var gone := int(not is_instance_valid(first)) + int(not is_instance_valid(second))
	print("PROBE бочки: вибухнуло %d з 2, поранено ворогів %d з %d" % [gone, hurt, victims.size()])
	if gone != 2 or hurt != victims.size():
		_failed = true

func _test_trap(trap: SpikeTrap) -> void:
	_player.global_position = trap.global_position + Vector3(0, 0.1, 0)
	var before: float = _player.current_hp
	var shot_taken := false
	var until := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < until and _player.current_hp >= before:
		await get_tree().physics_frame
		_player.global_position = trap.global_position + Vector3(0, 0.1, 0)
		if not shot_taken and trap.get("_state") == SpikeTrap.State.WARN:
			shot_taken = true
			await _shot("trap_warn")
	await _wait(0.1)
	await _shot("trap_up")
	print("PROBE шипи: здоров'я героя %.0f -> %.0f" % [before, _player.current_hp])
	if _player.current_hp >= before:
		_failed = true

func _test_shrine(shrine: Shrine) -> void:
	_player.global_position = shrine.global_position + Vector3(0, 0.1, 3.5)
	_player.current_hp = _player.max_hp * 0.3
	await _wait(0.6)
	await _shot("shrine")
	var hp_before: float = _player.current_hp
	_player.global_position = shrine.global_position + Vector3(0, 0.1, 1.0)
	await _wait(0.6)
	var buff: Dictionary = _player.get_shrine_buff()
	print("PROBE святилище %s: сила %s, здоров'я %.0f -> %.0f" % [shrine.kind, buff, hp_before, _player.current_hp])
	if shrine.kind == &"life":
		if _player.current_hp <= hp_before:
			_failed = true
	elif buff.is_empty() or buff.kind != shrine.kind:
		_failed = true
	await _shot("shrine_used")

func _shot(name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	var path := "%s/props_%s.png" % [_shots, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("PROBE кадр: ", path)

## Чекати справжні секунди, закриваючи вікна вибору здібності.
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
