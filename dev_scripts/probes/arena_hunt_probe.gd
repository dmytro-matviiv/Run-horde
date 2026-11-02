extends Node
## Тимчасово (test_env): у великій залі засідки (рівень 2, друга зала)
## герой стоїть у кутку — чи всі вороги хвилі йдуть на нього.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
var _player: Node3D
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		if _player != null:
			_player.max_hp = 99999.0
			_player.current_hp = 99999.0
			_player.set_attack_held(false)
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _ready() -> void:
	PerfSettings.persist_settings = false
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, 1)
	GameState.dungeon_level = 1
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_player = _dungeon.get_node("Player")
	await _wait(2.5)
	var rect: Rect2i = DungeonLevels.get_level(1).arenas[1]
	var corner := rect.position + Vector2i(1, 1)
	while not DungeonBuilder.is_walkable(DungeonLevels.get_level(1).map, corner.x, corner.y):
		corner += Vector2i(1, 0)
	corner += Vector2i(1, 1)
	_player.global_position = DungeonBuilder.cell_center(corner) + Vector3(0, 0.2, 0)
	for t in 6:
		await _wait(2.0)
		var total := 0
		var chasing := 0
		var far := 0.0
		for e in _dungeon.find_children("*", "Enemy3D", true, false):
			if not e.is_alive() or not e.hunting:
				continue
			total += 1
			if e.get("_aggro"):
				chasing += 1
			far = maxf(far, e.global_position.distance_to(_player.global_position))
			if t >= 5:
				var map: RID = e.get_world_3d().navigation_map
				var cp := NavigationServer3D.map_get_closest_point(map, e.global_position)
				var ag: NavigationAgent3D = e.get("_agent")
				print("   agent target %s pathlen %d idx %d dist_to_target %.1f map_ok %s reachable %s final %s repath %.2f windup %.2f stagger %.2f special '%s'" % [ag.target_position, ag.get_current_navigation_path().size(), ag.get_current_navigation_path_index(), ag.distance_to_target(), ag.get_navigation_map().is_valid(), ag.is_target_reachable(), ag.get_final_position(), e.get("_repath_left"), e.get("_windup_left"), e.get("_stagger_left"), e.get("_special")])
				var path := NavigationServer3D.map_get_path(map, e.global_position, _player.global_position, true)
				print("   closest navmesh %s (%.2f м), шлях точок %d, кінець %s" % [cp, Vector2(cp.x - e.global_position.x, cp.z - e.global_position.z).length(), path.size(), path[path.size() - 1] if path.size() > 0 else Vector3.ZERO])
			if t >= 5:
				var agent: NavigationAgent3D = e.get("_agent")
				print("   %s kind %d pos %s dist %.1f vel %.2f navdone %s cell %s walk %s stationary %s" % [e.display_name, e.kind, e.global_position, e.global_position.distance_to(_player.global_position), Vector2(e.velocity.x, e.velocity.z).length(), agent.is_navigation_finished(), DungeonBuilder.cell_of(e.global_position), DungeonBuilder.is_walkable(DungeonLevels.get_level(1).map, DungeonBuilder.cell_of(e.global_position).x, DungeonBuilder.cell_of(e.global_position).y), e.get("stationary")])
		print("PROBE %d с: ворогів засідки %d, женуться %d, найдальший %.1f м" % [(t + 1) * 2, total, chasing, far])
	get_tree().quit(0)
