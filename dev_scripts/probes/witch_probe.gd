extends Node
## Тимчасово (test_env): Інейна чаклунка — прийоми й переривання (цифри).
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
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, 2)
	GameState.dungeon_level = 2
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	var witch: Enemy3D = null
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		if e.display_name == "Інейна чаклунка" and witch == null:
			witch = e
		elif e.kind != Enemy3D.Kind.BOSS:
			e.queue_free()
	print("PROBE чаклунка %s, анімації %s" % [witch != null, witch.find_child("AnimationPlayer", true, false).get_animation_list() if witch else []])
	_player.global_position = witch.global_position + Vector3(0, 0.2, 4.0)
	witch.alert()
	var seen := {}
	var rooted := false
	var slowed := false
	var hp0: float = _player.current_hp
	for i in 60 * 22:
		await _wait(0.0)
		var special: String = witch.get("_special")
		if special != "" and not seen.has(special):
			seen[special] = i / 60.0
		for a in witch.abilities:
			if a.id == "freezing_field" and a.is_busy() and not seen.has("freezing_field"):
				seen["freezing_field"] = i / 60.0
				print("PROBE поле: анімація %s" % witch.find_child("AnimationPlayer", true, false).current_animation)
		if _player.is_rooted():
			rooted = true
		if _player.get("_slow_left") != null and float(_player.get("_slow_left")) > 0.0:
			slowed = true
	print("PROBE прийоми (с): %s, скуто %s, сповільнено %s" % [seen, rooted, slowed])
	# Переривання: звичайний удар не збиває поле, суперздібність — збиває.
	var field = null
	for a in witch.abilities:
		if a.id == "freezing_field":
			field = a
	field.set("_left", 0.0)
	witch.set("_attack_left", 0.0)
	var waited := 0
	while not field.is_busy() and waited < 600:
		await _wait(0.0)
		field.set("_left", 0.0)
		waited += 1
	print("PROBE поле знову: %s" % field.is_busy())
	_player.deal_damage(witch, 0.01, Vector3.ZERO, false)
	witch.stun(1.0)
	await _wait(0.2)
	print("PROBE після удару зброєю: поле %s" % field.is_busy())
	_player.deal_damage(witch, 0.01, Vector3.ZERO, true, &"frost_nova")
	await _wait(0.2)
	print("PROBE після суперздібності: поле %s, анімація %s" % [field.is_busy(), witch.find_child("AnimationPlayer", true, false).current_animation])
	# Звичайний замах (кришталевий вибух) — удар зброєю не збиває.
	var nova = null
	for a in witch.abilities:
		if a.id == "crystal_nova":
			nova = a
	for a in witch.abilities:
		a.set("_left", 99.0)
	nova.set("_left", 0.0)
	witch.set("_attack_left", 0.0)
	witch.set("_stagger_left", 0.0)
	waited = 0
	while String(witch.get("_special")) != "crystal_nova" and waited < 600:
		await _wait(0.0)
		waited += 1
	_player.deal_damage(witch, 0.01, Vector3.ZERO, true)
	await _wait(0.05)
	print("PROBE вибух після удару зброєю: замах %.2f (special '%s')" % [witch.get("_windup_left"), witch.get("_special")])
	get_tree().quit(0)
