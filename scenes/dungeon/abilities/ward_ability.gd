extends EnemyAbility

## ОБЕРІГ: тотем береже найближчих ворогів (до них пливуть світні згустки) —
## поки зв'язок тримається, ворог майже не отримує шкоди ("factor" — частка шкоди,
## що проходить). Тотем стоїть на місці й сам не б'є: його треба
## розбити першим. З "target": "boss" — це пілон, що береже боса
## (factor 0 — повна невразливість).

const REFRESH := 0.25
const COLOR := Color(0.55, 0.85, 1.0)

const ORB_EVERY := 1.0
const ORB_FLIGHT := 0.6

var _refresh_left := 0.0
var _orb_left := 0.2
var _links: Array[Enemy3D] = []

func _init() -> void:
	id = "ward"
	cooldown = 0.0

func tick(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH
		_relink()
	_draw_beams()

func _relink() -> void:
	var factor := float(config.get("factor", 0.2))
	var reach := float(config.get("range", 8.0))
	var boss_only := String(config.get("target", "")) == "boss"
	var candidates: Array[Enemy3D] = []
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or other == enemy or not other.is_aim_target() or other.stationary:
			continue
		if boss_only != (other.kind == Enemy3D.Kind.BOSS):
			continue
		if other.global_position.distance_to(enemy.global_position) <= reach:
			candidates.append(other)
	candidates.sort_custom(func(a: Enemy3D, b: Enemy3D) -> bool:
		return a.global_position.distance_to(enemy.global_position) < b.global_position.distance_to(enemy.global_position))
	_links = candidates.slice(0, int(config.get("links", 3)))
	for other in _links:
		other.apply_ward(factor, REFRESH * 2.0)

## Від тотема до кожного, кого він береже, раз на мить плавно летить
## світний згусток (замість променів через увесь екран).
func _draw_beams() -> void:
	_orb_left -= enemy.get_physics_process_delta_time()
	if _orb_left > 0.0:
		return
	_orb_left = ORB_EVERY
	var color: Color = config.get("color", COLOR)
	var from := enemy.global_position + Vector3.UP * enemy.target_height * 0.85
	for other in _links:
		if is_instance_valid(other) and other.is_alive():
			CombatVfx.glow_orb(world(), from, other, other.target_height * 0.6, color, ORB_FLIGHT)

func on_death() -> void:
	_links.clear()
