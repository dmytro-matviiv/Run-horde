extends Node

## Де саме данж витрачає процесорний час. Міряє кілька сценаріїв:
## звичайний бій, бій без анімацій ворогів, без фізики ворогів, без
## анімації героя, — і скільки коштує побудова одного шматка данжу.
## Числа з ПК в абсолютному вимірі до телефона не переносяться, але
## ПРОПОРЦІЇ ті самі: що важке тут, те важке й там.
##
##   godot --path . res://tools/cpu_probe.tscn -- --quality=0

const ProbeUtil := preload("res://tools/probe_util.gd")

const SCENE := "res://scenes/dungeon/dungeon.tscn"
const SAMPLE_FRAMES := 180

var _dungeon: Node
var _player: CharacterBody3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	var quality := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="):
			quality = argument.get_slice("=", 1).to_int()
	PerfSettings.apply_quality(quality, false)
	# Як на телефоні: стеля кадрів і фізика з однаковою частотою, тож у
	# кожному кадрі рівно один крок фізики і показники чесні.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	var scenario := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scenario="):
			scenario = argument.get_slice("=", 1)
	if scenario == "chunks":
		_measure_chunk_build()
		get_tree().quit(0)
		return

	_dungeon = load(SCENE).instantiate()
	add_child(_dungeon)
	await _dismiss_popups(600)
	_player = _dungeon.get_node("Player")
	_player.combat_input_enabled = false

	# Герой у великій залі: вороги прокидаються й нападають. Вороги
	# безсмертні, щоб за час заміру їх не поменшало.
	_player.global_position = Vector3(38, 0.2, 30)
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		enemy.max_hp = 1e9
		enemy.current_hp = 1e9
	if scenario == "spikes":
		for i in 3:
			_player.attack()
			await get_tree().create_timer(0.4).timeout
		await _catch_spikes("перший бій (ефекти вперше)", 60)
		get_tree().quit(0)
		return
	await get_tree().create_timer(3.0).timeout
	match scenario:
		"nonav":
			_set_enemy_navigation(false)
		"noanim":
			_set_enemy_animation(false)
		"nophys":
			_set_enemy_physics(false)
		"nohero":
			_player.animation_tree.active = false
		"noenemies":
			for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
				enemy.queue_free()
	await _throughput(scenario + " (не сплять %d)" % _awake_count())
	get_tree().quit(0)

## Скільки коштує зібрати один шматок данжу з нуля.
func _measure_chunk_build() -> void:
	var level := DungeonLevels.get_level(0)
	var root := Node3D.new()
	add_child(root)
	var markers := DungeonBuilder.build_base(level.map, root)
	var worst := 0.0
	var total := 0.0
	for chunk: Dictionary in markers.chunks:
		var started := Time.get_ticks_usec()
		DungeonBuilder.build_chunk(level.map, chunk, 1.0)
		var spent := (Time.get_ticks_usec() - started) / 1000.0
		worst = maxf(worst, spent)
		total += spent
	print("CPU: побудова шматка данжу — у середньому %.1f мс, найдовший %.1f мс (%d шматків)" % [
		total / markers.chunks.size(), worst, markers.chunks.size()])
	root.queue_free()

## Скільки кадрів гра встигає за 5 секунд без стелі кадрів. На ПК
## відеокарта могутня, тож число кадрів упирається в процесор — саме
## те, що нас цікавить.
func _throughput(title: String) -> void:
	Engine.max_fps = 0
	await get_tree().create_timer(0.5).timeout
	var frames := 0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 5000:
		_keep_fighting()
		await get_tree().process_frame
		frames += 1
	var per_frame := 5000.0 / frames
	print("CPU: %-28s %5d кадрів/с -> %.2f мс роботи на кадр" % [title, frames / 5, per_frame])

func _sample(title: String) -> void:
	await get_tree().create_timer(0.5).timeout
	var process_total := 0.0
	var physics_total := 0.0
	var render_total := 0.0
	var worst_frame := 0.0
	var viewport := get_viewport().get_viewport_rid()
	for i in SAMPLE_FRAMES:
		_keep_fighting()
		await get_tree().process_frame
		process_total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		render_total += RenderingServer.viewport_get_measured_render_time_cpu(viewport) \
			+ RenderingServer.get_frame_setup_time_cpu()
		worst_frame = maxf(worst_frame, get_process_delta_time() * 1000.0)
	print("CPU: %-28s скрипти+анімації %.2f мс, фізика %.2f мс, підготовка малювання %.2f мс, найдовший кадр %.1f мс" % [
		title, process_total / SAMPLE_FRAMES, physics_total / SAMPLE_FRAMES,
		render_total / SAMPLE_FRAMES, worst_frame])

## Ловить кадри, довші за 2 бюджети кадру.
func _catch_spikes(title: String, frames: int) -> void:
	var spikes := []
	for i in frames:
		_keep_fighting()
		var started := Time.get_ticks_usec()
		await get_tree().process_frame
		var spent := (Time.get_ticks_usec() - started) / 1000.0
		if spent > 66.0:
			spikes.append(roundi(spent))
	print("CPU: %s — ривки довші за 2 кадри: %s" % [title, spikes])

## Герой біжить коридором кілька секунд — рахуємо кадри-ривки.
func _sample_walk() -> void:
	var times := []
	for i in 360:
		_player.set_move_input(Vector2(0, 1))
		await get_tree().process_frame
		times.append(get_process_delta_time() * 1000.0)
	_player.set_move_input(Vector2.ZERO)
	times.sort()
	var median: float = times[times.size() / 2]
	var spikes := 0
	for t: float in times:
		if t > median * 3.0 and t > 8.0:
			spikes += 1
	print("CPU: ходьба коридором — медіана кадру %.1f мс, найдовший %.1f мс, ривків (кадр утричі довший) %d" % [
		median, times[-1], spikes])

func _keep_fighting() -> void:
	_player.current_hp = _player.max_hp

func _awake_count() -> int:
	var count := 0
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.is_physics_processing():
			count += 1
	return count

## Вороги "бачать" героя, але не рахують маршрут: ідуть напряму.
func _set_enemy_navigation(enabled: bool) -> void:
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		enemy._agent.set_physics_process(enabled)
		enemy._repath_left = 0.0 if enabled else 1e9

func _set_enemy_animation(enabled: bool) -> void:
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		enemy.set_process(enabled)

func _set_enemy_physics(enabled: bool) -> void:
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(enabled)

func _dismiss_popups(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen"):
				ProbeUtil.press_first_card(node)
				get_tree().paused = false
				return

func _process(_delta: float) -> void:
	if _dungeon == null or not get_tree().paused:
		return
	for node in _dungeon.get_node("HUD").get_children():
		if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
			ProbeUtil.press_first_card(node)
