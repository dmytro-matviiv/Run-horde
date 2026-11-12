extends Node3D
class_name PoisonCloud

## Отруйна хмара Посоха трясовини: стоїть на місці кілька секунд і раз
## за разом труїть усіх, хто в ній. Велике болото (здібність посоха)
## ще й сповільнює.
##
## Вигляд — отруйна калюжа (Fx.make_pool): темна пляма з нерівним краєм,
## зелений дим і бульбашки, без пласкої заливки колом. Під кінець усихає.

const TICK := 0.5
const COLOR := Color(0.45, 0.95, 0.3, 0.85)

var radius := 2.0
## Хто лишив хмару: &"weapon" (посох отрути) чи id здібності.
var source: StringName = &"weapon"
var duration := 3.0
var tick_damage := 0.3
## Частка швидкості ворога всередині (1 — не сповільнює).
var slow := 1.0

var _player: Node
var _left := 0.0
var _tick_left := 0.0
var _pool: Node3D

static func spawn(parent: Node, player: Node, position: Vector3, cloud_radius: float, seconds: float,
		damage: float, slow_factor: float = 1.0) -> PoisonCloud:
	var cloud := PoisonCloud.new()
	cloud._player = player
	cloud.radius = cloud_radius
	cloud.duration = seconds
	cloud.tick_damage = damage
	cloud.slow = slow_factor
	parent.add_child(cloud)
	# Хмара лягає на підлогу під точкою влучання.
	cloud.global_position = Vector3(position.x, (player as Node3D).global_position.y, position.z)
	return cloud

func _ready() -> void:
	_left = duration
	_pool = Fx.make_pool(COLOR, radius * 0.75)
	add_child(_pool)
	# Калюжа розтікається з точки влучання.
	_pool.scale = Vector3.ONE * 0.3
	_pool.create_tween().tween_property(_pool, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	Fx.puff(get_parent(), global_position + Vector3.UP * 0.3, COLOR, 0.6 + radius * 0.15, 0.2)

func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or _player == null or not is_instance_valid(_player):
		queue_free()
		return
	# Під кінець калюжа всихає — видно, що скоро зникне.
	if _left < 0.6:
		_pool.scale = Vector3.ONE * maxf(_left / 0.6, 0.05)
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = TICK
	for enemy: Enemy3D in _player.enemies_near(global_position, radius):
		_player.deal_damage(enemy, tick_damage, Vector3.ZERO, false, source)
		if slow < 1.0 and enemy.is_alive():
			enemy.apply_slow(slow, TICK + 0.3)
