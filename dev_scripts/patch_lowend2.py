# -*- coding: utf-8 -*-
# Другий прохід оптимізації під слабкі телефони (Moto G32: 17-19 FPS у данжі).
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:80])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


# --- 1. Легкий рушій для телефонів ---
patch('project.godot', [
    ('''renderer/rendering_method="mobile"''',
     '''renderer/rendering_method="mobile"
renderer/rendering_method.mobile="gl_compatibility"'''),
])

# --- 2. Якість: без тіней у Compatibility, легший "Низький" профіль ---
patch('scripts/autoload/perf_settings.gd', [
    ('''		"max_fps": 30,
		"render_scale_max": 0.7,
		"render_scale_min": 0.5,
		"shadows": false,
		"lod_threshold": 4.0,
		"dungeon_lights": 2,
		"view_distance": 20.0,
		"decor_density": 0.45,
		"enemy_awake": 26.0,''',
     '''		"max_fps": 30,
		"render_scale_max": 0.65,
		"render_scale_min": 0.5,
		"shadows": false,
		"lod_threshold": 4.0,
		"dungeon_lights": 0,
		"view_distance": 20.0,
		"decor_density": 0.45,
		"enemy_awake": 22.0,'''),
    ('''func get_quality_title() -> String:
	return QUALITY_TITLES[quality]''',
     '''func get_quality_title() -> String:
	return QUALITY_TITLES[quality]

## Чи працює легкий рушій (OpenGL ES 3). На телефонах гра стартує саме в
## ньому: на слабких відеочипах він швидший за Vulkan у рази.
static func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"'''),
    ('''	var wanted: bool = light.get_meta(&"perf_shadow")
	light.shadow_enabled = wanted and get_value("shadows")''',
     '''	var wanted: bool = light.get_meta(&"perf_shadow")
	# У легкому рушії сонце з тінями малюється ще одним проходом поверх
	# уже освітленої сцени — світло подвоюється, трава стає кислотною. Тож
	# там тіні від сонця вимкнені: і правильні кольори, і дешевше.
	light.shadow_enabled = wanted and get_value("shadows") and not is_compatibility()'''),
])

# --- 3. Вороги: рух маршрутом без фізики ---
patch('scenes/dungeon/enemy_3d.gd', [
    ('''var _telegraph: MeshInstance3D
var _charging_shot: EnemyProjectile''',
     '''var _telegraph: MeshInstance3D
var _charging_shot: EnemyProjectile

## Стоїть на підлозі (після першого приземлення). Поки так, ворог, що
## йде маршрутом, рухається без фізики — див. _move().
var _grounded := false
var _path_step := false'''),
    ('''	# Стоїть без діла на підлозі — рухати нічого, фізику не рахуємо.
	if not _aggro and is_on_floor() and velocity.is_zero_approx() and _knockback.is_zero_approx():
		_play("Idle")
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0''',
     '''	# Стоїть без діла на підлозі — рухати нічого, фізику не рахуємо.
	if not _aggro and _grounded and velocity.is_zero_approx() and _knockback.is_zero_approx():
		_play("Idle")
		return

	if not _grounded:
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0'''),
    ('''	# Відкидання від удару героя накладається поверх власного руху лише
	# на цей крок. Власну швидкість потім повертаємо точно такою, якою
	# вона була: раніше після кроку віднімалось уже зменшене відкидання,
	# і залишок накопичувався — ворога "несло" на кілька метрів.
	var own_velocity := velocity
	velocity.x += _knockback.x
	velocity.z += _knockback.z
	move_and_slide()
	velocity.x = own_velocity.x
	velocity.z = own_velocity.z
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)''',
     '''	_move(delta)

## Рух ворога.
##
## move_and_slide() — найдорожча річ, яку ворог робить щокадру: кілька
## перевірок зіткнень фігурою. Але коли ворог іде МАРШРУТОМ, вона не
## потрібна: маршрут по карті прохідності вже обходить стіни з запасом.
## Тож такий ворог просто зсувається вздовж маршруту. Повна фізика
## лишається там, де без неї не можна: падіння на старті, відкидання від
## удару, відхід стрільця (він іде не маршрутом, а геть від героя).
##
## Відкидання накладається лише на цей крок, а власна швидкість потім
## повертається точно такою, якою була, — інакше залишок накопичувався б.
func _move(delta: float) -> void:
	var has_knockback := not _knockback.is_zero_approx()
	var moving := not Vector2(velocity.x, velocity.z).is_zero_approx()
	if _grounded and not has_knockback and _path_step:
		global_position.x += velocity.x * delta
		global_position.z += velocity.z * delta
	elif has_knockback or moving or not _grounded:
		var own_velocity := velocity
		velocity.x += _knockback.x
		velocity.z += _knockback.z
		move_and_slide()
		_grounded = is_on_floor()
		velocity.x = own_velocity.x
		velocity.z = own_velocity.z
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	_path_step = false'''),
    ('''	velocity.x = move_toward(velocity.x, direction.x * move_speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 12.0 * delta)
	_face(direction, 10.0)
	_play("Walk")''',
     '''	velocity.x = move_toward(velocity.x, direction.x * move_speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 12.0 * delta)
	_path_step = true
	_face(direction, 10.0)
	_play("Walk")'''),
])

# --- 4. Данж: усі шматки й "прогрів" графіки під екраном завантаження ---
patch('scenes/dungeon/dungeon.gd', [
    ('''	level_root.bake_navigation_mesh(true)
	while _build_next_visible_chunk():
		await get_tree().process_frame
	_update_streaming()
	if level_root.is_baking():
		await level_root.bake_finished

	_spawn_enemies(markers)
	_update_streaming()
	SceneLoader.release()''',
     '''	level_root.bake_navigation_mesh(true)
	# Збираємо ВСІ шматки одразу, по одному за кадр, поки гравець дивиться
	# на смужку завантаження. На слабкому телефоні збирання шматка посеред
	# гри давало ривок щоразу, як герой заходив у нову залу; тепер під
	# час гри шматки лише ховаються й показуються — це безкоштовно.
	while _build_next_chunk():
		await get_tree().process_frame
	_update_streaming()
	if level_root.is_baking():
		await level_root.bake_finished

	_spawn_enemies(markers)
	await _warm_up_rendering()
	_update_streaming()
	SceneLoader.release()'''),
    ('''## Під час завантаження: будує найближчий ще не збудований шматок, який
## опиниться в кадрі. Повертає false, коли таких не лишилось.
func _build_next_visible_chunk() -> bool:
	var origin := player.global_position
	var view_distance: float = PerfSettings.get_value("view_distance")
	for chunk: Dictionary in _chunks:
		if not chunk.built and _distance_to_chunk(origin, chunk) < view_distance:
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"))
			chunk.node.visible = true
			return true
	return false''',
     '''## Під час завантаження: будує наступний ще не збудований шматок.
## Повертає false, коли всі зібрані.
func _build_next_chunk() -> bool:
	for chunk: Dictionary in _chunks:
		if not chunk.built:
			DungeonBuilder.build_chunk(_map_rows, chunk, PerfSettings.get_value("decor_density"))
			return true
	return false

## ПРОГРІВ ГРАФІКИ.
##
## Відеочип готує програму малювання (шейдер) для кожного виду об'єкта
## тоді, коли вперше бачить його в кадрі. На слабкому телефоні це
## десяті частки секунди — саме такі "зависання" бували на першому ударі,
## першому снаряді, першій зустрічі з босом.
##
## Тож поки на екрані смужка завантаження, ми на кілька кадрів ставимо
## перед камерою по одному зразку всього, що з'явиться в данжі: кожного
## ворога, боса, двері виходу, всі прикраси, всі ефекти бою. Гравець
## цього не бачить (екран завантаження зверху), а шейдери вже готові.
func _warm_up_rendering() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var center := player.global_position + Vector3(0, 1.0, 0)
	var models: Array = MELEE_MODELS.duplicate()
	models.append_array([RANGED_MODEL, BOSS_MODEL, EXIT_SCENE])
	var step := 0
	for scene: PackedScene in models:
		var model: Node3D = scene.instantiate()
		holder.add_child(model)
		model.global_position = center + Vector3((step % 3 - 1) * 0.6, -0.8, (step / 3) * 0.6)
		model.scale = Vector3.ONE * 0.3
		step += 1
		CombatVfx.flash_model(model, Color.WHITE, 0.5)

	# Прикраси малюються пакетами (MultiMesh) — у пакета свій варіант
	# шейдера, тож і прогріваємо пакетом.
	var batcher := MeshBatcher.new()
	for scene: PackedScene in DungeonBuilder.all_decor_scenes():
		batcher.add(scene, Transform3D(Basis().scaled(Vector3.ONE * 0.3), center + Vector3(0, -0.8, 0)))
	batcher.flush(holder)

	CombatVfx.slash(holder, center, 0.0, 2.0, 150.0, Color(0.72, 0.87, 1.0), false, 0.0, 0.5)
	CombatVfx.impact(holder, center, Color(1.0, 0.65, 0.25), true)
	CombatVfx.damage_number(holder, center, 12.0, true)
	CombatVfx.shockwave(holder, center, 1.5, Color(0.35, 0.95, 1.0), 0.5)
	var marker := CombatVfx.make_ground_marker(Color(1.0, 0.22, 0.15, 0.85), 1.0, 1.0)
	holder.add_child(marker)
	marker.global_position = center - Vector3(0, 0.9, 0)
	var shot := EnemyProjectile.create(0.0)
	holder.add_child(shot)
	shot.global_position = center
	var bar: HealthBar3D = HealthBar3D.new()
	holder.add_child(bar)
	bar.setup(Color(0.95, 0.25, 0.25), 0.5, true)
	bar.global_position = center

	for i in 4:
		await get_tree().process_frame
	holder.queue_free()'''),
])

# Список усіх прикрас данжу — для прогріву.
patch('scenes/dungeon/dungeon_builder.gd', [
    ('''## Символи, по яких можна ходити.''',
     '''## Усі моделі, з яких збирається данж (для прогріву графіки).
static func all_decor_scenes() -> Array:
	var scenes: Array = [FLOOR_SCENE, FLOOR_BRICKS_SCENE, WALL_SCENE, TORCH_SCENE, COLUMN_SCENE]
	for group: Array in [CLUTTER_SCENES, WALL_DECOR_SCENES, FURNITURE_SCENES, TREASURE_SCENES, TRAP_SCENES]:
		scenes.append_array(group)
	return scenes

## Символи, по яких можна ходити.'''),
])
