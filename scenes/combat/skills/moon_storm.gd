extends HeroSkill3D

## МІСЯЧНА БУРЯ — особлива здібність Місячного посоха.
## Шість променів із неба один за одним б'ють по ворогах довкола — кожен
## зачіпає ще й тих, хто стоїть поруч із ціллю.

const STRIKES := 6
const INTERVAL := 0.25
const RADIUS := 10.0
const DAMAGE := 1.3
const SPLASH_RADIUS := 1.4
const SPLASH := 0.5

var _left := 0
var _next := 0.0

func _init() -> void:
	id = &"moon_storm"
	title = "Місячна буря"
	description = "Шість променів із неба б'ють по ворогах довкола, зачіпаючи й тих, хто поруч."
	color = Spells3D.LIGHTNING_COLOR
	icon_kind = "bolt"
	cooldown = 12.0

func _use(_player: Node) -> bool:
	_left = STRIKES
	_next = 0.0
	return true

func _update(player: Node, delta: float) -> void:
	if _left <= 0:
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = INTERVAL
	_left -= 1
	# Промінь падає на випадкового ворога поруч, а як нікого — просто
	# поряд із Чарівницею (буря однаково видна й лякає).
	var enemies: Array[Enemy3D] = player.aim_targets_in_radius(RADIUS, false)
	var spot: Vector3 = player.global_position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
	if not enemies.is_empty():
		spot = enemies[randi() % enemies.size()].global_position
	CombatVfx.sky_beam(player.get_parent(), spot, color)
	for enemy: Enemy3D in player.enemies_near(spot, SPLASH_RADIUS):
		var direct := enemy.global_position.distance_to(spot) < 0.3
		player.deal_damage(enemy, DAMAGE if direct else DAMAGE * SPLASH, Vector3.ZERO, direct)
	player.shake_camera(0.05)
