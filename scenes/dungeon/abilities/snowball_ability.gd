extends EnemyAbility

## СНІЖНА БРИЛА (Сніговий велетень). Велетень нахиляється й згрібає
## сніг (windup, Slam), — тоді котить на героя брилу. Вона біжить по
## підлозі, обертаючись, і росте, збираючи сніг; хто під неї потрапив —
## шкода й збиває з ніг. Об стіну розлітається хмарою снігу. Відступи
## вбік з її шляху.
## Налаштування: min, windup, speed, reach, size, grow, knock, damage.

const COLOR := Color(0.92, 0.96, 1.0)

var _balls: Array = []
static var _material: StandardMaterial3D

func _init() -> void:
	id = "snowball"
	cooldown = 8.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 3.5)):
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.9))
	enemy.face_player(100.0)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	BossFx.gesture(enemy.get("_model") as Node3D, -20.0, -0.1, windup * 0.7, windup * 0.3)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var from := enemy.global_position
	var dir := hero.global_position - from
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else -enemy.global_basis.z
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	ball.mesh = sphere
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(0.93, 0.96, 1.0)
		_material.roughness = 0.9
		_material.albedo_texture = Fx.art("smoke_04")
		_material.uv1_scale = Vector3(2.0, 2.0, 2.0)
	ball.material_override = _material
	world().add_child(ball)
	var size := float(config.get("size", 0.9))
	var start := from + dir * 1.4
	start.y = DungeonBuilder.FLOOR_TOP
	var dust := Fx.make_particles("circle_05", Color(COLOR, 0.8), 14, 0.5, 0.14)
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 0.8
	dust.initial_velocity_max = 1.8
	dust.local_coords = false
	ball.add_child(dust)
	_balls.append({"node": ball, "pos": start, "dir": dir, "size": size, "travel": 0.0, "hit": false})
	CombatVfx.ground_hit(world(), start, 1.0)

func tick(delta: float) -> void:
	super.tick(delta)
	var hero := player()
	var speed := float(config.get("speed", 7.0))
	var rows: Variant = hero.get_parent().get("_map_rows") if hero != null and is_instance_valid(hero) else null
	for i in range(_balls.size() - 1, -1, -1):
		var b: Dictionary = _balls[i]
		var ball: MeshInstance3D = b.node
		if not is_instance_valid(ball):
			_balls.remove_at(i)
			continue
		var step: Vector3 = (b.dir as Vector3) * speed * delta
		var next: Vector3 = (b.pos as Vector3) + step
		b.travel = float(b.travel) + step.length()
		b.size = float(b.size) + float(config.get("grow", 0.08)) * step.length()
		var cell := DungeonBuilder.cell_of(next)
		var blocked: bool = rows is Array and not DungeonBuilder.is_walkable(rows, cell.x, cell.y)
		if blocked or float(b.travel) > float(config.get("reach", 16.0)):
			_burst(b)
			_balls.remove_at(i)
			continue
		b.pos = next
		var size := float(b.size)
		ball.global_position = next + Vector3.UP * size * 0.5
		ball.scale = Vector3.ONE * size
		# Котиться: обертається навколо осі, поперечної до руху.
		var axis := Vector3.UP.cross(b.dir as Vector3).normalized()
		ball.rotate(axis, step.length() / maxf(size * 0.5, 0.1))
		if hero != null and is_instance_valid(hero) and not b.hit:
			var off := hero.global_position - next
			off.y = 0.0
			if off.length() < size * 0.5 + 0.45:
				b.hit = true
				if hero.take_damage(damage()):
					CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.8, COLOR, true)
					if hero.has_method("knock_down"):
						hero.knock_down((b.dir as Vector3) * 7.0, float(config.get("knock", 0.5)))
				_burst(b)
				_balls.remove_at(i)

func _burst(b: Dictionary) -> void:
	var ball: MeshInstance3D = b.node
	if not is_instance_valid(ball):
		return
	CombatVfx.smoke_puff(world(), ball.global_position, COLOR, 1.2 + float(b.size))
	CombatVfx.ground_hit(world(), b.pos, float(b.size))
	ball.queue_free()

func on_death() -> void:
	for b: Dictionary in _balls:
		_burst(b)
	_balls.clear()
