extends EnemyAbility

## РОЗПАДАЄТЬСЯ НА УЛАМКИ (Ожилий вартовий): загинувши, розлітається
## шматками льоду — коло radius за мить вибухає й ранить усіх у ньому.
## Добивати краще здалеку.
##
## Налаштування: radius, delay (с), damage (частка удару ворога).

const COLOR := Color(0.6, 0.9, 1.0, 0.9)

func _init() -> void:
	id = "shatter"
	cooldown = 0.0

func on_death() -> void:
	var parent := world()
	var center := enemy.global_position
	var radius := float(config.get("radius", 2.6))
	var hurt := damage()
	var hero := player()
	var marker := CombatVfx.make_telegraph(COLOR, radius, PI, true)
	parent.add_child(marker)
	marker.global_position = Vector3(center.x, DungeonBuilder.FLOOR_TOP + 0.05, center.z)
	var tween := marker.create_tween()
	tween.tween_method(func(value: float) -> void:
		CombatVfx.set_param(marker, &"progress", value), 0.0, 1.0, float(config.get("delay", 0.5)))
	tween.tween_callback(func() -> void:
		marker.queue_free()
		CombatVfx.shockwave(parent, center, radius, COLOR, 0.3)
		CombatVfx.impact(parent, center + Vector3.UP * 0.9, Color(0.8, 0.95, 1.0), true)
		CombatVfx.impact_decal(parent, center, radius * 0.7, COLOR, 0.4)
		_shards(parent, center)
		if is_instance_valid(hero):
			var offset := hero.global_position - center
			offset.y = 0.0
			if offset.length() <= radius:
				hero.take_damage(hurt))

## Шматки льоду розлітаються на всі боки.
static func _shards(parent: Node, center: Vector3) -> void:
	var shards := CPUParticles3D.new()
	shards.one_shot = true
	shards.explosiveness = 1.0
	shards.amount = 14
	shards.lifetime = 0.7
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.24, 0.1)
	shards.mesh = mesh
	shards.material_override = CombatVfx.get_glow_material(Color(0.55, 0.85, 1.0))
	shards.direction = Vector3.UP
	shards.spread = 70.0
	shards.initial_velocity_min = 4.0
	shards.initial_velocity_max = 8.0
	shards.gravity = Vector3(0, -14.0, 0)
	shards.angular_velocity_min = -400.0
	shards.angular_velocity_max = 400.0
	parent.add_child(shards)
	shards.global_position = center + Vector3.UP * 1.0
	shards.emitting = true
	parent.get_tree().create_timer(1.2, false).timeout.connect(shards.queue_free)
