extends EnemyAbility

## ЗЛОВІСНИЙ ВИБУХ (Розкладена плоть): гине — коло на підлозі, і за мить
## тіло розривається отрутою: б'є героя й ІНШИХ ВОРОГІВ поруч (добий її
## біля них!) і лишає отруйну калюжу на pool секунд.
##
## Налаштування: radius, delay (с), damage (частка удару по героєві),
## mob_share (частка її здоров'я — шкода іншим ворогам), pool,
## pool_radius, pool_damage (частка удару — за тик калюжі).

const COLOR := Color(0.55, 0.9, 0.3, 0.9)

func _init() -> void:
	id = "death_blast"
	cooldown = 0.0

func on_death() -> void:
	var parent := world()
	var center := Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP + 0.05, enemy.global_position.z)
	var radius := float(config.get("radius", 3.0))
	var hero := player()
	var hero_damage := damage()
	var mob_damage := enemy.max_hp * float(config.get("mob_share", 0.5))
	var pool_tick := enemy.damage * float(config.get("pool_damage", 0.25))
	var pool_radius := float(config.get("pool_radius", 2.2))
	var pool_seconds := float(config.get("pool", 4.0))
	var tree := enemy.get_tree()
	var marker := CombatVfx.make_telegraph(COLOR, radius, PI, true)
	parent.add_child(marker)
	marker.global_position = center
	var tween := marker.create_tween()
	tween.tween_method(func(value: float) -> void:
		CombatVfx.set_param(marker, &"progress", value), 0.0, 1.0, float(config.get("delay", 0.45)))
	tween.tween_callback(func() -> void:
		marker.queue_free()
		CombatVfx.shockwave(parent, center, radius, COLOR, 0.4)
		Fx.flipbook(parent, center + Vector3.UP * 1.0, "explosion", radius * 1.5, COLOR.lightened(0.15), 0.55, false, true)
		CombatVfx.impact_decal(parent, center, radius * 0.8, COLOR, 0.6)
		var rig := tree.get_first_node_in_group(&"camera_rig")
		if rig != null:
			rig.shake(0.15)
		if hero != null and is_instance_valid(hero):
			var offset := hero.global_position - center
			offset.y = 0.0
			if offset.length() <= radius + 0.3:
				hero.take_damage(hero_damage)
		for node in tree.get_nodes_in_group(&"enemies"):
			var other := node as Enemy3D
			if other == null or not other.is_alive() or other.kind == Enemy3D.Kind.BOSS:
				continue
			var away := other.global_position - center
			away.y = 0.0
			if away.length() <= radius:
				other.take_damage(mob_damage, away.normalized() * 4.0)
		HazardPool.spawn(parent, center, hero, pool_radius, pool_tick, pool_seconds, Color(0.5, 0.9, 0.3)))
