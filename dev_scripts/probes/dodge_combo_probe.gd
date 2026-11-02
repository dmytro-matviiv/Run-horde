extends Node

## Перевірка ідеального перекату й серії ударів:
##  - перекат в останню мить перед ударом ворога — "Ідеально!", герой
##    цілий, наступні удари критичні;
##  - перекат задовго до удару — звичайний, не ідеальний;
##  - 26 влучань поспіль — серія з нагородами; пропущений удар її гасить.
##   godot --path . res://tools/dodge_combo_probe.tscn -- [--shots=D:/папка]
## Пише рядки "PROBE ..." і в кінці "RESULT: OK" або "RESULT: FAIL".

const ProbeUtil := preload("res://tools/probe_util.gd")
const SCENE := "res://scenes/dungeon/dungeon.tscn"

var _failed := false
var _dungeon: Node
var _player: CharacterBody3D
var _shots := ""
var _perfect := 0

func _ready() -> void:
	PerfSettings.persist_settings = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			_shots = argument.get_slice("=", 1)
	GameState.dungeon_level = 0
	_dungeon = load(SCENE).instantiate()
	add_child(_dungeon)
	await _wait(3.0)
	_player = _dungeon.get_node("Player")
	_player.max_hp = 50000.0
	_player.current_hp = 50000.0
	# Здоров'я змінене напряму — повідомляємо данж, як це зробила б гра.
	_player.health_changed.emit(_player.current_hp, _player.max_hp)
	_player.perfect_dodge.connect(func() -> void: _perfect += 1)
	# Звичайний ворог, не еліта: випадкові риси зробили б перевірку нестабільною.
	var base: Dictionary = DungeonLevels.get_level(0).enemies.m[0].duplicate()
	base.no_elite = true
	var enemy: Enemy3D = _dungeon.call("_spawn_enemy", _player.global_position + Vector3(0, 0, -1.4), base, false)
	enemy.max_hp = 100000.0
	enemy.current_hp = 100000.0
	enemy.alert()

	# 1) Перекат в останню мить.
	await _wait_windup(enemy, 0.12)
	var hp_before: float = _player.current_hp
	_player.dodge()
	await _wait(0.25)
	await _shot("perfect_dodge")
	await _wait(0.4)
	print("PROBE пізній перекат: ідеальних %d, здоров'я %.0f -> %.0f, крити: %s" % [
		_perfect, hp_before, _player.current_hp, _player.has_perfect_crits()])
	if _perfect != 1 or _player.current_hp < hp_before or not _player.has_perfect_crits():
		_failed = true

	# 2) Перекат задовго до удару — не ідеальний.
	await _wait(1.5)
	_player.global_position = enemy.global_position + Vector3(0, 0.1, 1.4)
	await _wait_windup(enemy, 0.5)
	_player.dodge()
	await _wait(1.0)
	print("PROBE ранній перекат: ідеальних усього %d (має лишитись 1)" % _perfect)
	if _perfect != 1:
		_failed = true

	# 3) Серія: 26 влучань — два пороги, нагороди діють.
	enemy.stun(20.0)
	var combo: ComboMeter = _dungeon.get("_combo")
	for i in 26:
		_player.deal_damage(enemy, 0.01, Vector3.ZERO, false)
		await get_tree().process_frame
	await _wait(0.2)
	await _shot("combo")
	var bonus: float = _player.get("_bonus_damage_left")
	print("PROBE серія: %d ударів, посилення шкоди ще %.1f с" % [combo.get_count(), bonus])
	# Щонайменше 26: пасивки й узяті здібності героя теж можуть влучити.
	if combo.get_count() < 26 or bonus <= 0.0:
		_failed = true
	await _wait(0.6)
	_player.take_damage(1.0)
	await _wait(0.1)
	print("PROBE після пропущеного удару серія: %d" % combo.get_count())
	if combo.get_count() != 0:
		_failed = true
	print("RESULT: ", "FAIL" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)

## Дочекатися замаху ворога, поки до удару лишиться менше за left секунд.
func _wait_windup(enemy: Enemy3D, left: float) -> void:
	var until := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		var windup: float = enemy.get("_windup_left")
		if windup > 0.0 and windup <= left:
			return
	print("PROBE ворог так і не замахнувся")
	_failed = true

func _shot(name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_shots, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("PROBE кадр: ", path)

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
