extends EnemyAbility

## ВИТТЯ ЗГРАЇ (Пекельний пес). Пес зупиняється, задирає морду вгору й
## виє (windup) — від нього розходяться кільця жару. Усі пси поруч (range,
## і він сам) на time секунд швидші (haste), а лапи в них палають: за
## кожним лишаються вогняні сліди, що печуть героя. Бий того, хто виє,
## поки не довив, — або тікай від слідів, а не по них.
## Налаштування: windup, range, time, haste, damage.

const COLOR := Color(1.0, 0.45, 0.12)
const STEP := 0.45
const PATCH_LIFE := 2.2
const PATCH_RADIUS := 0.75

var _pack: Array = []
var _patches: Array = []
var _time_left := 0.0
var _step_left := 0.0

func _init() -> void:
	id = "pack_howl"
	cooldown = 14.0

func try_use(distance: float) -> bool:
	if distance > 12.0 or enemy.has_meta("howl_buff") or _time_left > 0.0:
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.8))
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	# Морда вгору: модель відхиляється назад і витягується.
	BossFx.gesture(enemy.get("_model") as Node3D, 32.0, 0.1, windup * 0.5, windup * 0.5)
	for i in 3:
		enemy.get_tree().create_timer(i * windup * 0.3).timeout.connect(func() -> void:
			if is_instance_valid(enemy) and enemy.is_alive():
				CombatVfx.shockwave(world(), enemy.global_position, 3.5 + i, COLOR, 0.35))
	return true

func resolve() -> void:
	var reach := float(config.get("range", 10.0))
	var haste := float(config.get("haste", 1.4))
	var time := float(config.get("time", 5.0))
	_pack.clear()
	for node in enemy.get_parent().get_children():
		var other := node as Enemy3D
		if other == null or not other.is_alive() or other.display_name != enemy.display_name:
			continue
		if other.global_position.distance_to(enemy.global_position) > reach or other.has_meta("howl_buff"):
			continue
		other.set_meta("howl_buff", other.move_speed)
		other.move_speed *= haste
		other.alert()
		other.hunting = true
		var paws := Fx.make_particles("flame_06", Color(1.0, 0.55, 0.15, 0.9), 12, 0.4, 0.4, true)
		paws.direction = Vector3.UP
		paws.gravity = Vector3.ZERO
		paws.initial_velocity_min = 0.8
		paws.initial_velocity_max = 1.6
		paws.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		paws.emission_sphere_radius = 0.4
		other.add_child(paws)
		paws.position = Vector3.UP * 0.2
		_pack.append({"id": other.get_instance_id(), "paws": paws})
	_time_left = time
	_step_left = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	if _time_left > 0.0:
		_time_left -= delta
		_step_left -= delta
		if _step_left <= 0.0:
			_step_left = STEP
			for member: Dictionary in _pack:
				var dog := instance_from_id(int(member.id)) as Enemy3D
				if dog != null and is_instance_valid(dog) and dog.is_alive():
					_add_patch(dog.global_position)
		if _time_left <= 0.0:
			_end()
	var hero := player()
	for i in range(_patches.size() - 1, -1, -1):
		var p: Dictionary = _patches[i]
		p.left = float(p.left) - delta
		p.tick = float(p.tick) - delta
		var node: MeshInstance3D = p.node
		if is_instance_valid(node):
			BossFx.set_heat(node, clampf(float(p.left) / PATCH_LIFE, 0.0, 1.0), clampf(float(p.left) / 0.6, 0.0, 0.9))
		if hero != null and is_instance_valid(hero) and float(p.tick) <= 0.0:
			var off: Vector3 = hero.global_position - (p.spot as Vector3)
			off.y = 0.0
			if off.length() < PATCH_RADIUS:
				p.tick = 0.5
				hero.take_damage(damage())
		if float(p.left) <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			_patches.remove_at(i)

func _add_patch(position: Vector3) -> void:
	var spot := Vector3(position.x, DungeonBuilder.FLOOR_TOP + 0.04, position.z)
	# Новий слід не ліпимо поверх свіжого.
	for p: Dictionary in _patches:
		if (p.spot as Vector3).distance_to(spot) < 0.6:
			return
	var node := BossFx.floor_disc(BossFx.lava_material(1.0, 0.9), PATCH_RADIUS)
	world().add_child(node)
	node.global_position = spot
	_patches.append({"node": node, "spot": spot, "left": PATCH_LIFE, "tick": 0.0})

func _end() -> void:
	_time_left = 0.0
	for member: Dictionary in _pack:
		var dog := instance_from_id(int(member.id)) as Enemy3D
		if dog != null and is_instance_valid(dog) and dog.has_meta("howl_buff"):
			dog.move_speed = float(dog.get_meta("howl_buff"))
			dog.remove_meta("howl_buff")
		if is_instance_valid(member.paws):
			(member.paws as Node).queue_free()
	_pack.clear()

func on_death() -> void:
	_end()
	for p: Dictionary in _patches:
		if is_instance_valid(p.node):
			(p.node as Node).queue_free()
	_patches.clear()
