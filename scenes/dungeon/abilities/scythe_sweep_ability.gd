extends EnemyAbility

## ШИРОКИЙ УКІС (Кістяний Володар): закручується й косить по дузі 180°
## перед собою — червоне півколо на підлозі. Рятує перекат назад (з дуги)
## або під косу — за спину боса.
##
## Налаштування: radius, arc (півкут, градуси), windup, damage, push.

const COLOR := Color(1.0, 0.3, 0.2, 0.85)
const SLASH_COLOR := Color(0.75, 1.0, 0.7)

var _origin := Vector3.ZERO
var _front := Vector3.FORWARD
var _marker: MeshInstance3D

func _init() -> void:
	id = "scythe_sweep"
	cooldown = 6.0

func try_use(distance: float) -> bool:
	var radius := float(config.get("radius", 4.4))
	if distance > radius * 0.9 or not enemy.sees_player():
		return false
	start_cooldown()
	_origin = enemy.global_position
	var aim := player().global_position - _origin
	aim.y = 0.0
	_front = aim.normalized() if aim.length() > 0.2 else enemy.facing_vector()
	enemy.face_point(_origin + _front)
	var windup := float(config.get("windup", 0.9))
	_clear()
	_marker = CombatVfx.make_telegraph(COLOR, radius, deg_to_rad(float(config.get("arc", 90.0))), true)
	world().add_child(_marker)
	_marker.global_position = Vector3(_origin.x, DungeonBuilder.FLOOR_TOP + 0.05, _origin.z)
	_marker.rotation.y = atan2(_front.x, _front.z)
	var marker := _marker
	marker.create_tween().tween_method(func(value: float) -> void:
		if is_instance_valid(marker):
			marker.set_instance_shader_parameter(&"progress", value), 0.0, 1.0, windup)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	return true

## Замах збила суперздібність — півколо зникає разом із ним.
func tick(delta: float) -> void:
	super.tick(delta)
	if _marker != null and String(enemy.get("_special")) != id:
		_clear()

func resolve() -> void:
	_clear()
	var radius := float(config.get("radius", 4.4))
	var arc := float(config.get("arc", 90.0))
	CombatVfx.slash(world(), _origin + Vector3.UP * 1.1, atan2(_front.x, _front.z), radius, arc * 2.0, SLASH_COLOR, true, 0.0, 0.3)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.15)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - _origin
	offset.y = 0.0
	if offset.length() > radius + 0.3:
		return
	if offset.length() > 0.4 and _front.angle_to(offset.normalized()) > deg_to_rad(arc + 8.0):
		return
	if hero.take_damage(damage()) and hero.has_method("knock_down"):
		hero.knock_down(offset.normalized() * float(config.get("push", 6.0)), 0.3)

func on_death() -> void:
	_clear()

func _clear() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
