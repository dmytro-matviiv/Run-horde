extends Node
## Дотики по екрану в данжі: (1) дотик у правій половині повз кнопки НЕ
## б'є; (2) дотик біля краю кнопки перекату (за намальованим колом) —
## перекат; (3) кнопка удару б'є.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
var _failed := false
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _tap(position: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = position
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = position
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
func _ready() -> void:
	PerfSettings.persist_settings = false
	GameState.dungeon_level = 0
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	var buttons := _dungeon.find_children("*", "CombatButton", true, false)
	var dodge: CombatButton
	var attack: CombatButton
	for b: CombatButton in buttons:
		if b.icon_kind == "dodge":
			dodge = b
		elif b.radius >= 60.0:
			attack = b
	var area := get_viewport().get_visible_rect().size
	# 1. Права половина, вище кнопок.
	await _tap(Vector2(area.x * 0.7, area.y * 0.35))
	await _wait(0.1)
	var attacked: bool = int(_player.get("_attack_step")) >= 0
	print("PROBE дотик по екрану вдарив: %s (має бути false)" % attacked)
	if attacked:
		_failed = true
	await _wait(0.8)
	# 2. Біля краю перекату: 1.25 радіуса від центру, ліворуч.
	var center := dodge.get_global_rect().get_center()
	await _tap(center + Vector2(-dodge.radius * 1.25, 0))
	await _wait(0.05)
	var rolled: bool = float(_player.get("_roll_left")) > 0.0
	print("PROBE дотик за краєм кола перекату (1.25 радіуса) — перекат: %s, радіус кнопки %.0f" % [rolled, dodge.radius])
	if not rolled:
		_failed = true
	await _wait(1.0)
	# 3. Кнопка удару.
	var a_center := attack.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = a_center
	down.pressed = true
	Input.parse_input_event(down)
	await _wait(0.4)
	var holding: bool = bool(_player.get("_attack_held"))
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = a_center
	up.pressed = false
	Input.parse_input_event(up)
	print("PROBE кнопка удару тримає удар: %s" % holding)
	if not holding:
		_failed = true
	print("RESULT: ", "FAIL" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)
