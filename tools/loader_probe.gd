extends Node

## Перевіряє переходи через екран завантаження: острів -> данж -> острів.
## Друкує, скільки тривав перехід і який був найдовший кадр (ривок).

func _ready() -> void:
	PerfSettings.persist_settings = false
	# Сам тест не має зникнути разом зі сценою, тож "поточною сценою"
	# робимо порожню заглушку.
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await get_tree().process_frame
	get_tree().current_scene = dummy

	await _go("res://scenes/world/base_island.tscn", "База")
	await _go("res://scenes/dungeon/dungeon.tscn", "Забуті склепи")
	var choice_found := false
	for node in get_tree().current_scene.get_node("HUD").get_children():
		if node.has_signal("upgrade_chosen"):
			choice_found = true
			node.upgrade_chosen.emit(&"weapon_damage")
	print("LOADER: вибір здібності після завантаження: ", choice_found)
	get_tree().paused = false
	await get_tree().create_timer(1.0).timeout
	print("LOADER: ворогів у данжі ", get_tree().current_scene.get_node("Enemies").get_child_count())
	await _go("res://scenes/world/base_island.tscn", "База")
	get_tree().quit(0)

func _go(path: String, title: String) -> void:
	var started := Time.get_ticks_msec()
	var worst := 0.0
	SceneLoader.change_scene(path, title)
	while SceneLoader.is_busy():
		await get_tree().process_frame
		worst = maxf(worst, get_process_delta_time())
		if get_process_delta_time() > 0.025:
			print("LOADER:   ривок %d мс на етапі %d" % [int(get_process_delta_time() * 1000.0), SceneLoader._state])
	print("LOADER: %s за %d мс, найдовший кадр %d мс, сцена %s" % [
		title, Time.get_ticks_msec() - started, int(worst * 1000.0), get_tree().current_scene.name])
