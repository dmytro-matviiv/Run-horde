extends EnemyAbility

## МЕРЕХТІННЯ: ворог розчиняється в диму й за мить виникає за спиною
## героя — і одразу замахується. Замах короткий, але червону зону видно:
## обернись і перекотись.

const FADE := 0.4
const MIN_DISTANCE := 3.0
const MAX_DISTANCE := 12.0
const BEHIND := 2.0
const STRIKE_WINDUP := 0.45
const SMOKE := Color(0.6, 0.4, 0.95)

var _busy := false

func _init() -> void:
	id = "blink"
	cooldown = 6.5

func is_busy() -> bool:
	return _busy

func try_use(distance: float) -> bool:
	if distance < MIN_DISTANCE or distance > MAX_DISTANCE or not enemy.sees_player():
		return false
	start_cooldown()
	_busy = true
	CombatVfx.impact(world(), enemy.global_position + Vector3.UP, SMOKE, true)
	enemy.set_hidden(true)
	var tween := enemy.create_tween()
	tween.tween_interval(FADE)
	tween.tween_callback(_reappear)
	return true

func _reappear() -> void:
	var hero := player()
	var facing: Vector3 = hero.get_facing() if hero.has_method("get_facing") else Vector3.FORWARD
	var spot := _free_spot(hero.global_position, -facing)
	enemy.teleport_to(spot)
	enemy.set_hidden(false)
	CombatVfx.impact(world(), spot + Vector3.UP, SMOKE, true)
	_busy = false
	enemy.strike_now(STRIKE_WINDUP)

## За спиною героя, а якщо там стіна — збоку.
func _free_spot(center: Vector3, behind: Vector3) -> Vector3:
	var space := enemy.get_world_3d().direct_space_state
	for turn: float in [0.0, PI * 0.5, -PI * 0.5, PI]:
		var direction := behind.rotated(Vector3.UP, turn)
		var spot := center + direction * BEHIND
		var query := PhysicsRayQueryParameters3D.create(center + Vector3.UP, spot + Vector3.UP)
		query.collision_mask = 1
		if space.intersect_ray(query).is_empty():
			return spot
	return center + behind * 0.5
