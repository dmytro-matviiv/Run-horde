extends EnemyAbility

## ГАК-ЛАНЦЮГ (Гном-клепальник, Кузня Присмерку). Побачив героя на
## відстані — смуга на підлозі показує, куди полетить гак; гак летить по
## прямій, і якщо зачепив (а герой не відкотився) — ривком підтягує героя
## до гнома, і наступний удар молотом сильніший (empower).
##
## Налаштування: min, max (відстань), speed (м/с гака), windup, damage
## (частка шкоди гнома за влучання), empower (множник), empower_time.

const COLOR := Color(1.0, 0.55, 0.2, 0.85)
const HIT_RADIUS := 0.75
## Наскільки близько перед гномом зупиняється підтягнутий герой.
const STOP_GAP := 1.2

var _flying := false
var _direction := Vector3.ZERO
var _travel := 0.0
var _length := 0.0
var _hook: Node3D
var _chain: MeshInstance3D
var _line: MeshInstance3D

func _init() -> void:
	id = "hook"
	cooldown = 7.0

func is_busy() -> bool:
	return _flying

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 3.0)) or distance > float(config.get("max", 8.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	var to_player := player().global_position - enemy.global_position
	to_player.y = 0.0
	_direction = to_player.normalized()
	_length = float(config.get("max", 8.0)) + 0.5
	_line = CombatVfx.make_line_telegraph(COLOR, _length, 0.9, "chevrons")
	world().add_child(_line)
	_line.global_position = Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP + 0.05, enemy.global_position.z) + _direction * _length * 0.5
	_line.rotation.y = atan2(_direction.x, _direction.z)
	# Замах можуть збити — смуга сама зникне.
	var line := _line
	enemy.get_tree().create_timer(float(config.get("windup", 0.6)) + 0.4, false).timeout.connect(func() -> void:
		if is_instance_valid(line):
			line.queue_free())
	enemy.face_point(enemy.global_position + _direction)
	enemy.begin_special(id, float(config.get("windup", 0.6)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_clear_line()
	_flying = true
	_travel = 0.0
	enemy.hold_still(0.8)
	_hook = Node3D.new()
	var head := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.08
	mesh.outer_radius = 0.2
	mesh.rings = 8
	mesh.ring_segments = 6
	head.mesh = mesh
	head.material_override = CombatVfx.get_glow_material(Color(0.75, 0.72, 0.7))
	head.rotation.x = PI * 0.5
	_hook.add_child(head)
	world().add_child(_hook)
	_chain = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.07, 1.0)
	_chain.mesh = box
	_chain.material_override = CombatVfx.get_glow_material(Color(0.55, 0.5, 0.48))
	_chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world().add_child(_chain)
	_place(0.0)

func tick(delta: float) -> void:
	super.tick(delta)
	if not _flying:
		return
	_travel += float(config.get("speed", 18.0)) * delta
	_place(_travel)
	var hero := player()
	if hero != null and is_instance_valid(hero):
		var offset := hero.global_position - _hook.global_position
		offset.y = 0.0
		if offset.length() <= HIT_RADIUS:
			_grab(hero)
			return
	var query := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP, _hook.global_position)
	query.collision_mask = 1
	if _travel >= _length or not enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		_stop()

func _place(distance: float) -> void:
	var hand := enemy.global_position + Vector3.UP * enemy.target_height * 0.55
	var tip := enemy.global_position + _direction * distance + Vector3.UP * enemy.target_height * 0.45
	_hook.global_position = tip
	var span := tip - hand
	_chain.global_position = hand + span * 0.5
	if span.length() > 0.05:
		_chain.look_at(tip, Vector3.UP)
	_chain.scale = Vector3(1.0, 1.0, maxf(span.length(), 0.05))

func _grab(hero: Node3D) -> void:
	if hero.take_damage(damage()):
		# Ривок: герой їде до гнома (knock_down з поштовхом, що згасає за
		# KNOCK_DECAY — швидкість підібрана під відстань).
		var to_enemy := enemy.global_position - hero.global_position
		to_enemy.y = 0.0
		var distance := maxf(to_enemy.length() - STOP_GAP, 0.0)
		if hero.has_method("knock_down") and distance > 0.2:
			var speed := sqrt(2.0 * 14.0 * distance)
			hero.knock_down(to_enemy.normalized() * speed, 0.45)
		enemy.apply_empower(float(config.get("empower", 1.6)), float(config.get("empower_time", 3.0)))
		enemy.play_once(["Pull", "Weapon"])
		CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
	_stop()

func on_death() -> void:
	_stop()
	_clear_line()

func _stop() -> void:
	_flying = false
	if _hook != null and is_instance_valid(_hook):
		_hook.queue_free()
	if _chain != null and is_instance_valid(_chain):
		_chain.queue_free()
	_hook = null
	_chain = null

func _clear_line() -> void:
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	_line = null
