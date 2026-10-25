extends EnemyAbility

## УДАР КРИЛАМИ (Інейний Дракон, фаза 3): змахує крилами — хуртовина
## зносить героя геть від дракона, до країв арени.
##
## Налаштування: range, push (м/с), windup.

const COLOR := Color(0.85, 0.95, 1.0, 0.7)

func _init() -> void:
	id = "wing_gust"
	cooldown = 7.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("range", 10.0)):
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.6)), Color(COLOR, 0.6), 2.5)
	return true

func resolve() -> void:
	var parent := world()
	var center := enemy.global_position
	CombatVfx.shockwave(parent, center, float(config.get("range", 10.0)), COLOR, 0.6)
	var snow := CPUParticles3D.new()
	snow.one_shot = true
	snow.explosiveness = 0.8
	snow.amount = 36
	snow.lifetime = 0.9
	snow.mesh = CombatVfx.spark_mesh()
	snow.material_override = CombatVfx.spark_material()
	snow.color = Color(0.9, 0.97, 1.0)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	snow.emission_sphere_radius = 1.5
	snow.direction = Vector3(1, 0.2, 0)
	snow.spread = 180.0
	snow.flatness = 0.8
	snow.initial_velocity_min = 8.0
	snow.initial_velocity_max = 14.0
	snow.damping_min = 6.0
	snow.damping_max = 9.0
	snow.gravity = Vector3.ZERO
	snow.scale_amount_min = 2.0
	snow.scale_amount_max = 3.5
	parent.add_child(snow)
	snow.global_position = center + Vector3.UP * 1.2
	snow.emitting = true
	parent.get_tree().create_timer(1.2, false).timeout.connect(snow.queue_free)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - center
	offset.y = 0.0
	if offset.length() <= float(config.get("range", 10.0)) and hero.has_method("knock_down"):
		hero.knock_down(offset.normalized() * float(config.get("push", 11.0)), 0.45)
