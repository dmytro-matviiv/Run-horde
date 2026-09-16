extends Node2D

## Вибух по площі: б'є всіх ворогів у радіусі ОДИН раз у момент появи
## (CombatQuery — без снарядів і без очікування сигналів), а далі лише
## малює коло, що розширюється й згасає. Тому лежить у пулі: вибухів
## за ран сотні.

const GROW_TIME := 0.25
const SEGMENTS := 20

var _pool: ObjectPool
var _radius := 60.0
var _color := Color(1, 0.5, 0.2)
var _elapsed := 0.0
var _active := false
# Удар прилітає з call_deferred (WeaponModule.spawn_blast), тобто на
# кадр пізніше за взяття з пулу. До того вибух не малюємо й не
# рахуємо час — інакше він встиг би "згаснути" ще до свого удару.
var _armed := false

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func spawn(at_position: Vector2, radius: float, damage: float, color: Color, status: StringName = &"", status_power: float = 0.0, status_duration: float = 0.0) -> void:
	global_position = at_position
	_radius = radius
	_color = color
	_elapsed = 0.0
	_armed = true
	visible = true
	CombatQuery.hit_all(CombatQuery.enemies_in_circle(get_world_2d(), at_position, radius), damage, status, status_power, status_duration)
	queue_redraw()

func pool_activate() -> void:
	_active = true
	_elapsed = 0.0
	_armed = false
	visible = false

func pool_deactivate() -> void:
	_active = false
	_armed = false
	visible = false
	global_position = Vector2(-10000, -10000)

func _process(delta: float) -> void:
	if not _active or not _armed:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= GROW_TIME:
		_pool.release(self)

func _draw() -> void:
	if not _active or not _armed:
		return
	var progress := clampf(_elapsed / GROW_TIME, 0.0, 1.0)
	var color := _color
	color.a = 1.0 - progress
	draw_circle(Vector2.ZERO, _radius * (0.35 + 0.65 * progress), color * Color(1, 1, 1, 0.35))
	draw_arc(Vector2.ZERO, _radius * (0.35 + 0.65 * progress), 0.0, TAU, SEGMENTS, color, 3.0)
