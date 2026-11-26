extends EnemyAbility

## ЛАВОВИЙ КУЛАК (Обсидіановий голем). Голем відхиляється далеко назад і
## присідає, заносячи кулаки, — тоді гупає об підлогу. Від нього віялом
## до героя розходяться count тріщин, з яких б'є лава: тріщина спершу
## тьмяна (warn), тоді розжарюється й пече всіх на ній; лишається
## гарячою burn секунд. Стань між тріщинами.
## Налаштування: windup, count, length, spread, warn, burn, damage.

const COLOR := Color(1.0, 0.45, 0.1)
const WIDTH := 1.0

var _cracks: Array = []

func _init() -> void:
	id = "lava_slam"
	cooldown = 9.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("length", 8.0)):
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.9))
	enemy.face_player(100.0)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	BossFx.gesture(enemy.get("_model") as Node3D, 22.0, -0.1, windup, 0.25)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var origin := enemy.global_position
	origin.y = DungeonBuilder.FLOOR_TOP + 0.05
	var to := hero.global_position - origin
	to.y = 0.0
	var base := atan2(to.x, to.z)
	var count := int(config.get("count", 3))
	var spread := deg_to_rad(float(config.get("spread", 28.0)))
	var length := float(config.get("length", 8.0))
	CombatVfx.ground_hit(world(), origin, 1.6)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.12)
	for i in count:
		var yaw := base + (float(i) - (count - 1) * 0.5) * spread
		var dir := Vector3(sin(yaw), 0.0, cos(yaw))
		var strip := BossFx.lava_strip(length, WIDTH)
		world().add_child(strip)
		strip.global_position = origin + dir * (length * 0.5 + 0.8)
		strip.rotation.y = yaw
		_cracks.append({"node": strip, "from": origin + dir * 0.8, "dir": dir, "left": float(config.get("warn", 0.6)), "hot": false, "burn": float(config.get("burn", 2.5)), "tick": 0.0})

func tick(delta: float) -> void:
	super.tick(delta)
	var hero := player()
	var length := float(config.get("length", 8.0))
	for i in range(_cracks.size() - 1, -1, -1):
		var c: Dictionary = _cracks[i]
		var node: MeshInstance3D = c.node
		if not c.hot:
			c.left = float(c.left) - delta
			var t := clampf(1.0 - float(c.left) / float(config.get("warn", 0.6)), 0.0, 1.0)
			if is_instance_valid(node):
				BossFx.set_heat(node, t * 0.3, 0.5 * t)
			if float(c.left) <= 0.0:
				c.hot = true
				if is_instance_valid(node):
					BossFx.set_heat(node, 1.0, 1.0)
					var sparks := Fx.make_particles("flame_06", Color(1.0, 0.6, 0.2, 0.9), 14, 0.5, 0.5, true)
					sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
					sparks.emission_box_extents = Vector3(WIDTH * 0.4, 0.05, length * 0.5)
					sparks.direction = Vector3.UP
					sparks.gravity = Vector3.ZERO
					sparks.initial_velocity_min = 1.5
					sparks.initial_velocity_max = 3.0
					node.add_child(sparks)
					# Частинки не мають тягтися за масштабом смуги.
					sparks.scale = Vector3(1.0 / node.scale.x, 1.0, 1.0 / node.scale.z)
			continue
		c.burn = float(c.burn) - delta
		c.tick = float(c.tick) - delta
		if hero != null and is_instance_valid(hero) and float(c.tick) <= 0.0 and _on_crack(hero.global_position, c, length):
			c.tick = 0.5
			if hero.take_damage(damage() * (1.0 if float(c.burn) > float(config.get("burn", 2.5)) - 0.1 else 0.35)):
				CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.5, COLOR, false)
		if float(c.burn) <= 0.0:
			if is_instance_valid(node):
				var tween := node.create_tween()
				tween.tween_method(func(v: float) -> void: BossFx.set_heat(node, v, v), 1.0, 0.0, 0.6)
				tween.tween_callback(node.queue_free)
			_cracks.remove_at(i)

func _on_crack(point: Vector3, c: Dictionary, length: float) -> bool:
	var off: Vector3 = point - (c.from as Vector3)
	off.y = 0.0
	var along := off.dot(c.dir)
	var side := (off - (c.dir as Vector3) * along).length()
	return along > -0.3 and along < length + 0.3 and side < WIDTH * 0.6

func on_death() -> void:
	for c: Dictionary in _cracks:
		if is_instance_valid(c.node):
			(c.node as Node).queue_free()
	_cracks.clear()
