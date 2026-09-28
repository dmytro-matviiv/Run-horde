extends Node

## Діагностика данжу: чи рухається герой, чи існують вороги, чи вони
## помічають героя, ідуть до нього маршрутом і б'ють.
##
##   godot --path . res://tools/dungeon_probe.tscn -- --quality=0

const ProbeUtil := preload("res://tools/probe_util.gd")

const SCENE := "res://scenes/dungeon/dungeon.tscn"

func _ready() -> void:
	PerfSettings.persist_settings = false
	# --level=N — який рівень данжу перевіряти (0, 1, 2).
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, argument.get_slice("=", 1).to_int())
			GameState.dungeon_level = argument.get_slice("=", 1).to_int()
	var quality := 2
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="):
			quality = argument.get_slice("=", 1).to_int()
	PerfSettings.apply_quality(quality, false)
	print("PROBE: якість ", PerfSettings.get_quality_title(), ", фізика ", Engine.physics_ticks_per_second, " Гц")

	var dungeon: Node = load(SCENE).instantiate()
	add_child(dungeon)
	var started := Time.get_ticks_msec()
	await _dismiss_ability_choice(dungeon)
	print("PROBE: рівень готовий за %d мс" % (Time.get_ticks_msec() - started))

	var obstacles: Node = dungeon.find_child("Obstacles", true, false)
	print("PROBE: фізичних форм у перешкодах ", obstacles.get_child_count())

	var player: CharacterBody3D = dungeon.get_node("Player")
	print("PROBE: старт героя ", player.global_position)

	# Женемо героя вперед дві секунди й дивимось, чи зрушив.
	var start := player.global_position
	for i in 120:
		player.set_move_input(Vector2(0, 1))
		await get_tree().physics_frame
	player.set_move_input(Vector2.ZERO)
	print("PROBE: після руху ", player.global_position, " пройшов ", start.distance_to(player.global_position))

	var enemies: Node = dungeon.get_node("Enemies")
	print("PROBE: ворогів у сцені ", enemies.get_child_count())

	# Ставимо героя в центр великої зали: вороги мають помітити, дійти
	# маршрутом і почати бити.
	player.global_position = Vector3(38.0, 0.2, 30.0)
	await get_tree().create_timer(0.6).timeout
	var before := _nearest_distances(enemies, player.global_position)
	var hp_before: float = player.current_hp
	await get_tree().create_timer(4.0).timeout
	var after := _nearest_distances(enemies, player.global_position)
	print("PROBE: відстані 3 найближчих ворогів до/після: ", before, " -> ", after)
	print("PROBE: здоров'я героя ", hp_before, " -> ", player.current_hp)
	var awake := 0
	for enemy in enemies.get_children():
		if (enemy as Node).is_physics_processing():
			awake += 1
	print("PROBE: ворогів не сплять ", awake)
	get_tree().quit(0)

func _nearest_distances(enemies: Node, origin: Vector3) -> Array:
	var distances := []
	for enemy in enemies.get_children():
		distances.append(snappedf((enemy as Node3D).global_position.distance_to(origin), 0.1))
	distances.sort()
	return distances.slice(0, 3)

func _dismiss_ability_choice(dungeon: Node) -> void:
	for i in 600:
		await get_tree().process_frame
		for node in dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen"):
				ProbeUtil.press_first_card(node)
				get_tree().paused = false
				return
	print("PROBE: вікно вибору здібності так і не з'явилось!")
