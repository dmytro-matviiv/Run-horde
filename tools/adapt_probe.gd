extends Node

## Перевіряє автоматичне підлаштування якості: штучно гальмуємо кожен
## кадр (ніби слабкий процесор) і дивимось, чи гра сама опуститься на
## нижчий рівень, а коли гальмування зникне — чи не "гойдається".

const ProbeUtil := preload("res://tools/probe_util.gd")

var _slow_ms := 0

func _ready() -> void:
	PerfSettings.persist_settings = false
	PerfSettings._adaptive = true
	PerfSettings.auto_quality = true
	PerfSettings.apply_quality(PerfSettings.Quality.MEDIUM, false)

	var dungeon: Node = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(dungeon)
	for i in 600:
		await get_tree().process_frame
		var picked := false
		for node in dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen"):
				ProbeUtil.press_first_card(node)
				picked = true
		if picked:
			break
	get_tree().paused = false

	_report("старт")
	_slow_ms = 24
	for second in 12:
		await get_tree().create_timer(1.0).timeout
		_report("гальмуємо %d с" % (second + 1))
	_slow_ms = 0
	for second in 6:
		await get_tree().create_timer(1.0).timeout
		_report("без гальмування %d с" % (second + 1))
	get_tree().quit(0)

func _process(_delta: float) -> void:
	if _slow_ms > 0:
		OS.delay_msec(_slow_ms)

func _report(stage: String) -> void:
	print("ADAPT: %-22s якість %-8s роздільність %d%%  стеля %d  кадрів %d" % [
		stage, PerfSettings.get_quality_title(), roundi(get_tree().root.scaling_3d_scale * 100.0),
		Engine.max_fps, Engine.get_frames_per_second()])
