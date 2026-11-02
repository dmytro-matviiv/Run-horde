# -*- coding: utf-8 -*-
import os
os.chdir(r'D:\Claude code\idle survivor_like')
path = 'scenes/dungeon/dungeon.gd'
s = open(path, encoding='utf-8').read()


def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b, 1)


rep('''## ПОТОКОВЕ ПІДВАНТАЖЕННЯ
##
## Данж ріжеться на шматки (див. DungeonBuilder). Тут вирішується, який
## шматок збудувати, а який сховати:
##   BUILD_DISTANCE — на цій відстані шматок починають будувати, щоб
##     гравець підійшов уже до готового;
##   HIDE_DISTANCE  — далі за це шматок ховається з очей, бо малювати
##     кімнати за три повороти звідси немає сенсу.
## Перевіряємо не щокадру, а раз на STREAM_INTERVAL — цього вистачає,
## бо герой не встигає пробігти шматок за чверть секунди.
const BUILD_DISTANCE := 46.0
const HIDE_DISTANCE := 38.0
const STREAM_INTERVAL := 0.25

## Ворог далі за цю відстань не думає й не ворушить скелетом: він просто
## чекає. На телефоні саме анімація скелетів з'їдає найбільше часу.
const ENEMY_SLEEP_DISTANCE := 32.0
''',
'''## ПОТОКОВЕ ПІДВАНТАЖЕННЯ
##
## Данж ріжеться на шматки (див. DungeonBuilder). Тут вирішується, який
## шматок збудувати, а який сховати. Відстані залежать від якості
## графіки (PerfSettings): на слабкому телефоні видно трохи ближче, але
## завжди далі, ніж захоплює камера, тож "дірок" гравець не бачить.
##   view_distance        — далі за це (від краю шматка) шматок ховається;
##   + BUILD_AHEAD         — на цій відстані шматок починають будувати,
##                           щоб гравець підійшов уже до готового.
## Перевіряємо не щокадру, а раз на STREAM_INTERVAL — цього вистачає,
## бо герой не встигає пробігти шматок за чверть секунди.
const BUILD_AHEAD := 12.0
const STREAM_INTERVAL := 0.25

## Вороги ближче за це анімуються щокадру, далі — через кадр: на такій
## відстані різниці не видно, а скелетна анімація найдорожча на телефоні.
const ENEMY_FULL_DETAIL_DISTANCE := 13.0
''')

rep('''func _ready() -> void:
	_level_index = GameState.dungeon_level
	var level := DungeonLevels.get_level(_level_index)
	_map_rows = level.map
	var markers := DungeonBuilder.build_base(level.map, level_root)
	_chunks = markers.chunks
	_lights = markers.lights

	player.global_position = markers.start + Vector3(0, 0.2, 0)
	_exit_position = markers.exit
	# Найближчі шматки будуємо одразу, решту — коли гравець підійде.
	_update_streaming(true)

	# Карту прохідності печемо ПІСЛЯ того, як рівень зібрано: інакше
	# ворогам не буде по чому рахувати маршрут.
	level_root.bake_navigation_mesh(false)
	await get_tree().physics_frame

	_spawn_enemies(markers)
	_setup_hud(level.title)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)

	# Вхідна кімната порожня, і перше, що робить гравець, — обирає
	# здібність. Далі вибір повторюється з кожним новим рівнем.
	await _offer_ability()''',
'''## Збирання рівня розкладене на кілька кадрів і сховане за екраном
## завантаження (SceneLoader.hold): гравець бачить плавну смужку, а не
## застиглий екран. Карта прохідності печеться в окремому потоці.
func _ready() -> void:
	SceneLoader.hold()
	_level_index = GameState.dungeon_level
	var level := DungeonLevels.get_level(_level_index)
	_map_rows = level.map
	var markers := DungeonBuilder.build_base(level.map, level_root)
	_chunks = markers.chunks
	_lights = markers.lights

	player.global_position = markers.start + Vector3(0, 0.2, 0)
	_exit_position = markers.exit
	_setup_hud(level.title)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	PerfSettings.quality_changed.connect(_on_quality_changed)

	# Карту прохідності печемо ПІСЛЯ того, як перешкоди створено: інакше
	# ворогам не буде по чому рахувати маршрут. Печеться у фоні — тим
	# часом по одному шматку за кадр збираємо найближчі зали.
	level_root.bake_navigation_mesh(true)
	while _build_next_visible_chunk():
		await get_tree().process_frame
	_update_streaming()
	if level_root.is_baking():
		await level_root.bake_finished

	_spawn_enemies(markers)
	_update_streaming()
	SceneLoader.release()

	# Вхідна кімната порожня, і перше, що робить гравець, — обирає
	# здібність. Далі вибір повторюється з кожним новим рівнем.
	await _offer_ability()''')

rep('''func _process(delta: float) -> void:
	_stream_left -= delta
	if _stream_left <= 0.0:
		_stream_left = STREAM_INTERVAL
		_update_streaming(false)
''',
'''func _process(delta: float) -> void:
	_stream_left -= delta
	if _stream_left <= 0.0:
		_stream_left = STREAM_INTERVAL
		_update_streaming()
''')

rep('''## Будує те, що попереду, ховає те, що позаду, і присипляє далеких
## ворогів. Гравець цього не помічає: він просто йде коридором.
func _update_streaming(immediate: bool) -> void:
	var origin := player.global_position
	for chunk: Dictionary in _chunks:
		var distance := origin.distance_to(chunk.center)
		if distance < BUILD_DISTANCE and not chunk.built:
			DungeonBuilder.build_chunk(_map_rows, chunk)
			if not immediate:
				# За раз будуємо лише один шматок: так навіть найповільніший
				# телефон не отримає ривка посеред бігу.
				chunk.node.visible = true
				break
		chunk.node.visible = chunk.built and distance < HIDE_DISTANCE

	# Далекі смолоскипи гасимо: кожне увімкнене джерело світла коштує.
	for light: OmniLight3D in _lights:
		light.visible = origin.distance_to(light.global_position) < HIDE_DISTANCE

	for enemy in enemies_root.get_children():
		if enemy is Enemy3D:
			(enemy as Enemy3D).set_sleeping(origin.distance_to(enemy.global_position) > ENEMY_SLEEP_DISTANCE)''',
'''## Будує те, що попереду, ховає те, що позаду, і присипляє далеких
## ворогів. Гравець цього не помічає: він просто йде коридором.
func _update_streaming() -> void:
	var origin := player.global_position
	var view_distance: float = PerfSettings.get_value("view_distance")
	var built_one := false
	for chunk: Dictionary in _chunks:
		var distance := _distance_to_chunk(origin, chunk)
		if not chunk.built and distance < view_distance + BUILD_AHEAD and not built_one:
			# За раз будуємо лише один шматок: так навіть найповільніший
			# телефон не отримає ривка посеред бігу.
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"))
			built_one = true
		chunk.node.visible = chunk.built and distance < view_distance

	_update_lights(origin, view_distance)
	_update_enemies(origin)

## Під час завантаження: будує найближчий ще не збудований шматок, який
## опиниться в кадрі. Повертає false, коли таких не лишилось.
func _build_next_visible_chunk() -> bool:
	var origin := player.global_position
	var view_distance: float = PerfSettings.get_value("view_distance")
	for chunk: Dictionary in _chunks:
		if not chunk.built and _distance_to_chunk(origin, chunk) < view_distance:
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"))
			chunk.node.visible = true
			return true
	return false

## Відстань від героя до найближчої точки шматка на площині.
func _distance_to_chunk(origin: Vector3, chunk: Dictionary) -> float:
	var bounds: Rect2 = chunk.bounds
	var point := Vector2(origin.x, origin.z)
	var closest := point.clamp(bounds.position, bounds.end)
	return point.distance_to(closest)

## Світять лише кілька НАЙБЛИЖЧИХ смолоскипів — скільки саме, вирішує
## якість графіки. Кожне увімкнене джерело світла телефон рахує для
## кожного пікселя, тож далекі гасимо: гравець їх однаково не бачить.
func _update_lights(origin: Vector3, view_distance: float) -> void:
	var allowed: int = PerfSettings.get_value("dungeon_lights")
	var by_distance := _lights.duplicate()
	by_distance.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	for i in by_distance.size():
		var light: OmniLight3D = by_distance[i]
		light.visible = i < allowed and origin.distance_to(light.global_position) < view_distance + 10.0

## Далекі вороги сплять, середні анімуються рідше, близькі — щокадру.
func _update_enemies(origin: Vector3) -> void:
	var awake_distance: float = PerfSettings.get_value("enemy_awake")
	for enemy in enemies_root.get_children():
		if not enemy is Enemy3D:
			continue
		var distance := origin.distance_to((enemy as Node3D).global_position)
		(enemy as Enemy3D).set_sleeping(distance > awake_distance)
		(enemy as Enemy3D).set_animation_step(1 if distance < ENEMY_FULL_DETAIL_DISTANCE else 2)

## Якість змінилась (гравець у меню або автоматика) — одразу
## перераховуємо світло й дальність, не чекаючи наступної перевірки.
func _on_quality_changed(_quality: int) -> void:
	_update_streaming()''')

rep('''## Герой загинув — це має бути видно, а не виглядати як "застряг".
func _on_player_died() -> void:
	status_label.text = "Ви загинули. Повертаємось на базу…"
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/world/base_island.tscn")''',
'''## Герой загинув — це має бути видно, а не виглядати як "застряг".
func _on_player_died() -> void:
	status_label.text = "Ви загинули. Повертаємось на базу…"
	await get_tree().create_timer(2.0).timeout
	SceneLoader.change_scene(BASE_SCENE_PATH, "База")''')

rep('''func _on_exit_pressed() -> void:
	# Пройшов данж — наступний рівень стає доступним.
	GameState.unlock_next_dungeon_level()
	get_tree().change_scene_to_file("res://scenes/world/base_island.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		player.attack()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/world/base_island.tscn")''',
'''func _on_exit_pressed() -> void:
	# Пройшов данж — наступний рівень стає доступним.
	GameState.unlock_next_dungeon_level()
	SceneLoader.change_scene(BASE_SCENE_PATH, "База")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		player.attack()
	elif event.is_action_pressed("ui_cancel"):
		SceneLoader.change_scene(BASE_SCENE_PATH, "База")''')

rep('''## Скільки досвіду треба на наступний рівень героя в данжі.''',
'''const BASE_SCENE_PATH := "res://scenes/world/base_island.tscn"

## Скільки досвіду треба на наступний рівень героя в данжі.''')

open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('dungeon ok')

# --- Острів і меню теж переходять через екран завантаження ---
path = 'scenes/world/base_island.gd'
s = open(path, encoding='utf-8').read()
rep('''	var path: String = ACTION_SCENES.get(_nearby.action, "")
	if path != "":
		get_tree().change_scene_to_file(path)''',
'''	var path: String = ACTION_SCENES.get(_nearby.action, "")
	if path == "":
		return
	# У данж — через екран завантаження: це найважча сцена гри, і на
	# слабкому телефоні пряме завантаження "заморожувало" екран.
	if _nearby.action == "portal":
		SceneLoader.change_scene(path, "Забуті склепи")
	else:
		get_tree().change_scene_to_file(path)''')
open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('island ok')

path = 'scenes/ui/main_menu.gd'
s = open(path, encoding='utf-8').read()
rep('''func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world/base_island.tscn")''',
'''func _on_play_pressed() -> void:
	SceneLoader.change_scene("res://scenes/world/base_island.tscn", "База")''')
open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('menu ok')

# --- Реєстрація завантажувача ---
path = 'project.godot'
s = open(path, encoding='utf-8').read()
rep('''PerfSettings="*res://scripts/autoload/perf_settings.gd"''',
'''PerfSettings="*res://scripts/autoload/perf_settings.gd"
SceneLoader="*res://scripts/autoload/scene_loader.gd"''')
open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('project ok')

# --- Карта прохідності: клітинка як у карти навігації (без попереджень,
# --- і печеться швидше), фон — простий колір замість неба.
path = 'scenes/dungeon/dungeon.tscn'
s = open(path, encoding='utf-8').read()
rep('''cell_size = 0.2
cell_height = 0.2
agent_height = 1.8
agent_radius = 0.55
agent_max_climb = 0.35''',
'''cell_size = 0.25
cell_height = 0.25
agent_height = 1.8
agent_radius = 0.5
agent_max_climb = 0.5''')
rep('''[sub_resource type="Environment" id="Environment_dungeon"]
background_mode = 2
sky = SubResource("Sky_dark")''',
'''[sub_resource type="Environment" id="Environment_dungeon"]
background_color = Color(0.035, 0.03, 0.05, 1)''')
open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('tscn ok')
