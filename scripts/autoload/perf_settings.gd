extends Node

## Якість графіки й непомітне підлаштування під телефон.
##
## Головна ідея: гра сама з'ясовує, на що здатен телефон, і тихо
## підкручує картинку так, щоб кадри йшли рівно. Гравець нічого не
## налаштовує — він просто бачить, що гра не гальмує.
##
## Працює в три шари, від непомітного до помітного:
##
##  1. ДИНАМІЧНА РОЗДІЛЬНІСТЬ. Щосекунди міряємо, скільки коштує кадр.
##     Не встигаємо — 3D малюється в трохи меншій роздільності (інтерфейс
##     лишається різким). Є запас — роздільність тихо повертається.
##     На щільному екрані телефона зміну на 10-20% оком не видно.
##
##  2. РІВНІ ЯКОСТІ (низька / середня / висока). Якщо навіть на мінімальній
##     роздільності кадри не встигають, гра сама опускає рівень: менше
##     світла, без тіней, ближча дальність промальовки, 30 кадрів замість
##     60 — зате рівних, без ривків. Вибір запам'ятовується для телефона.
##
##  3. ВИБІР ГРАВЦЯ. У меню можна примусово поставити рівень або лишити
##     "Авто". На ПК це ще й спосіб побачити, як гра виглядає на слабкому
##     телефоні, не встановлюючи її.
##
## Геймплей на всіх рівнях однаковий: ті самі вороги, та сама шкода.
## Міняється лише картинка й те, як часто рахуються речі, яких гравець
## не помічає (наприклад, анімація ворога за спиною камери).

signal quality_changed(quality: int)

enum Quality {LOW, MEDIUM, HIGH}

const QUALITY_TITLES := ["Низька", "Середня", "Висока"]

## Налаштування пристрою зберігаються окремо від прогресу гри: якість
## графіки належить телефону, а не гравцеві, і не має переїжджати
## разом зі збереженням на інший пристрій.
const SETTINGS_PATH := "user://settings.cfg"

## Що міняє кожен рівень якості.
##   max_fps          — стеля кадрів. Рівні 30 приємніші за "плаваючі"
##                      40-55, і телефон гріється вдвічі менше.
##   render_scale_*   — межі динамічної роздільності 3D.
##   shadows          — тіні від сонця на острові.
##   lod_threshold    — наскільки охоче далекі моделі спрощуються.
##   dungeon_lights   — скільки найближчих смолоскипів справді світять.
##   view_distance    — на якій відстані від краю шматок данжу ховається.
##   decor_density    — частка дрібних прикрас (бочки, павутиння).
##   enemy_awake      — далі за цю відстань ворог спить.
##   arena_max_enemies — скільки ворогів засідки живуть одночасно (решта
##                      хвилі чекає черги).
##   horde_size       — скільки дрібноти в орді засідки.
const PROFILES := {
	Quality.LOW: {
		"max_fps": 30,
		"render_scale_max": 0.65,
		"render_scale_min": 0.5,
		"shadows": false,
		"lod_threshold": 4.0,
		"dungeon_lights": 0,
		"view_distance": 20.0,
		"decor_density": 0.45,
		"enemy_awake": 22.0,
		"arena_max_enemies": 9,
		"horde_size": 4,
	},
	Quality.MEDIUM: {
		"max_fps": 60,
		"render_scale_max": 0.8,
		"render_scale_min": 0.55,
		"shadows": true,
		"lod_threshold": 2.0,
		"dungeon_lights": 4,
		"view_distance": 24.0,
		"decor_density": 0.8,
		"enemy_awake": 30.0,
		"arena_max_enemies": 12,
		"horde_size": 5,
	},
	Quality.HIGH: {
		"max_fps": 60,
		"render_scale_max": 1.0,
		"render_scale_min": 0.7,
		"shadows": true,
		"lod_threshold": 1.0,
		"dungeon_lights": 6,
		"view_distance": 30.0,
		"decor_density": 1.0,
		"enemy_awake": 34.0,
		"arena_max_enemies": 15,
		"horde_size": 6,
	},
}

## Динамічна роздільність: крок униз більший за крок угору. Коли
## гальмує — треба рятувати швидко; коли є запас — повертатись обережно,
## щоб не "гойдатись" туди-сюди.
const SCALE_STEP_DOWN := 0.07
const SCALE_STEP_UP := 0.04

## Скільки секунд поспіль має гальмувати на мінімальній роздільності,
## перш ніж гра опустить рівень якості.
const DOWNGRADE_AFTER_SEC := 6
## Скільки секунд поспіль має бути великий запас, щоб наступного разу
## (при переході між локаціями) спробувати рівень вище.
const UPGRADE_AFTER_SEC := 20
## Після переходу на іншу сцену перші секунди не міряємо: там
## завантаження, і кадри нерівні не через слабкий телефон.
const SETTLE_AFTER_SCENE_SEC := 2.5

var quality: int = Quality.MEDIUM
var auto_quality := true
var show_fps := false

## Тести вимикають збереження, щоб їхні експерименти з якістю не
## лишались у налаштуваннях справжньої гри.
var persist_settings := true

var _render_scale := 1.0
var _adaptive := false
var _gpu_timing_ready := false

# Лічильники вікна вимірювання (одна секунда).
var _window_time := 0.0
var _window_frames := 0
var _window_cost_ms := 0.0
var _window_gpu_ms := 0.0
var _window_worst_frame := 0.0

var _struggle_seconds := 0
var _comfort_seconds := 0
var _upscale_wait := 3
var _just_upscaled := false
var _settle_left := 0.0
var _last_scene: Node
var _headroom := false
var _upgrade_blocked := false

var _fps_layer: CanvasLayer
var _fps_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_adaptive = OS.has_feature("mobile")
	_load_settings()
	_apply_static_settings()
	apply_quality(quality, false)
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_set_fps_visible(show_fps)

# --- публічне ---

## Значення з профілю поточного рівня, наприклад "dungeon_lights".
func get_value(key: String) -> Variant:
	return PROFILES[quality][key]

func get_quality_title() -> String:
	return QUALITY_TITLES[quality]

## Чи працює легкий рушій (OpenGL ES 3). На телефонах гра стартує саме в
## ньому: на слабких відеочипах він швидший за Vulkan у рази.
static func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"

## Вибір у меню: -1 = "Авто", інакше конкретний рівень.
func set_user_choice(choice: int) -> void:
	auto_quality = choice < 0
	if not auto_quality:
		apply_quality(choice)
	else:
		_upgrade_blocked = false
	_save_settings()

func set_show_fps(enabled: bool) -> void:
	show_fps = enabled
	_set_fps_visible(enabled)
	_save_settings()

func apply_quality(level: int, save: bool = true) -> void:
	quality = clampi(level, Quality.LOW, Quality.HIGH)
	var profile: Dictionary = PROFILES[quality]
	Engine.max_fps = profile.max_fps
	# Фізика рахується стільки ж разів, скільки малюються кадри: тоді
	# рух плавний без додаткових хитрощів, а на "низькій" процесор
	# рахує фізику вдвічі рідше.
	Engine.physics_ticks_per_second = profile.max_fps
	_render_scale = profile.render_scale_max
	_apply_render_scale()
	get_tree().root.mesh_lod_threshold = profile.lod_threshold
	for light in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		_apply_sun(light as DirectionalLight3D)
	for world in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_apply_environment(world as WorldEnvironment)
	_struggle_seconds = 0
	_comfort_seconds = 0
	quality_changed.emit(quality)
	if save:
		_save_settings()

# --- що не залежить від рівня ---

func _apply_static_settings() -> void:
	# Якщо телефон не встигає, Godot намагається "наздогнати" фізику,
	# рахуючи по кілька кроків за кадр, — від цього кадр стає ще довшим,
	# і гра валиться в прірву. Обмежуємо наздоганяння: краще гра на мить
	# сповільниться, ніж зависне.
	Engine.max_physics_steps_per_frame = 3
	if not OS.has_feature("mobile"):
		return
	var root := get_tree().root
	# Згладжування на телефоні коштує помітно, а на щільному екрані його
	# майже не видно.
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	root.use_taa = false
	root.positional_shadow_atlas_size = 1024
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR

func _apply_render_scale() -> void:
	get_tree().root.scaling_3d_scale = _render_scale

# --- підлаштування об'єктів сцени ---

## Кожен новий вузол сцени проходить тут. Так налаштування діють і на
## те, що ви розставите в редакторі самі: нове сонце на острові одразу
## отримає тіні під рівень телефона.
func _on_node_added(node: Node) -> void:
	if node is DirectionalLight3D:
		_apply_sun(node as DirectionalLight3D)
	elif node is WorldEnvironment:
		_apply_environment(node as WorldEnvironment)

func _apply_sun(light: DirectionalLight3D) -> void:
	# Запам'ятовуємо, чи задумані тіні автором сцени, щоб при підвищенні
	# якості повернути саме задумане, а не вмикати їх усюди.
	if not light.has_meta(&"perf_shadow"):
		light.set_meta(&"perf_shadow", light.shadow_enabled)
	var wanted: bool = light.get_meta(&"perf_shadow")
	# У легкому рушії сонце з тінями малюється ще одним проходом поверх
	# уже освітленої сцени — світло подвоюється, трава стає кислотною. Тож
	# там тіні від сонця вимкнені: і правильні кольори, і дешевше.
	light.shadow_enabled = wanted and get_value("shadows") and not is_compatibility()
	if quality == Quality.HIGH:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		light.directional_shadow_max_distance = 50.0
	else:
		# Одна карта тіні замість чотирьох: камера дивиться згори на
		# невеликий шматок світу, розбиття на зони тут нічого не дає.
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		light.directional_shadow_max_distance = 30.0

## Сяйво й об'ємний туман — найдорожчі ефекти оточення. На низькій
## вимикаємо, на вищих повертаємо те, що задумав автор сцени.
func _apply_environment(world: WorldEnvironment) -> void:
	var environment := world.environment
	if environment == null:
		return
	if not environment.has_meta(&"perf_glow"):
		environment.set_meta(&"perf_glow", environment.glow_enabled)
		environment.set_meta(&"perf_volumetric", environment.volumetric_fog_enabled)
	var low := quality == Quality.LOW
	environment.glow_enabled = environment.get_meta(&"perf_glow") and not low
	environment.volumetric_fog_enabled = environment.get_meta(&"perf_volumetric") and not low

# --- визначення телефона ---

## Перший запуск: оцінюємо телефон за пам'яттю й відеочипом. Помилка не
## страшна — динамічне підлаштування виправить її за кілька секунд гри.
func _detect_quality() -> int:
	if not OS.has_feature("mobile"):
		return Quality.HIGH
	var memory_gb := float(OS.get_memory_info().get("physical", 0)) / 1073741824.0
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var weak_gpu := false
	for marker in ["mali-t", "mali-g5", "mali-g31", "mali-g51", "mali-g52", "mali-g57",
			"adreno (tm) 5", "adreno (tm) 610", "adreno (tm) 612", "adreno (tm) 613",
			"adreno (tm) 618", "powervr", "img bxm"]:
		if gpu.contains(marker):
			weak_gpu = true
	if weak_gpu or (memory_gb > 0.0 and memory_gb <= 4.5) or OS.get_processor_count() < 8:
		return Quality.LOW
	if memory_gb > 0.0 and memory_gb < 7.5:
		return Quality.MEDIUM
	return Quality.HIGH

# --- вимірювання ---

func _process(delta: float) -> void:
	if _fps_label != null and _fps_layer.visible:
		_fps_label.text = "%d FPS  •  %s  •  %d%%" % [
			Engine.get_frames_per_second(), get_quality_title(), roundi(_render_scale * 100.0)]

	if get_tree().current_scene != _last_scene:
		_on_scene_changed()
	if not _adaptive:
		return
	if _settle_left > 0.0:
		_settle_left -= delta
		return
	# Міряємо лише справжню гру: 3D-сцену, не паузу й не меню.
	if get_tree().paused or get_viewport().get_camera_3d() == null:
		_reset_window()
		return

	_window_time += delta
	_window_frames += 1
	_window_worst_frame = maxf(_window_worst_frame, delta)
	var rid := get_viewport().get_viewport_rid()
	var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(rid) \
		+ RenderingServer.get_frame_setup_time_cpu() \
		+ (Performance.get_monitor(Performance.TIME_PROCESS)
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	if gpu_ms > 0.0:
		_gpu_timing_ready = true
	_window_gpu_ms += gpu_ms
	_window_cost_ms += maxf(gpu_ms, cpu_ms)

	if _window_time >= 1.0:
		_evaluate_window()
		_reset_window()

func _reset_window() -> void:
	_window_time = 0.0
	_window_frames = 0
	_window_cost_ms = 0.0
	_window_gpu_ms = 0.0
	_window_worst_frame = 0.0

## Раз на секунду вирішуємо: гальмує, є запас чи все добре.
func _evaluate_window() -> void:
	# Секунда з кадром довшим за чверть секунди — це завантаження чи
	# збирання сміття, а не слабкий телефон. Не рахуємо її.
	if _window_worst_frame > 0.25 or _window_frames == 0:
		return
	var profile: Dictionary = PROFILES[quality]
	var target_fps: float = profile.max_fps
	var budget_ms := 1000.0 / target_fps
	var fps := _window_frames / _window_time
	var cost_ms := _window_cost_ms / _window_frames
	var gpu_ms := _window_gpu_ms / _window_frames

	if fps < target_fps * 0.88:
		_on_struggling(profile, budget_ms, gpu_ms)
	elif fps >= target_fps * 0.96:
		_on_comfortable(profile, cost_ms, gpu_ms, budget_ms)
	else:
		_struggle_seconds = 0
		_comfort_seconds = 0

func _on_struggling(profile: Dictionary, budget_ms: float, gpu_ms: float) -> void:
	_struggle_seconds += 1
	_comfort_seconds = 0
	# Щойно підняли роздільність і одразу загальмувало — наступного разу
	# чекаємо довше: цей телефон живе на межі.
	if _just_upscaled:
		_upscale_wait = mini(_upscale_wait * 2, 60)
	_just_upscaled = false

	# Зменшувати роздільність має сенс, лише коли не встигає відеочип.
	# Якщо не встигає процесор, менша картинка не допоможе.
	var gpu_bound := not _gpu_timing_ready or gpu_ms > budget_ms * 0.65
	if gpu_bound and _render_scale > profile.render_scale_min + 0.001:
		_render_scale = maxf(_render_scale - SCALE_STEP_DOWN, profile.render_scale_min)
		_apply_render_scale()
		return
	if auto_quality and quality > Quality.LOW and _struggle_seconds >= DOWNGRADE_AFTER_SEC:
		_upgrade_blocked = true
		apply_quality(quality - 1)

func _on_comfortable(profile: Dictionary, cost_ms: float, gpu_ms: float, budget_ms: float) -> void:
	_struggle_seconds = 0
	_comfort_seconds += 1
	_just_upscaled = false
	if _render_scale < profile.render_scale_max - 0.001:
		if _comfort_seconds >= _upscale_wait and (not _gpu_timing_ready or gpu_ms < budget_ms * 0.7):
			_render_scale = minf(_render_scale + SCALE_STEP_UP, profile.render_scale_max)
			_apply_render_scale()
			_comfort_seconds = 0
			_just_upscaled = true
		return
	# Повна роздільність і великий запас: наступний рівень може потягти.
	# Перевіряємо чесно — вистачить  ЙОГО бюджету кадру, а не поточного.
	if not auto_quality or _upgrade_blocked or quality >= Quality.HIGH or not _gpu_timing_ready:
		return
	var next_budget := 1000.0 / float(PROFILES[quality + 1].max_fps)
	if cost_ms < next_budget * 0.6 and _comfort_seconds >= UPGRADE_AFTER_SEC:
		_headroom = true

## Підвищуємо якість лише між локаціями, а не посеред бою: зміна
## картинки на очах гравця — саме те, чого ми уникаємо.
func _on_scene_changed() -> void:
	_last_scene = get_tree().current_scene
	_settle_left = SETTLE_AFTER_SCENE_SEC
	_reset_window()
	if _headroom:
		_headroom = false
		apply_quality(quality + 1)

# --- лічильник кадрів ---

func _set_fps_visible(enabled: bool) -> void:
	if enabled and _fps_layer == null:
		_fps_layer = CanvasLayer.new()
		_fps_layer.layer = 120
		_fps_label = Label.new()
		# Угорі посередині: ліворуч золото, праворуч кнопка меню, унизу
		# джойстик — а тут лічильник нічому не заважає.
		_fps_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_fps_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fps_label.position.y = 2
		_fps_label.add_theme_font_size_override("font_size", 16)
		_fps_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_fps_label.add_theme_constant_override("outline_size", 4)
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fps_layer.add_child(_fps_label)
		add_child(_fps_layer)
	if _fps_layer != null:
		_fps_layer.visible = enabled

# --- збереження ---

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		quality = _detect_quality()
		auto_quality = true
		_save_settings()
		return
	auto_quality = config.get_value("graphics", "auto", true)
	quality = config.get_value("graphics", "quality", _detect_quality())
	show_fps = config.get_value("graphics", "show_fps", false)

func _save_settings() -> void:
	if not persist_settings:
		return
	var config := ConfigFile.new()
	config.set_value("graphics", "auto", auto_quality)
	config.set_value("graphics", "quality", quality)
	config.set_value("graphics", "show_fps", show_fps)
	config.save(SETTINGS_PATH)
