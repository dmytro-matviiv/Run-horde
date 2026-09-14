extends Node

## Спавнер ворогів: з часом дедалі частіше створює ворогів за межами
## екрана по колу навколо героя. Інтенсивність росте лінійно від
## SPAWN_RATE_START до SPAWN_RATE_END за RUN_DURATION секунд.
## Тип конкретного ворога — випадковий (з вагою spawn_weight) серед
## тих, чий EnemyDef.min_spawn_minute уже настав. Боси спавняться
## окремо, напряму за часом (2:00 і 4:00), а не через цей розподіл.

const ENEMY_DEFS: Array[EnemyDef] = [
	preload("res://data/enemies/skeleton.tres"),
	preload("res://data/enemies/bat.tres"),
	preload("res://data/enemies/golem.tres"),
	preload("res://data/enemies/archer.tres"),
	preload("res://data/enemies/bomber_spider.tres"),
]

const BOSS_DEFS: Array[EnemyDef] = [
	preload("res://data/enemies/boss_bone_king.tres"),
	preload("res://data/enemies/boss_golem_destroyer.tres"),
]
const BOSS_SPAWN_SECONDS: Array[float] = [120.0, 240.0]   # 2:00, 4:00

var _enemy_pool: ObjectPool
var _crystal_pool: ObjectPool
var _enemy_projectile_pool: ObjectPool
var _hero: Node2D
var _run: Run
var _on_enemy_died: Callable
var _on_damage_dealt: Callable

var _spawn_accumulator := 0.0
var _bosses_spawned: Array[bool] = [false, false]

func setup(enemy_pool: ObjectPool, crystal_pool: ObjectPool, enemy_projectile_pool: ObjectPool, hero: Node2D, run: Run, on_enemy_died: Callable, on_damage_dealt: Callable) -> void:
	_enemy_pool = enemy_pool
	_crystal_pool = crystal_pool
	_enemy_projectile_pool = enemy_projectile_pool
	_hero = hero
	_run = run
	_on_enemy_died = on_enemy_died
	_on_damage_dealt = on_damage_dealt

func _process(delta: float) -> void:
	var minute := _run.get_elapsed_minutes()

	_check_boss_spawns(minute * 60.0, minute)

	var progress := clampf(minute / (Balance.RUN_DURATION / 60.0), 0.0, 1.0)
	var current_rate := lerpf(Balance.SPAWN_RATE_START, Balance.SPAWN_RATE_END, progress)

	_spawn_accumulator += current_rate * delta
	while _spawn_accumulator >= 1.0:
		_spawn_accumulator -= 1.0
		_spawn_enemy(minute, _pick_enemy_def(minute))

func _check_boss_spawns(elapsed_seconds: float, minute: float) -> void:
	for i in BOSS_SPAWN_SECONDS.size():
		if not _bosses_spawned[i] and elapsed_seconds >= BOSS_SPAWN_SECONDS[i]:
			_bosses_spawned[i] = true
			_spawn_enemy(minute, BOSS_DEFS[i])

## Випадковий тип серед доступних на цій хвилині, зважений на
## spawn_weight (частіші типи випадають частіше).
func _pick_enemy_def(minute: float) -> EnemyDef:
	var available: Array[EnemyDef] = []
	var total_weight := 0.0
	for def in ENEMY_DEFS:
		if minute >= def.min_spawn_minute:
			available.append(def)
			total_weight += def.spawn_weight
	if available.is_empty():
		return ENEMY_DEFS[0]
	var roll := randf() * total_weight
	for def in available:
		roll -= def.spawn_weight
		if roll <= 0.0:
			return def
	return available[available.size() - 1]

func _spawn_enemy(minute: float, def: EnemyDef) -> void:
	var enemy: Node = _enemy_pool.acquire()
	enemy.set_crystal_pool(_crystal_pool)
	enemy.set_projectile_pool(_enemy_projectile_pool)
	enemy.spawn(_random_spawn_position(), _hero, minute, _on_enemy_died, def, _on_damage_dealt)

## Точка за межами екрана, по колу навколо героя.
func _random_spawn_position() -> Vector2:
	var viewport_size := _hero.get_viewport_rect().size
	var radius := viewport_size.length() * 0.5 * Balance.SPAWN_RADIUS_FACTOR
	var angle := randf() * TAU
	return _hero.global_position + Vector2(cos(angle), sin(angle)) * radius
