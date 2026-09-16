extends Node2D

## Зона на землі (крижане поле, багаття): живе кілька секунд і
## щопівсекунди шкодить усім, хто всередині. Ворог може зайти й вийти —
## тому шкода тікає по таймеру, а не разово, як у вибуху.

const TICK_INTERVAL := 0.5
const SEGMENTS := 24

var _pool: ObjectPool
var _radius := 80.0
var _damage := 0.0
var _color := Color(1, 0.4, 0.1)
var _duration_left := 0.0
var _tick_left := 0.0
var _status: StringName = &""
var _status_power := 0.0
var _status_duration := 0.0
var _active := false

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func spawn(at_position: Vector2, def: WeaponDef, damage: float) -> void:
	global_position = at_position
	_radius = def.zone_radius
	_damage = damage
	_color = def.color
	_duration_left = def.zone_duration
	_tick_left = 0.0   # перший тік одразу, щоб зона не здавалась "мертвою"
	_status = def.status
	_status_power = def.status_power
	_status_duration = def.status_duration
	queue_redraw()

func pool_activate() -> void:
	_active = true
	visible = true

func pool_deactivate() -> void:
	_active = false
	visible = false
	global_position = Vector2(-10000, -10000)

func _process(delta: float) -> void:
	if not _active:
		return
	_duration_left -= delta
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = TICK_INTERVAL
		CombatQuery.hit_all(CombatQuery.enemies_in_circle(get_world_2d(), global_position, _radius), _damage, _status, _status_power, _status_duration)
	queue_redraw()
	if _duration_left <= 0.0:
		_pool.release(self)

func _draw() -> void:
	if not _active:
		return
	var fill := _color
	fill.a = 0.22
	draw_circle(Vector2.ZERO, _radius, fill)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, SEGMENTS, _color, 2.0)
