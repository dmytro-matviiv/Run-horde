extends EnemyAbility

## ПІЛОНИ (бос): раз за бій (з фази "phase") бос здіймає довкола себе
## кілька пілонів — світні нитки від них роблять його невразливим. Розбив
## усі пілони — бос на кілька секунд знесилений і відкритий для ударів.
## "pylon" в описі — сам пілон (тотем з оберегом "target": "boss").

const STUN := 3.5
const DISTANCE := 5.5

var _raised := false
var _released := false

func _init() -> void:
	id = "pylons"
	cooldown = 1.0

func try_use(_distance: float) -> bool:
	if _raised or config.get("pylon", {}).is_empty():
		return false
	_raised = true
	var count := int(config.get("count", 3))
	var color := Color(1.0, 0.82, 0.35)
	CombatVfx.shockwave(world(), enemy.global_position, 7.0, color, 0.6)
	for i in count:
		var angle := TAU * i / count + randf() * 0.4
		var spot := _free_spot(Vector3(cos(angle), 0.0, sin(angle)))
		enemy.spawn_requested.emit(spot, config.pylon, enemy)
	return false

## Пілон стає на відстані від боса, але не в стіні.
func _free_spot(direction: Vector3) -> Vector3:
	var center := enemy.global_position
	var space := enemy.get_world_3d().direct_space_state
	var distance := DISTANCE
	while distance > 1.5:
		var spot := center + direction * distance
		var query := PhysicsRayQueryParameters3D.create(center + Vector3.UP, spot + Vector3.UP)
		query.collision_mask = 1
		if space.intersect_ray(query).is_empty():
			return spot
		distance -= 1.0
	return center + direction * 1.5

func tick(delta: float) -> void:
	super.tick(delta)
	# Усі пілони впали — бос знесилений.
	if _raised and not _released and enemy.summons_alive <= 0:
		_released = true
		enemy.hold_still(STUN)
		CombatVfx.impact(world(), enemy.global_position + Vector3.UP * enemy.target_height * 0.6,
			Color(1.0, 0.85, 0.4), true)
		enemy.ward_broken.emit()
