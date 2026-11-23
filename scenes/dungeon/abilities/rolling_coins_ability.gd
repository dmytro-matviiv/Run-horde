extends EnemyAbility

## КОТЯТЬСЯ МОНЕТИ (Золотий Скупар). Бос сипле зі свого мішка велетенські
## золоті монети: на підлозі смуги-попередження (warn с), потім по кожній
## котиться монета (speed м/с) через усю залу. Зачепила — шкода й збиває
## з ніг. Смуги — віялом на героя, з проміжками, куди можна стати.
## Налаштування: count, spread (градуси між смугами), length, speed, warn.

const COLOR := Color(1.0, 0.8, 0.25, 0.9)
const HIT_RADIUS := 1.0

class Coin extends Node3D:
	var direction := Vector3.FORWARD
	var speed := 9.0
	var travel := 16.0
	var target: Node3D
	var hit_damage := 10.0
	var hit := false
	var _disc: MeshInstance3D
	var _aimed := false

	func _ready() -> void:
		_disc = MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.9
		mesh.bottom_radius = 0.9
		mesh.height = 0.22
		mesh.radial_segments = 16
		mesh.rings = 1
		_disc.mesh = mesh
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(1.0, 0.78, 0.3)
		gold.metallic = 0.85
		gold.roughness = 0.3
		gold.emission_enabled = true
		gold.emission = Color(0.5, 0.35, 0.05)
		_disc.material_override = gold
		_disc.rotation.z = PI * 0.5
		add_child(_disc)
		# Карбування: вищий обідок і темніший відбиток корони посередині.
		var rim := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.78
		torus.outer_radius = 0.92
		torus.rings = 20
		torus.ring_segments = 4
		rim.mesh = torus
		rim.material_override = gold
		rim.scale = Vector3(1.0, 2.2, 1.0)
		_disc.add_child(rim)
		var stamp := MeshInstance3D.new()
		var face := CylinderMesh.new()
		face.top_radius = 0.42
		face.bottom_radius = 0.42
		face.height = 0.26
		face.radial_segments = 6
		face.rings = 1
		stamp.mesh = face
		var dark := gold.duplicate() as StandardMaterial3D
		dark.albedo_color = Color(0.75, 0.52, 0.15)
		stamp.material_override = dark
		_disc.add_child(stamp)
		var shine := CombatVfx.make_trail(Color(1.0, 0.85, 0.4), 0.35)
		shine.amount = 8
		add_child(shine)

	func _physics_process(delta: float) -> void:
		if not _aimed:
			# Ребром уперед: вісь диска (локальна X) — поперек руху.
			_aimed = true
			look_at(global_position + direction, Vector3.UP)
		var step := speed * delta
		global_position += direction * step
		travel -= step
		_disc.rotate(Vector3.RIGHT, -step / 0.9)
		if not hit and target != null and is_instance_valid(target):
			var offset := target.global_position - global_position
			offset.y = 0.0
			if offset.length() <= HIT_RADIUS and target.take_damage(hit_damage):
				hit = true
				if target.has_method("knock_down"):
					target.knock_down(direction * 8.0, 0.6)
		if travel <= 0.0:
			CombatVfx.impact(get_parent(), global_position, COLOR, false)
			queue_free()

var _pending: Array = []

func _init() -> void:
	id = "rolling_coins"
	cooldown = 10.0

func try_use(_distance: float) -> bool:
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.7)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var count := int(config.get("count", 3)) + (1 if enemy.phases != null and enemy.phases.phase >= 2 else 0)
	var length := float(config.get("length", 16.0))
	var to := hero.global_position - enemy.global_position
	to.y = 0.0
	var aim := to.normalized() if to.length() > 0.1 else enemy.model_forward()
	var spread := deg_to_rad(float(config.get("spread", 22.0)))
	var warn := float(config.get("warn", 0.9))
	var start := Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP, enemy.global_position.z)
	for i in count:
		var direction := aim.rotated(Vector3.UP, (i - (count - 1) * 0.5) * spread)
		var line := CombatVfx.make_line_telegraph(COLOR, length, 1.6, "chevrons")
		world().add_child(line)
		line.global_position = start + direction * length * 0.5 + Vector3.UP * 0.05
		line.rotation.y = atan2(direction.x, direction.z)
		_pending.append({"line": line, "direction": direction, "at": warn + i * 0.15, "total": warn + i * 0.15})

func tick(delta: float) -> void:
	super.tick(delta)
	for item: Dictionary in _pending.duplicate():
		item.at = float(item.at) - delta
		var line: MeshInstance3D = item.line
		if is_instance_valid(line):
			CombatVfx.set_param(line, &"progress", clampf(1.0 - float(item.at) / float(item.total), 0.0, 1.0))
		if float(item.at) > 0.0:
			continue
		_pending.erase(item)
		if is_instance_valid(line):
			line.queue_free()
		var coin := Coin.new()
		coin.direction = item.direction
		coin.speed = float(config.get("speed", 9.0))
		coin.travel = float(config.get("length", 16.0))
		coin.target = player()
		coin.hit_damage = damage()
		world().add_child(coin)
		coin.global_position = Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP + 0.9, enemy.global_position.z) + item.direction * 1.2

func on_death() -> void:
	for item: Dictionary in _pending:
		if is_instance_valid(item.line):
			item.line.queue_free()
	_pending.clear()
