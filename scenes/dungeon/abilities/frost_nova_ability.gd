extends EnemyAbility

## КРИЖАНА ХВИЛЯ (Шаман Півночі). Герой підійшов ближче за near — шаман
## б'є посохом об підлогу: довкола розлітається кільце криги (radius),
## хто в ньому — повільніший (slow) і отримує шкоду, а сам шаман у
## вихорі снігу відлітає на distance м назад. Наздоганяй перекатом.
## Налаштування: near, radius, slow, time, distance, damage.

const COLOR := Color(0.65, 0.9, 1.0)

func _init() -> void:
	id = "frost_nova"
	cooldown = 7.0
	instant = true

func try_use(distance: float) -> bool:
	if distance > float(config.get("near", 3.0)):
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.25)), Color(COLOR, 0.0), 0.1)
	BossFx.gesture(enemy.get("_model") as Node3D, -16.0, -0.12, 0.2, 0.3)
	return true

func resolve() -> void:
	var radius := float(config.get("radius", 3.2))
	var center := enemy.global_position
	center.y = DungeonBuilder.FLOOR_TOP
	CombatVfx.shockwave(world(), center, radius, COLOR, 0.35)
	var frost := BossFx.floor_disc(BossFx.ice_material(Color(0.8, 0.95, 1.0, 0.75)), radius)
	world().add_child(frost)
	frost.global_position = center + Vector3.UP * 0.03
	var tween := frost.create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(frost, "scale", Vector3(0.01, 1.0, 0.01), 0.6)
	tween.tween_callback(frost.queue_free)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var off := hero.global_position - center
	off.y = 0.0
	if off.length() <= radius:
		if hero.take_damage(damage()):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.8, COLOR, false)
		if hero.has_method("apply_slow"):
			hero.apply_slow(float(config.get("slow", 0.5)), float(config.get("time", 2.0)))
	# Відліт від героя на прохідну клітинку.
	var away := -off.normalized() if off.length() > 0.1 else enemy.global_basis.z
	var rows: Variant = hero.get_parent().get("_map_rows")
	var spot := center
	var reach := float(config.get("distance", 6.0))
	for k in range(1, int(reach / 0.5) + 1):
		var point := center + away * k * 0.5
		var cell := DungeonBuilder.cell_of(point)
		if rows is Array and not DungeonBuilder.is_walkable(rows, cell.x, cell.y):
			break
		spot = point
	CombatVfx.smoke_puff(world(), enemy.global_position + Vector3.UP * 0.8, Color(0.92, 0.96, 1.0), 1.4)
	enemy.teleport_to(Vector3(spot.x, enemy.global_position.y, spot.z))
	CombatVfx.smoke_puff(world(), enemy.global_position + Vector3.UP * 0.8, Color(0.92, 0.96, 1.0), 1.4)
	enemy.face_point(hero.global_position)
