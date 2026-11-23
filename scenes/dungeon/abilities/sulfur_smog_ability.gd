extends EnemyAbility

## СІРЧАНИЙ ЧАД (Сірчаний котел, не ходить). Котел булькає й щоcooldown
## секунд випускає хмару чаду, що повільно пливе до героя (speed) і висить
## time секунд. Хто в чаду — його удари промахуються з шансом miss.
## Виходь із жовтої хмари, перш ніж битись. Котел сам по собі не б'є.
## Налаштування: radius, speed, time, miss, range.

const COLOR := Color(0.85, 0.85, 0.25, 0.5)

var _clouds: Array = []

func _init() -> void:
	id = "sulfur_smog"
	cooldown = 7.0

func tick(delta: float) -> void:
	super.tick(delta)
	var hero := player()
	if ready_to_use() and hero != null and is_instance_valid(hero) \
			and hero.global_position.distance_to(enemy.global_position) <= float(config.get("range", 12.0)):
		start_cooldown()
		_belch()
	var radius := float(config.get("radius", 2.6))
	for i in range(_clouds.size() - 1, -1, -1):
		var cloud: Dictionary = _clouds[i]
		cloud.left -= delta
		var node: Node3D = cloud.node
		if cloud.left <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_clouds.remove_at(i)
			continue
		if hero == null or not is_instance_valid(hero):
			continue
		var to := hero.global_position - node.global_position
		to.y = 0.0
		if to.length() > 0.3:
			node.global_position += to.normalized() * float(config.get("speed", 1.1)) * delta
		if to.length() <= radius and hero.has_method("set_smog"):
			hero.set_smog(0.2, float(config.get("miss", 0.45)))

func _belch() -> void:
	var cloud := Node3D.new()
	world().add_child(cloud)
	cloud.global_position = Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP, enemy.global_position.z)
	var radius := float(config.get("radius", 2.6))
	var motes := CombatVfx.make_motes(Color(0.8, 0.8, 0.2), 26, radius * 0.8, 0.5, 0.35)
	cloud.add_child(motes)
	motes.position.y = 0.6
	var ring := CombatVfx.make_ground_marker(COLOR, radius)
	CombatVfx.set_param(ring, &"progress", 1.0)
	ring.position.y = 0.05
	cloud.add_child(ring)
	CombatVfx.smoke_puff(world(), enemy.global_position + Vector3.UP * 1.2, Color(0.8, 0.8, 0.25), 1.6)
	_clouds.append({"node": cloud, "left": float(config.get("time", 9.0))})

func on_death() -> void:
	for cloud: Dictionary in _clouds:
		if is_instance_valid(cloud.node):
			cloud.node.queue_free()
	_clouds.clear()
