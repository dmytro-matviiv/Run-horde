extends EnemyAbility

## ВТЕЧА В МОГИЛУ (Кістяний чаклун): герой підійшов надто близько — чаклун
## провалюється під землю (зелене коло, пил) і за мить виринає в іншому
## кінці кладовища, далеко від героя. Наздогнати його — справа ривка.
##
## Налаштування: trigger (м — "надто близько"), min (м від героя — нове
## місце не ближче), reach (м — як далеко від себе шукає), sink, under (с).

const COLOR := Color(0.45, 1.0, 0.5)
const DUST := Color(0.5, 0.45, 0.35)

enum Step {IDLE, SINK, UNDER}

var _step := Step.IDLE
var _time := 0.0

func _init() -> void:
	id = "grave_escape"
	cooldown = 9.0

func is_busy() -> bool:
	return _step != Step.IDLE

func try_use(distance: float) -> bool:
	if distance > float(config.get("trigger", 3.5)):
		return false
	start_cooldown()
	_step = Step.SINK
	_time = float(config.get("sink", 0.6))
	enemy.play_once(["Sink"])
	enemy.burrow_down(_time)
	CombatVfx.impact_decal(world(), enemy.global_position, 1.2, DUST, 0.8)
	CombatVfx.shockwave(world(), enemy.global_position, 1.6, COLOR, 0.4)
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	if _step == Step.IDLE:
		return
	_time -= delta
	if _time > 0.0:
		return
	if _step == Step.SINK:
		enemy.set_hidden(true)
		_step = Step.UNDER
		_time = float(config.get("under", 0.6))
		return
	_step = Step.IDLE
	var spot := _pick_spot()
	if spot != Vector3.INF:
		enemy.teleport_to(spot)
	enemy.set_hidden(false)
	enemy.emerge(0.6)
	CombatVfx.impact_decal(world(), enemy.global_position, 1.2, DUST, 0.8)
	CombatVfx.shockwave(world(), enemy.global_position, 1.6, COLOR, 0.4)

## Найдальше від героя з кількох випадкових місць довкола: прохідна
## клітинка, не зала боса, вільно (не стіл і не надгробок).
func _pick_spot() -> Vector3:
	var map_rows: Array = DungeonLevels.get_level(GameState.dungeon_level).map
	var boss_room := DungeonBuilder.boss_room(map_rows)
	var from := enemy.global_position
	var hero := player()
	var reach := float(config.get("reach", 16.0))
	var low := float(config.get("min", 9.0))
	var best := Vector3.INF
	var best_distance := 0.0
	for attempt in 24:
		var angle := randf() * TAU
		var spot := from + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(4.0, reach)
		var cell := DungeonBuilder.cell_of(spot)
		if not DungeonBuilder.is_walkable(map_rows, cell.x, cell.y) or boss_room.has(cell):
			continue
		var away := spot.distance_to(hero.global_position) if hero != null else 99.0
		if away < low or away <= best_distance:
			continue
		if not Enemy3D.is_spot_clear(enemy.get_world_3d(), spot):
			continue
		best = Vector3(spot.x, from.y, spot.z)
		best_distance = away
	return best
