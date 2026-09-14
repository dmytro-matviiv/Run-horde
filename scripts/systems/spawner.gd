extends Node

## Спавнер ворогів: з часом дедалі частіше створює ворогів за межами
## екрана по колу навколо героя. Інтенсивність росте лінійно від
## SPAWN_RATE_START до SPAWN_RATE_END за RUN_DURATION секунд.

var _enemy_pool: ObjectPool
var _crystal_pool: ObjectPool
var _hero: Node2D
var _run: Run
var _on_enemy_died: Callable

var _spawn_accumulator := 0.0

func setup(enemy_pool: ObjectPool, crystal_pool: ObjectPool, hero: Node2D, run: Run, on_enemy_died: Callable) -> void:
	_enemy_pool = enemy_pool
	_crystal_pool = crystal_pool
	_hero = hero
	_run = run
	_on_enemy_died = on_enemy_died

func _process(delta: float) -> void:
	var minute := _run.get_elapsed_minutes()
	var progress := clampf(minute / (Balance.RUN_DURATION / 60.0), 0.0, 1.0)
	var current_rate := lerpf(Balance.SPAWN_RATE_START, Balance.SPAWN_RATE_END, progress)

	_spawn_accumulator += current_rate * delta
	while _spawn_accumulator >= 1.0:
		_spawn_accumulator -= 1.0
		_spawn_enemy(minute)

func _spawn_enemy(minute: float) -> void:
	var enemy: Node = _enemy_pool.acquire()
	enemy.set_crystal_pool(_crystal_pool)
	enemy.spawn(_random_spawn_position(), _hero, minute, _on_enemy_died)

## Точка за межами екрана, по колу навколо героя.
func _random_spawn_position() -> Vector2:
	var viewport_size := _hero.get_viewport_rect().size
	var radius := viewport_size.length() * 0.5 * Balance.SPAWN_RADIUS_FACTOR
	var angle := randf() * TAU
	return _hero.global_position + Vector2(cos(angle), sin(angle)) * radius
