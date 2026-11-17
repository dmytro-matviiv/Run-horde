extends HeroSkill3D

## ЗЕМНИЙ РОЗЛАМ (Танк): удар щитом об землю — розлам біжить уперед,
## ранячи й оглушуючи всіх на лінії.

const LENGTH := 9.0
const WIDTH := 1.7
const DAMAGE := 2.0
const STUN := 1.4
const STEPS := 6

var _origin := Vector3.ZERO
var _direction := Vector3.FORWARD
var _step := -1
var _next := 0.0
var _hit: Array = []

func _init() -> void:
	id = &"ground_fissure"
	title = "Земний розлам"
	description = "Б'єш щитом об землю — розлам біжить уперед, оглушуючи й ранячи всіх на лінії."
	color = Color(0.85, 0.65, 0.4)
	icon_kind = "nova"
	cooldown = 10.0

func _use(player: Node) -> bool:
	var target: Node = player.get("_target")
	if is_instance_valid(target) and target is Enemy3D:
		var to: Vector3 = (target as Enemy3D).global_position - player.global_position
		to.y = 0.0
		if to.length() > 0.05:
			player.face_direction(to.normalized())
	_direction = player.facing_vector()
	_origin = player.global_position
	_step = 0
	_next = 0.0
	_hit.clear()
	player.play_clip("Shield_OneShot", 1.3)
	player.shake_camera(0.12)
	return true

func _update(player: Node, delta: float) -> void:
	if _step < 0:
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = 0.06
	_step += 1
	var center := _origin + _direction * (LENGTH * _step / STEPS)
	Fx.puff(player.get_parent(), center + Vector3.UP * 0.15, Color(0.6, 0.5, 0.4), 1.1)
	CombatVfx.shockwave(player.get_parent(), center, WIDTH, color, 0.25)
	for enemy: Enemy3D in player.enemies_near(center, WIDTH):
		if _hit.has(enemy.get_instance_id()):
			continue
		_hit.append(enemy.get_instance_id())
		player.deal_damage(enemy, DAMAGE, _direction * 3.0, true, id)
		enemy.stun(STUN, true)
	if _step >= STEPS:
		_step = -1
