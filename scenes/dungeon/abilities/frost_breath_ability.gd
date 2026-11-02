extends EnemyAbility

## КРИЖАНЕ ДИХАННЯ (Інейний Дракон): набирає повітря — у пащі яскравішає
## світло (сигнал ухилитись), на підлозі конус; далі видихає мороз. Хто
## в конусі й не за крижаною колоною — отримує й вмерзає на freeze секунд.
##
## Налаштування: range, arc (півкута, градуси), windup, freeze, damage,
## fast_cooldown (перезарядка у фазі 3 — дихає частіше).

const COLOR := Color(0.55, 0.9, 1.0, 0.9)

var _origin := Vector3.ZERO
var _direction := Vector3.FORWARD
var _cone: MeshInstance3D
var _glow: Node3D

func _init() -> void:
	id = "frost_breath"
	cooldown = 8.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("range", 9.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	if enemy.phases != null and enemy.phases.phase >= 3 and config.has("fast_cooldown"):
		set("_left", float(config.fast_cooldown))
	var windup := float(config.get("windup", 1.1))
	_origin = enemy.global_position
	_direction = player().global_position - _origin
	_direction.y = 0.0
	_direction = _direction.normalized() if _direction.length() > 0.1 else enemy.facing_vector()
	enemy.face_point(_origin + _direction)
	var reach := float(config.get("range", 9.0))
	_clear()
	_cone = CombatVfx.make_telegraph(COLOR, reach, deg_to_rad(float(config.get("arc", 32.0))), true)
	world().add_child(_cone)
	_cone.global_position = Vector3(_origin.x, DungeonBuilder.FLOOR_TOP + 0.05, _origin.z)
	_cone.rotation.y = atan2(_direction.x, _direction.z)
	var cone := _cone
	var tween := cone.create_tween()
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(cone):
			CombatVfx.set_param(cone, &"progress", value), 0.0, 1.0, windup)
	_mouth_glow(windup)
	enemy.get_tree().create_timer(windup + 0.3, false).timeout.connect(_clear)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	return true

## Світло в пащі наростає за замах.
func _mouth_glow(seconds: float) -> void:
	var skeleton := enemy.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var bone := "Jaw" if skeleton.find_bone("Jaw") >= 0 else "Head"
	if skeleton.find_bone(bone) < 0:
		return
	var holder := BoneAttachment3D.new()
	holder.bone_name = bone
	skeleton.add_child(holder)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.9, 1.0)
	light.light_energy = 0.0
	light.omni_range = 4.0
	holder.add_child(light)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	core.mesh = sphere
	core.material_override = CombatVfx.get_glow_material(Color(0.7, 0.95, 1.0))
	holder.add_child(core)
	core.scale = Vector3.ONE * 0.3
	var tween := holder.create_tween().set_parallel(true)
	tween.tween_property(light, "light_energy", 4.0, seconds)
	tween.tween_property(core, "scale", Vector3.ONE * 2.2, seconds).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(holder.queue_free)
	_glow = holder

func resolve() -> void:
	_clear()
	var reach := float(config.get("range", 9.0))
	var arc := deg_to_rad(float(config.get("arc", 32.0)))
	var parent := world()
	# Хмара морозу: іскри летять конусом уперед.
	var frost := CPUParticles3D.new()
	frost.one_shot = true
	frost.explosiveness = 0.6
	frost.amount = 40
	frost.lifetime = 0.8
	frost.mesh = CombatVfx.spark_mesh()
	frost.material_override = CombatVfx.spark_material()
	frost.color = Color(0.75, 0.95, 1.0)
	frost.direction = _direction
	frost.spread = rad_to_deg(arc)
	frost.initial_velocity_min = reach * 0.8
	frost.initial_velocity_max = reach * 1.4
	frost.damping_min = 4.0
	frost.damping_max = 6.0
	frost.gravity = Vector3.ZERO
	frost.scale_amount_min = 2.0
	frost.scale_amount_max = 4.0
	parent.add_child(frost)
	frost.global_position = _origin + Vector3.UP * enemy.target_height * 0.5 + _direction * 1.2
	frost.emitting = true
	parent.get_tree().create_timer(1.2, false).timeout.connect(frost.queue_free)
	for k in 4:
		var spot := _origin + _direction * (reach * (k + 1) / 5.0)
		CombatVfx.impact_decal(parent, spot, 0.9 + k * 0.25, Color(0.7, 0.92, 1.0), 0.6)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - _origin
	offset.y = 0.0
	if offset.length() > reach or offset.length() < 0.1 or _direction.angle_to(offset.normalized()) > arc + 0.05:
		return
	# За крижаною колоною (чи стіною) — дихання не дістає.
	var space := enemy.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(_origin + Vector3.UP * 1.0, hero.global_position + Vector3.UP * 1.0, 1)
	query.exclude = [enemy.get_rid()]
	if not space.intersect_ray(query).is_empty():
		return
	if hero.take_damage(damage()) and hero.has_method("root"):
		hero.root(float(config.get("freeze", 1.5)))

func on_death() -> void:
	_clear()

func _clear() -> void:
	if _cone != null and is_instance_valid(_cone):
		_cone.queue_free()
	_cone = null
