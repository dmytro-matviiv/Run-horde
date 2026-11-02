extends EnemyAbility

## УДАР ХВОСТОМ (Інейний Дракон): б'є хвостом позаду й збоку — під ним
## позаду віялом червоне попередження. Стояти за спиною теж небезпечно.
##
## Налаштування: radius, arc (півкута позаду, градуси), windup, damage.

const COLOR := Color(1.0, 0.35, 0.25, 0.85)

var _origin := Vector3.ZERO
var _back := Vector3.BACK
var _marker: MeshInstance3D

func _init() -> void:
	id = "tail_sweep"
	cooldown = 6.0
	instant = true

func try_use(distance: float) -> bool:
	var radius := float(config.get("radius", 4.8))
	if distance > radius:
		return false
	# Б'є, лише коли герой збоку чи позаду — спереду дракон дихає.
	var to_player := player().global_position - enemy.global_position
	to_player.y = 0.0
	var arc := deg_to_rad(float(config.get("arc", 115.0)))
	_back = -enemy.facing_vector()
	if to_player.length() > 0.3 and _back.angle_to(to_player.normalized()) > arc:
		return false
	start_cooldown()
	_origin = enemy.global_position
	_marker = CombatVfx.make_telegraph(COLOR, radius, arc, true)
	world().add_child(_marker)
	_marker.global_position = Vector3(_origin.x, DungeonBuilder.FLOOR_TOP + 0.05, _origin.z)
	_marker.rotation.y = atan2(_back.x, _back.z)
	var marker := _marker
	var windup := float(config.get("windup", 0.7))
	var tween := marker.create_tween()
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(marker):
			CombatVfx.set_param(marker, &"progress", value), 0.0, 1.0, windup)
	enemy.get_tree().create_timer(windup + 0.3, false).timeout.connect(_clear)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_clear()
	var radius := float(config.get("radius", 4.8))
	var arc := deg_to_rad(float(config.get("arc", 115.0)))
	CombatVfx.shockwave(world(), _origin, radius, Color(0.8, 0.9, 1.0, 0.7), 0.3)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.15)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - _origin
	offset.y = 0.0
	if offset.length() <= radius and (offset.length() < 0.5 or _back.angle_to(offset.normalized()) <= arc):
		if hero.take_damage(damage()) and hero.has_method("knock_down"):
			hero.knock_down(offset.normalized() * 6.0, 0.35)

func on_death() -> void:
	_clear()

func _clear() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
