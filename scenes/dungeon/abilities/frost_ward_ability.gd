extends EnemyAbility

## КРИЖАНИЙ ОБЕРІГ (Шаман Півночі). Шаман здіймає посох (відхиляється
## назад) — і на союзника поруч (найпораненішого, у range) летить
## крижаний промінь: того вкриває панцир криги, що поглинає share його
## здоров'я time секунд. Щита не буде, якщо вбити шамана першим.
## Налаштування: range, windup, share, time.

const COLOR := Color(0.6, 0.88, 1.0)

var _target_id := 0

func _init() -> void:
	id = "frost_ward"
	cooldown = 9.0

func try_use(_distance: float) -> bool:
	var best: Enemy3D = null
	var best_score := INF
	var reach := float(config.get("range", 9.0))
	for node in enemy.get_parent().get_children():
		if not is_instance_valid(node) or not node is Enemy3D:
			continue
		var other := node as Enemy3D
		if other == enemy or not other.is_alive() or other.stationary:
			continue
		if other.global_position.distance_to(enemy.global_position) > reach:
			continue
		if float(other.get("_absorb")) > 0.0:
			continue
		var score := other.current_hp / maxf(other.max_hp, 1.0)
		if score < best_score:
			best_score = score
			best = other
	if best == null:
		return false
	start_cooldown()
	_target_id = best.get_instance_id()
	var windup := float(config.get("windup", 0.7))
	enemy.face_point(best.global_position)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	BossFx.gesture(enemy.get("_model") as Node3D, 20.0, 0.1, windup, 0.3)
	var glow := Fx.make_particles("circle_05", Color(COLOR, 0.9), 16, 0.6, 0.15, true)
	glow.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	glow.emission_sphere_radius = 0.4
	glow.direction = Vector3.UP
	glow.gravity = Vector3.ZERO
	glow.initial_velocity_min = 0.5
	glow.initial_velocity_max = 1.2
	enemy.add_child(glow)
	glow.position = Vector3.UP * (enemy.target_height + 0.2)
	enemy.get_tree().create_timer(windup + 0.2).timeout.connect(glow.queue_free)
	return true

func resolve() -> void:
	var target := instance_from_id(_target_id) as Enemy3D
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	CombatVfx.lightning(world(), [enemy.global_position + Vector3.UP * (enemy.target_height + 0.2),
		target.global_position + Vector3.UP * target.target_height * 0.6], COLOR, 0.2)
	target.add_absorb(target.max_hp * float(config.get("share", 0.4)), float(config.get("time", 6.0)), COLOR, true)
	CombatVfx.impact(world(), target.global_position + Vector3.UP * target.target_height * 0.6, COLOR, false)
