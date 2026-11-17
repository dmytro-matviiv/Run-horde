extends HeroSkill3D

## НАСКОК (Фенрір): стрибок на ворога й серія з 5 швидких ударів, поки
## він оглушений і безпорадний. Сусідів зачіпає частково.

const RANGE := 9.0
const HITS := 5
const HIT_GAP := 0.16
const HIT_DAMAGE := 0.75
const STUN := 1.4

var _target: Enemy3D
var _hits_left := 0
var _next_hit := 0.0

func _init() -> void:
	id = &"pounce"
	title = "Наскок"
	description = "Стрибок на ворога й серія з п'яти ударів, поки він оглушений і нічого не може вдіяти."
	color = Color(0.45, 0.95, 0.8)
	icon_kind = "dash"
	cooldown = 9.0

func _use(player: Node) -> bool:
	var best: Enemy3D = null
	var best_distance := RANGE
	for enemy: Enemy3D in player.enemies_in_radius(RANGE, true):
		if not enemy.is_aim_target():
			continue
		var d: float = enemy.global_position.distance_to(player.global_position)
		if d < best_distance:
			best_distance = d
			best = enemy
	if best == null:
		return false
	_target = best
	var offset: Vector3 = best.global_position - player.global_position
	offset.y = 0.0
	var distance := maxf(offset.length() - 1.0 - best.body_radius(), 0.0)
	var time := maxf(distance / 20.0, 0.08)
	player.face_direction(offset.normalized())
	player.dash(offset.normalized(), distance / time, time)
	player.grant_invulnerable(time + HIT_GAP * HITS + 0.2)
	best.stun(STUN + time, true)
	_hits_left = HITS
	_next_hit = time
	player.play_form_strike(true)
	return true

func _update(player: Node, delta: float) -> void:
	if _hits_left <= 0:
		return
	_next_hit -= delta
	if _next_hit > 0.0:
		return
	_next_hit = HIT_GAP
	_hits_left -= 1
	if _target == null or not is_instance_valid(_target) or not _target.is_alive():
		_hits_left = 0
		return
	var offset: Vector3 = _target.global_position - player.global_position
	offset.y = 0.0
	var last := _hits_left == 0
	player.deal_damage(_target, HIT_DAMAGE * (1.8 if last else 1.0), offset.normalized() * (4.0 if last else 0.3), last, id)
	CombatVfx.slash(player.get_parent(), _target.global_position + Vector3.UP * 0.8, player.facing_angle() + randf_range(-0.6, 0.6),
		1.4, 90.0, color, false, -0.3, 0.18)
	player.play_form_strike(last)
