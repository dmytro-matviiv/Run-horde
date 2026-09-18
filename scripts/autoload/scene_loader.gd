extends CanvasLayer

## Плавний перехід між локаціями: екран завантаження + фонове
## завантаження сцени.
##
## Раніше перехід на острів чи в данж робився одним викликом, який
## вантажив усе й одразу. На слабкому телефоні екран на секунду-дві
## "замерзав", і здавалось, що гра зависла. Тепер:
##   1. плавно з'являється екран завантаження;
##   2. сцена вантажиться в окремому потоці — картинка живе, смужка
##      заповнюється;
##   3. нова сцена може попросити почекати (SceneLoader.hold()), поки
##      сама не збере важке. Данж так будує найближчі зали й карту
##      прохідності, і гравець бачить смужку, а не ривки першої секунди.
##
## Користування: SceneLoader.change_scene("res://...", "Назва локації")

const FADE_IN_TIME := 0.18
const FADE_OUT_TIME := 0.3

## Щоб екран завантаження не був порожнім. Заодно навчає гравця.
const HINTS := [
	"Права половина екрана крутить камеру, короткий дотик по ній — удар.",
	"Стрільці не бачать крізь стіни: зайди за ріг, щоб сховатись.",
	"Вороги помічають героя не одразу — у кожного своя дальність агро.",
	"Після боса відчиняється вихід: на базу або на рівень складніше.",
	"За кожен рівень героя в данжі — нова здібність на вибір.",
]

enum State {IDLE, FADING_IN, LOADING, WAITING_SCENE, FADING_OUT}

var _state := State.IDLE
var _path := ""
var _holds := 0
var _timer := 0.0
var _frames_after_change := 0
var _shown_progress := 0.0

var _root: Control
var _title_label: Label
var _hint_label: Label
var _bar: ProgressBar

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

## Перейти на іншу сцену через екран завантаження.
func change_scene(path: String, title: String = "") -> void:
	if _state != State.IDLE:
		return
	_path = path
	_holds = 0
	_timer = 0.0
	_shown_progress = 0.0
	_bar.value = 0.0
	_title_label.text = title if title != "" else "Завантаження"
	_hint_label.text = HINTS[randi() % HINTS.size()]
	_root.modulate.a = 0.0
	visible = true
	_state = State.FADING_IN

## Нова сцена просить потримати екран, поки вона готується.
func hold() -> void:
	_holds += 1

func release() -> void:
	_holds = maxi(_holds - 1, 0)

func is_busy() -> bool:
	return _state != State.IDLE

func _process(delta: float) -> void:
	match _state:
		State.FADING_IN:
			_timer += delta
			_root.modulate.a = clampf(_timer / FADE_IN_TIME, 0.0, 1.0)
			if _timer >= FADE_IN_TIME:
				_start_loading()
		State.LOADING:
			_poll_loading()
		State.WAITING_SCENE:
			_frames_after_change += 1
			# Поки нова сцена готується, смужка повільно доповзає до кінця:
			# гравець бачить, що гра жива.
			_set_progress(lerpf(_shown_progress, 0.98, 1.0 - exp(-delta * 1.5)))
			if _frames_after_change >= 3 and _holds == 0:
				_set_progress(1.0)
				_timer = 0.0
				_state = State.FADING_OUT
		State.FADING_OUT:
			_timer += delta
			_root.modulate.a = 1.0 - clampf(_timer / FADE_OUT_TIME, 0.0, 1.0)
			if _timer >= FADE_OUT_TIME:
				visible = false
				_state = State.IDLE

func _start_loading() -> void:
	get_tree().paused = false
	# Про всяк випадок: якщо перехід стався посеред "заморожування" кадру
	# від удару, нова сцена має стартувати з нормальною швидкістю.
	Engine.time_scale = 1.0
	# Окремі потоки для залежностей: моделі ворогів, стін і прикрас
	# вантажаться паралельно, на кількох ядрах телефона.
	var error := ResourceLoader.load_threaded_request(_path, "PackedScene", true)
	if error != OK:
		push_warning("Фонове завантаження не вдалося, вантажу напряму: %s" % _path)
		get_tree().change_scene_to_file(_path)
		_after_scene_change()
		return
	_state = State.LOADING

func _poll_loading() -> void:
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_set_progress(maxf(_shown_progress, float(progress[0]) * 0.8))
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(_path) as PackedScene
			_set_progress(0.85)
			get_tree().change_scene_to_packed(scene)
			_after_scene_change()
		_:
			push_warning("Не вдалося завантажити %s" % _path)
			get_tree().change_scene_to_file(_path)
			_after_scene_change()

func _after_scene_change() -> void:
	_frames_after_change = 0
	_state = State.WAITING_SCENE

func _set_progress(value: float) -> void:
	_shown_progress = value
	_bar.value = value * 100.0

# --- вигляд ---

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Екран завантаження ловить усі дотики: поки він на екрані, гравець
	# не має випадково натиснути щось у сцені під ним.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var background := ColorRect.new()
	background.color = UiTheme.BG_DARK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(520, 0)
	column.position = Vector2(-260, -90)
	column.add_theme_constant_override("separation", 18)
	_root.add_child(column)

	var game_label := Label.new()
	game_label.text = "RUNE HORDE"
	game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_label.add_theme_font_size_override("font_size", 22)
	game_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	column.add_child(game_label)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(_title_label)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.add_theme_stylebox_override("background", UiTheme.make_box(UiTheme.PANEL, 7))
	_bar.add_theme_stylebox_override("fill", UiTheme.make_box(UiTheme.ACCENT, 7))
	column.add_child(_bar)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	column.add_child(_hint_label)
