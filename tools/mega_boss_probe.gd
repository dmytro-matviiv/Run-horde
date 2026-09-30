extends Node

## Перевірка трьох мега-босів (herald_of_doom, icy_abyss_lord, shadow_lord):
## ворота (BossGate) не пускають бос вийти, поки герой не зайшов у залу,
## вступне кіно (BossIntro) відіграє й ЛИШЕ ТОДІ бос виринає з підлоги;
## і кожна нова здібність (метеоритний шторм / вир Безодні / дзеркальний
## розкол) справді ранить, тягне чи плодить двійників.
##   godot --path . res://tools/mega_boss_probe.tscn -- [--level=N]
## Без --level перевіряє всі три рівні (4, 9, 14 — фінальний порядок 1-15) по черзі.
## Пише рядки "PROBE ..." і в кінці "RESULT: OK" або "RESULT: FAIL".

const SCENE := "res://scenes/dungeon/dungeon.tscn"
const ProbeUtil := preload("res://tools/probe_util.gd")

var _failed := false
var _dungeon: Node
var _player: CharacterBody3D

func _ready() -> void:
	PerfSettings.persist_settings = false
	var levels := [4, 9, 14]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			levels = [argument.get_slice("=", 1).to_int()]
	for level_index in levels:
		await _run_level(level_index)
		if _dungeon != null and is_instance_valid(_dungeon):
			_dungeon.queue_free()
			await get_tree().process_frame
	print("RESULT: ", "FAIL" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)

func _run_level(level_index: int) -> void:
	GameState.dungeon_level = level_index
	var level: Dictionary = DungeonLevels.get_level(level_index)
	print("--- рівень %d: %s ---" % [level_index, level.get("boss_title", level.id)])

	_dungeon = load(SCENE).instantiate()
	add_child(_dungeon)
	await _wait(2.0)
	_player = _dungeon.get_node("Player")
	_set_hp(50000.0, 50000.0)

	var gate: Node = _dungeon.get("_boss_gate")
	print("PROBE ворота існують: %s" % (gate != null))
	if gate == null:
		_failed = true
		return
	print("PROBE бос ще не вийшов до кіна: %s" % (_dungeon.get("_boss") == null))
	if _dungeon.get("_boss") != null:
		_failed = true

	var arena: Rect2i = level.boss_arena
	var deep_cell := arena.get_center()
	_player.global_position = DungeonBuilder.cell_center(deep_cell) + Vector3(0, 0.2, 0)
	print("PROBE діагностика: arena=%s deep_cell=%s player_pos=%s player_cell=%s edges=%d" % [
		arena, deep_cell, _player.global_position, DungeonBuilder.cell_of(_player.global_position),
		(gate.get("_edges") as Array).size()])
	await _wait(0.6)
	var sealed: bool = int(gate.get("_state")) == 1
	print("PROBE ворота зачинились, щойно герой зайшов: %s" % sealed)
	if not sealed:
		_failed = true

	# Кіно (BossIntro.AUTO_ADVANCE ~3.4с) добігає само, без пропуску.
	await _wait(4.2)
	var boss: Enemy3D = _dungeon.get("_boss")
	print("PROBE бос виринув після кіна: %s" % (boss != null))
	if boss == null:
		_failed = true
		return
	boss.alert()
	await _wait(0.3)

	for ability_entry: Dictionary in level.boss.abilities:
		var id: String = ability_entry.id
		if id in ["meteor_storm", "void_rift", "mirror_split"]:
			_test_signature_ability(boss, id)
			await _wait(3.0)

	# Бос падає: ворота знову відчиняються, вихід з'являється.
	boss.take_damage(boss.max_hp * 10.0)
	await _wait(1.5)
	var reopened: bool = int(gate.get("_state")) == 2  # State.OPENED
	var exit_open: bool = _dungeon.get("_exit_open")
	print("PROBE після перемоги: ворота знову відчинені %s, вихід відкрито %s" % [reopened, exit_open])
	if not reopened or not exit_open:
		_failed = true

func _test_signature_ability(boss: Enemy3D, id: String) -> void:
	var ability := _find_ability(boss, id)
	if ability == null:
		_failed = true
		return
	match id:
		"meteor_storm":
			_player.global_position = boss.global_position + Vector3(1.0, 0, 1.0)
			var hp_before: float = _player.current_hp
			# Опис рівня — const-літерал (лишень для читання): щоб підмінити
			# лічильники для проби, спершу копія. Малий "span" і багато
			# метеоритів — щоб хоч один точно впав біля героя, а не
			# покладатись на удачу RNG на всю залу.
			ability.config = ability.config.duplicate()
			ability.config["count"] = 20
			ability.config["span"] = 1.5
			ability.config["safe"] = 0
			ability.try_use(0.0)
			await _wait(3.2)
			print("PROBE метеоритний шторм: здоров'я героя %.0f -> %.0f" % [hp_before, _player.current_hp])
			if _player.current_hp >= hp_before:
				_failed = true
		"void_rift":
			_set_hp(50000.0, 50000.0)
			# Розлом ляже там, де стоїть герой (windup 0.8с, він поки не
			# рухається) — центр приблизно тут.
			var center := boss.global_position + Vector3(3.5, 0, 0)
			_player.global_position = center
			var hp_before: float = _player.current_hp
			ability.try_use(0.0)
			await _wait(1.0)
			# Тепер розлом уже є: відбігаємо, як утік би гравець, і дивимось,
			# чи справді тягне назад, а не просто ранить на місці.
			_player.global_position = center + Vector3(3.0, 0, 0)
			var pos_before := _player.global_position
			await _wait(1.6)
			var pulled := pos_before.distance_to(_player.global_position)
			print("PROBE вир Безодні: після втечі підтягнуло назад на %.2f м, здоров'я %.0f -> %.0f" % [pulled, hp_before, _player.current_hp])
			if pulled < 0.1 or _player.current_hp >= hp_before:
				_failed = true
		"mirror_split":
			var before_count := _count_enemies()
			ability.try_use(0.0)
			await _wait(1.0)
			var after_count := _count_enemies()
			print("PROBE дзеркальний розкол: живих ворогів %d -> %d" % [before_count, after_count])
			if after_count <= before_count:
				_failed = true

func _find_ability(boss: Enemy3D, id: String) -> EnemyAbility:
	for ability in boss.abilities:
		if ability.id == id:
			return ability
	push_error("Нема здібності " + id)
	return null

func _count_enemies() -> int:
	var count := 0
	for node in _dungeon.get_node("Enemies").get_children():
		if node is Enemy3D and (node as Enemy3D).is_alive():
			count += 1
	return count

func _set_hp(current: float, maximum: float) -> void:
	_player.max_hp = maximum
	_player.current_hp = current
	_player.health_changed.emit(current, maximum)

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		# Стартовий вибір здібності ставить гру на паузу й чекає на клік —
		# тиснемо першу картку самі, як це вже роблять інші проби.
		if _dungeon != null and is_instance_valid(_dungeon):
			for node in _dungeon.get_node("HUD").get_children():
				if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
					ProbeUtil.press_first_card(node)
