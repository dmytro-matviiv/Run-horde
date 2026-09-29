extends Node

## Перевірка повернення з будівлі: герой підходить до Зали героїв,
## Збройні й Храму, заходить, міняє героя чи зброю, виходить — і має
## стояти там само й вільно ходити. Колись його ставило в центр зони
## будівлі, де стояла невидима брила від напису, — і герой застрягав.
##   godot --path . res://tools/town_return_probe.tscn
## Пише рядки "PROBE ..." і в кінці "RESULT: OK" або "RESULT: FAIL".

const TOWN := "res://scenes/world/base_island.tscn"
## Скільки герой має пройти за пів секунди, щоб вважати, що він не застряг.
## Застряглий проходив 0,00 м; вільний — 1,2-1,8 м (з центру зали один бік
## упирається в стіну будівлі).
const MIN_STEP := 0.4

var _failed := false

func _ready() -> void:
	# Сама сцена-перевірка зникне при першій зміні сцени — тож працює її
	# копія, повішена на корінь дерева.
	if get_tree().current_scene == self:
		get_tree().root.add_child.call_deferred(get_script().new())
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	PerfSettings.persist_settings = false
	get_tree().change_scene_to_file(TOWN)
	await _wait_for_scene(TOWN)
	# Зала героїв: стоїмо з боку площі, біля краю зони; обираємо іншого героя.
	await _visit("HeroesHallZone", Vector3(3.0, 0, 0), func(screen: Node) -> void:
		screen.call("_on_slot_pressed", 1)
		screen.call("_on_action_pressed"))
	# Збройня: споряджаємо іншу зброю.
	await _visit("ArmoryZone", Vector3(2.2, 0, -2.0), func(_screen: Node) -> void:
		var hero: StringName = GameState.selected_hero_id
		var weapons: Array = WeaponPool.get_for_hero(hero)
		var other: WeaponDef = weapons[1] if weapons.size() > 1 else weapons[0]
		if not GameState.is_weapon_owned(other.id):
			GameState.buy_weapon(other.id)
		GameState.equip_weapon(hero, other.id))
	# Найгірший випадок: герой стояв у самому центрі зони.
	await _visit("TempleZone", Vector3.ZERO, func(_screen: Node) -> void: pass)
	print("RESULT: ", "FAIL" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)

func _visit(zone_name: String, offset: Vector3, change: Callable) -> void:
	var town := get_tree().current_scene
	var player: CharacterBody3D = town.get_node("Player")
	var zone: Node3D = town.get_node("Buildings/" + zone_name)
	player.global_position = zone.global_position + offset + Vector3.UP * 0.05
	for i in 10:
		await get_tree().physics_frame
	var before := player.global_position
	town.call("_on_action_pressed")
	for i in 20:
		await get_tree().process_frame
	var screen := get_tree().current_scene
	change.call(screen)
	for i in 5:
		await get_tree().process_frame
	screen.call("_on_back_pressed")
	await _wait_for_scene(TOWN)
	player = get_tree().current_scene.get_node("Player")
	var shift := Vector2(before.x - player.global_position.x, before.z - player.global_position.z).length()
	print("PROBE %s (%s): героя поставило за %.2f м від місця, де він стояв" % [
		zone_name, GameState.selected_hero_id, shift])
	if shift > 0.3:
		_failed = true
	for direction: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		# Спершу даємо зупинитись: інакше розгін попереднього кроку
		# з'їдає частину руху назад.
		for i in 20:
			await get_tree().physics_frame
		var start := player.global_position
		for i in 30:
			player.set_move_input(direction)
			await get_tree().physics_frame
		player.set_move_input(Vector2.ZERO)
		var step := start.distance_to(player.global_position)
		print("PROBE   рух %s: %.2f м" % [direction, step])
		if step < MIN_STEP:
			_failed = true

func _wait_for_scene(path: String) -> void:
	for i in 600:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == path and not SceneLoader.is_busy():
			break
	for i in 10:
		await get_tree().physics_frame
