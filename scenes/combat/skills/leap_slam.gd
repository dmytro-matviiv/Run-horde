extends HeroSkill3D

## СТРИБОК-УДАР (Мечник): стрибок до найближчого ворога й удар об землю —
## шкода й оглушення всім довкола місця приземлення.

const RANGE := 8.0
const RADIUS := 3.2
const DAMAGE := 2.4
const STUN := 1.2

var _land_left := -1.0

func _init() -> void:
	id = &"leap_slam"
	title = "Стрибок-удар"
	description = "Стрибаєш до ворогів і з розмаху б'єш об землю: шкода й оглушення всім довкола."
	color = Color(1.0, 0.6, 0.3)
	icon_kind = "dash"
	cooldown = 9.0

func _use(player: Node) -> bool:
	var direction: Vector3 = player.facing_vector()
	var distance := 3.0
	var best_distance := RANGE
	for enemy: Enemy3D in player.enemies_in_radius(RANGE, true):
		var d: float = enemy.global_position.distance_to(player.global_position)
		if d < best_distance:
			best_distance = d
			var offset: Vector3 = enemy.global_position - player.global_position
			offset.y = 0.0
			direction = offset.normalized()
			distance = maxf(d - 1.2, 0.0)
	var time := maxf(distance / 16.0, 0.12)
	player.face_direction(direction)
	player.dash(direction, distance / time, time)
	player.grant_invulnerable(time + 0.15)
	player.play_clip("Sword_Attack", 1.6)
	_land_left = time
	return true

func _update(player: Node, delta: float) -> void:
	if _land_left < 0.0:
		return
	_land_left -= delta
	if _land_left >= 0.0:
		return
	_land_left = -1.0
	for enemy: Enemy3D in player.enemies_in_radius(RADIUS, false):
		var push: Vector3 = enemy.global_position - player.global_position
		push.y = 0.0
		player.deal_damage(enemy, DAMAGE, push.normalized() * 5.0, true, id)
		enemy.stun(STUN, true)
	var parent: Node = player.get_parent()
	CombatVfx.shockwave(parent, player.global_position, RADIUS, color, 0.35)
	Fx.puff(parent, player.global_position + Vector3.UP * 0.2, Color(0.7, 0.62, 0.55), 1.8)
	player.shake_camera(0.18)
