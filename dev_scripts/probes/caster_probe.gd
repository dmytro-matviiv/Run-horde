extends Node
## Тимчасово (test_env): Орк-палій і Склепний чаклун на 1-му рівні.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
var _defs := {}
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		_player.max_hp = 1000.0
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/caster_%s.png" % name)
func _spawn(name: String, cell: Vector2i) -> Enemy3D:
	var def: Dictionary = _defs[name].duplicate(true)
	def["no_elite"] = true
	def.erase("group")
	var e: Enemy3D = _dungeon.call("_spawn_enemy", DungeonBuilder.cell_center(cell) + Vector3(0, 0.2, 0), def, false)
	return e
func _clear() -> void:
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		e.queue_free()
	await _wait(0.2)
func _ready() -> void:
	PerfSettings.persist_settings = false
	GameState.dungeon_level = 0
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	for group in DungeonLevels.get_level(0).enemies.values():
		for d in group:
			_defs[String(d.name)] = d
	await _clear()
	# --- палій ---
	var pyro := _spawn("Орк-палій", Vector2i(19, 25))
	_player.global_position = DungeonBuilder.cell_center(Vector2i(19, 30)) + Vector3(0, 0.2, 0)
	_player.current_hp = 1000.0
	pyro.alert()
	var saw_aim := false
	var saw_pool := false
	var flights := 0
	for i in 200:
		await get_tree().physics_frame
		var lob = pyro.abilities[0]
		if lob.get("_aim_marker") != null and not saw_aim:
			saw_aim = true
			await _shot("pyro_aim")
		if saw_aim and not saw_pool and i % 9 == 0 and flights < 4:
			for n in _dungeon.find_children("*", "Node3D", true, false):
				if n is LobShell:
					var sh: Node3D = n.get("_shell")
					print("PROBE   глечик: %s, позиція %s, масштаб %s, видимий %s, герой %s" % [sh.get_class() if sh else "-", sh.global_position if sh else Vector3.ZERO, sh.scale if sh else Vector3.ZERO, sh.is_visible_in_tree() if sh else false, _player.global_position])
					var cam := get_viewport().get_camera_3d()
					var meshes := sh.find_children("*", "MeshInstance3D", true, false)
					print("PROBE   на екрані ", cam.unproject_position(sh.global_position), " за камерою ", cam.is_position_behind(sh.global_position), " мешів ", meshes.size(), " aabb ", (meshes[0] as MeshInstance3D).get_aabb() if meshes.size() > 0 else AABB())
					await _shot("jug_flight_%d" % flights)
					flights += 1
					break
		if not saw_pool:
			for n in _dungeon.find_children("*", "Node3D", true, false):
				if n is HazardPool:
					saw_pool = true
					await _shot("pyro_pool")
	print("PROBE палій: коло перед кидком %s, вогняна калюжа %s, здоров'я героя %.0f" % [saw_aim, saw_pool, _player.current_hp])
	pyro.global_position = DungeonBuilder.cell_center(Vector2i(19, 29)) + Vector3(0, 0.2, 0)
	_player.global_position = pyro.global_position + Vector3(0, 0, 2.0)
	var d0: float = pyro.global_position.distance_to(_player.global_position)
	await _wait(1.0)
	print("PROBE палій тікає: відстань %.1f -> %.1f, анімація %s" % [d0, pyro.global_position.distance_to(_player.global_position), pyro.get("_animation").current_animation])
	await _clear()
	# --- чаклун ---
	var orc := _spawn("Орк-рубака", Vector2i(18, 28))
	var warlock := _spawn("Склепний чаклун", Vector2i(20, 32))
	_player.global_position = DungeonBuilder.cell_center(Vector2i(19, 28)) + Vector3(0, 0.2, 0)
	_player.current_hp = 1000.0
	orc.set_physics_process(false)
	warlock.alert()
	var shielded := false
	var rooted := false
	for i in 360:
		await get_tree().physics_frame
		if orc.has_absorb() and not shielded:
			shielded = true
			await _shot("warlock_shield")
			var hp := orc.current_hp
			_player.deal_damage(orc, 1.0, Vector3.ZERO, false)
			print("PROBE щит на орку: удар зняв здоров'я %.1f (щит поглинув)" % (hp - orc.current_hp))
		if _player.is_rooted() and not rooted:
			rooted = true
			await _wait(0.1)
			await _shot("warlock_grasp")
	print("PROBE чаклун: щит на орку %s, руки схопили героя %s" % [shielded, rooted])
	var before := warlock.global_position
	_player.deal_damage(warlock, 0.2, Vector3.ZERO, false)
	await _wait(0.8)
	print("PROBE чаклун вдарений: перемістився на %.1f м" % before.distance_to(warlock.global_position))
	var before2 := warlock.global_position
	_player.deal_damage(warlock, 0.2, Vector3.ZERO, false)
	await _wait(0.8)
	print("PROBE удар знову (перезарядка): перемістився на %.1f м" % before2.distance_to(warlock.global_position))
	get_tree().quit(0)
