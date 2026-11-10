extends EnemyAbility

## АРМІЯ МЕРТВИХ (Кістяний Володар, фаза 2): встромляє косу в землю — по
## краях арени з-під землі виростають кістяні тотеми й лізуть скелети. Поки
## стоїть хоч один тотем, бос отримує лише половину шкоди (нитки від тотемів
## до боса — "ward" у їхньому описі), тож спершу — тотеми. Це прийом
## переходу фази: його не збити.
##
## Налаштування: totem, skeleton (описи), totems, skeletons (скільки),
## plant (с — скільки стоїть, встромивши косу).

const COLOR := Color(0.45, 1.0, 0.5)
## Коли коса входить у землю (кадр 21 анімації Plant).
const PLANT_HIT := 0.7

var _time := -1.0
var _raised := false
var _home := Vector3.INF
var _totem_spots: Array[Vector3] = []

func _init() -> void:
	id = "army_of_dead"
	cooldown = 999.0

func is_busy() -> bool:
	return _time >= 0.0

func try_use(_distance: float) -> bool:
	start_cooldown()
	_time = 0.0
	_raised = false
	enemy.velocity = Vector3.ZERO
	enemy.play_once(["Plant"])
	CombatVfx.shockwave(world(), enemy.global_position, 8.0, COLOR, 0.7)
	# Від боса до місць тотемів тягнуться темні стрічки (набір Obssidian) —
	# тотеми виростають саме тоді, коли стрічки досягають підлоги.
	if _home == Vector3.INF:
		_home = enemy.global_position
	_totem_spots = _edge_spots(int(config.get("totems", 3)), 1.6)
	var from := enemy.global_position + Vector3.UP * enemy.target_height * 0.8
	for spot in _totem_spots:
		Fx.signature(world(), "abyssal_tether", from, spot, PLANT_HIT, 1.3, Color(0.45, 1.0, 0.55))
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	if _home == Vector3.INF:
		_home = enemy.global_position
	if _time < 0.0:
		return
	_time += delta
	if not _raised and _time >= PLANT_HIT:
		_raised = true
		_raise()
	if _time >= float(config.get("plant", 2.2)):
		_time = -1.0

func _raise() -> void:
	var center := enemy.global_position
	CombatVfx.ground_hit(world(), center + enemy.facing_vector() * 1.5, 2.0)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.25)
	AudioManager.play(&"explosion", 0.05)
	var totem: Dictionary = config.get("totem", {})
	if not totem.is_empty():
		for spot in _totem_spots:
			_summon(spot, totem)
	var skeleton: Dictionary = config.get("skeleton", {})
	if not skeleton.is_empty():
		for spot in _edge_spots(int(config.get("skeletons", 4)), 4.0):
			_summon(spot, skeleton)

func _summon(spot: Vector3, definition: Dictionary) -> void:
	CombatVfx.ground_hit(world(), spot, 1.2)
	enemy.spawn_requested.emit(spot, definition, enemy)

## Місця по колу довкола центру зали: від центру — до краю зали боса,
## мінус inset (тотеми — під стінами, скелети — ближче).
func _edge_spots(count: int, inset: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var map_rows: Array = DungeonLevels.get_level(GameState.dungeon_level).map
	var room := DungeonBuilder.boss_room(map_rows)
	var base := randf() * TAU
	for i in count:
		var direction := Vector3(cos(base + TAU * i / count), 0.0, sin(base + TAU * i / count))
		var reach := 0.0
		var step := 1.0
		while step < 24.0:
			var cell := DungeonBuilder.cell_of(_home + direction * step)
			if not room.has(cell) or not DungeonBuilder.is_walkable(map_rows, cell.x, cell.y):
				break
			reach = step
			step += 0.5
		result.append(_home + direction * maxf(reach - inset, 2.0))
	return result
