extends HeroSkill3D

## ПАСТКА МИСЛИВЦЯ (Лучник): ставиш пастку під ноги. Ворог, що наступить,
## сковується, а вибух ранить усіх поруч. Пастка чекає 15 секунд.

const LIFE := 15.0
const TRIGGER := 1.3
const RADIUS := 2.8
const DAMAGE := 2.6
const ROOT := 2.5

var _marker: Node3D
var _left := 0.0

func _init() -> void:
	id = &"hunter_trap"
	title = "Пастка мисливця"
	description = "Пастка під ногами: хто наступить — скований, а вибух ранить усіх поруч."
	color = Color(0.95, 0.55, 0.2)
	icon_kind = "nova"
	cooldown = 10.0

func _use(player: Node) -> bool:
	_clear()
	_marker = CombatVfx.make_ground_marker(color, TRIGGER)
	player.get_parent().add_child(_marker)
	_marker.global_position = player.global_position + player.facing_vector() * 1.2 + Vector3.UP * 0.05
	_left = LIFE
	return true

func _update(player: Node, delta: float) -> void:
	if _marker == null:
		return
	_left -= delta
	if _left <= 0.0:
		_clear()
		return
	var spot := _marker.global_position
	var victims: Array = player.enemies_near(spot, TRIGGER)
	if victims.is_empty():
		return
	(victims[0] as Enemy3D).stun(ROOT, true)
	for enemy: Enemy3D in player.enemies_near(spot, RADIUS):
		var push: Vector3 = enemy.global_position - spot
		push.y = 0.0
		player.deal_damage(enemy, DAMAGE, push.normalized() * 3.0, true, id)
	CombatVfx.shockwave(player.get_parent(), spot, RADIUS, color, 0.35)
	Fx.puff(player.get_parent(), spot + Vector3.UP * 0.3, Color(0.9, 0.5, 0.2), 1.6)
	player.shake_camera(0.1)
	_clear()

func _clear() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
