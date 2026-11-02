# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"
BS = chr(92)


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/enemy_3d.gd", [
    ('''var _charge_hit := false
''', '''var _charge_hit := false
## Таран за описом ("charge"): своя перезарядка (а не перерва між
## ударами), своя анімація бігу, збиває героя з ніг, після стіни —
## довше оглушення, і тоді кам'яний щит не захищає.
var _charge_cooldown_left := 0.0
var _wall_stunned := false
var _stun_stars: Node3D
'''),
    ('''	attack_cooldown = float(definition.get("cooldown", attack_cooldown))''', '''	attack_cooldown = float(definition.get("cooldown", attack_cooldown))
	if definition.get("tank", false):
		tank = true'''),
    ('''	if definition.has("pack"):
		_pack_left -= delta''', '''	_charge_cooldown_left -= delta
	if definition.has("pack"):
		_pack_left -= delta'''),
    ('''	_model.rotation.y = rotate_toward(_model.rotation.y, wanted, speed * get_physics_process_delta_time())''',
     '''	# Важкий щитоносець ("turn_factor") обертається повільно — його можна
	# обійти й ударити збоку чи ззаду.
	var turn := speed * float(definition.get("turn_factor", 1.0))
	_model.rotation.y = rotate_toward(_model.rotation.y, wanted, turn * get_physics_process_delta_time())'''),
    ('''	if _attack_left <= 0.0 and distance >= CHARGE_MIN_DISTANCE and distance <= CHARGE_MAX_DISTANCE ''' + BS + '''
			and _sees_player():
		_begin_charge()
		return
	_move_along_path(delta)''', '''	var ready := _charge_cooldown_left <= 0.0 if definition.has("charge") else _attack_left <= 0.0
	if ready and distance >= CHARGE_MIN_DISTANCE and distance <= CHARGE_MAX_DISTANCE and _sees_player():
		_begin_charge()
		return
	_move_along_path(delta)'''),
    ('''	_telegraph.rotation.y = atan2(_charge_dir.x, _charge_dir.z)
	_play_once(["Jump", "No", "Headbutt", "Punch"])''', '''	_telegraph.rotation.y = atan2(_charge_dir.x, _charge_dir.z)
	var charge: Dictionary = definition.get("charge", {})
	_charge_cooldown_left = float(charge.get("cooldown", 0.0))
	_play_once([String(charge.get("windup_anim", "Jump")), "Jump", "No", "Headbutt", "Punch"])'''),
    ('''			velocity.x = _charge_dir.x * CHARGE_SPEED
			velocity.z = _charge_dir.z * CHARGE_SPEED
			_play("Walk")
			var offset := _player.global_position - global_position
			offset.y = 0.0
			if not _charge_hit and offset.length() < 1.4:
				_charge_hit = true
				if _player.take_damage(damage * 1.3):
					var rig := get_tree().get_first_node_in_group(&"camera_rig")
					if rig != null:
						rig.shake(0.15)
			if is_on_wall():
				# Врізався в стіну — оглушений довше: вікно для контратаки.
				_charge_state = 3
				_charge_left = CHARGE_WALL_STUN
				velocity.x = 0.0
				velocity.z = 0.0
				CombatVfx.impact(get_parent(), global_position + Vector3.UP + _charge_dir * 0.8, HIT_COLOR, true)''', '''			var charge: Dictionary = definition.get("charge", {})
			velocity.x = _charge_dir.x * CHARGE_SPEED
			velocity.z = _charge_dir.z * CHARGE_SPEED
			_play(String(charge.get("anim", "Walk")))
			var offset := _player.global_position - global_position
			offset.y = 0.0
			if not _charge_hit and offset.length() < 1.4:
				_charge_hit = true
				if _player.take_damage(damage * 1.3):
					var rig := get_tree().get_first_node_in_group(&"camera_rig")
					if rig != null:
						rig.shake(0.15)
					# Збиває з ніг: героя відкидає вздовж тарана.
					if charge.has("knockdown") and _player.has_method("knock_down"):
						_player.knock_down(_charge_dir * float(charge.get("push", 7.0)), float(charge.knockdown))
			if is_on_wall():
				# Врізався в стіну — оглушений довше: вікно для контратаки.
				_charge_state = 3
				_charge_left = float(charge.get("wall_stun", CHARGE_WALL_STUN))
				velocity.x = 0.0
				velocity.z = 0.0
				CombatVfx.impact(get_parent(), global_position + Vector3.UP + _charge_dir * 0.8, HIT_COLOR, true)
				CombatVfx.shockwave(get_parent(), global_position + _charge_dir * 0.8, 1.6, Color(0.85, 0.8, 0.7, 0.8), 0.3)
				var rig := get_tree().get_first_node_in_group(&"camera_rig")
				if rig != null:
					rig.shake(0.12)
				if charge.has("wall_stun"):
					_set_wall_stunned(true)'''),
    ('''		3:
			velocity.x = 0.0
			velocity.z = 0.0
			_play("Idle")
			if _charge_left <= 0.0:
				_charge_state = 0''', '''		3:
			velocity.x = 0.0
			velocity.z = 0.0
			_play("Stunned" if _wall_stunned else "Idle")
			if _charge_left <= 0.0:
				_charge_state = 0
				_set_wall_stunned(false)'''),
    ('''	if stationary:
		knockback = Vector3.ZERO
	current_hp -= amount''', '''	if stationary:
		knockback = Vector3.ZERO
	var blocked := _shield_blocks()
	if blocked:
		amount *= float(definition.stone_shield.get("factor", 0.2))
		knockback *= 0.2
		CombatVfx.impact(get_parent(), global_position + Vector3.UP * target_height * 0.55 + _model_forward() * 0.6,
			Color(0.8, 0.8, 0.85), false)
	current_hp -= amount'''),
    ('''	if _windup_left <= 0.0:
		_play_once(["HitReact", "HitRecieve"])
	if current_hp <= 0.0:
		_die()''', '''	if _windup_left <= 0.0 and not _wall_stunned:
		_play_once(["Block", "HitReact"] if blocked else ["HitReact", "HitRecieve"])
	if current_hp <= 0.0:
		_die()

## Кам'яний щит ("stone_shield" в описі): удар спереду (герой у секторі
## arc перед ворогом) проходить лише частково. Оглушений об стіну —
## відкритий з усіх боків.
func _shield_blocks() -> bool:
	if not definition.has("stone_shield") or _wall_stunned or _player == null:
		return false
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() < 0.05:
		return false
	var arc := deg_to_rad(float(definition.stone_shield.get("arc", 70.0)))
	return _model_forward().angle_to(to_player.normalized()) <= arc

## Оглушений після стіни: над головою кружляють зірочки.
func _set_wall_stunned(stunned: bool) -> void:
	_wall_stunned = stunned
	if stunned and _stun_stars == null:
		_stun_stars = _make_stun_stars()
		add_child(_stun_stars)
		_stun_stars.position = Vector3(0, target_height + 0.25, 0)
	if _stun_stars != null:
		_stun_stars.visible = stunned
	if stunned:
		_cancel_windup()

static func _make_stun_stars() -> Node3D:
	var holder := Node3D.new()
	for i in 3:
		var star := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		sphere.radial_segments = 6
		sphere.rings = 3
		star.mesh = sphere
		star.material_override = CombatVfx.get_glow_material(Color(1.0, 0.9, 0.35))
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * i / 3.0
		star.position = Vector3(cos(angle), 0.0, sin(angle)) * 0.35
		holder.add_child(star)
	return holder'''),
])

patch("scenes/world/player_3d.gd", [
    ('''var _pull_applied := Vector3.ZERO
''', '''var _pull_applied := Vector3.ZERO
## Збили з ніг (таран щитоносця): відлітає, мить не керує рухом і не б'є.
var _knock_left := 0.0
var _knock_velocity := Vector3.ZERO
'''),
    ('''func _update_velocity(direction: Vector3, delta: float) -> void:
	velocity.x -= _pull_applied.x
	velocity.z -= _pull_applied.z
	_pull_applied = Vector3.ZERO''', '''func _update_velocity(direction: Vector3, delta: float) -> void:
	velocity.x -= _pull_applied.x
	velocity.z -= _pull_applied.z
	_pull_applied = Vector3.ZERO
	if _knock_left > 0.0:
		_knock_left -= delta
		_knock_velocity = _knock_velocity.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)
		velocity.x = _knock_velocity.x
		velocity.z = _knock_velocity.z
		return'''),
    ('''func attack() -> void:
	if _dead:
		return''', '''func attack() -> void:
	if _dead or _knock_left > 0.0:
		return'''),
    ('''func dodge() -> void:
	if _dead or _dodge_cooldown_left > 0.0 or _roll_left > 0.0:
		return''', '''func dodge() -> void:
	if _dead or _knock_left > 0.0 or _dodge_cooldown_left > 0.0 or _roll_left > 0.0:
		return'''),
    ('''func use_skill(index: int = 0) -> void:
	if _dead or _roll_left > 0.0 or index < 0 or index >= _skills.size():
		return''', '''func use_skill(index: int = 0) -> void:
	if _dead or _knock_left > 0.0 or _roll_left > 0.0 or index < 0 or index >= _skills.size():
		return'''),
    ('''## Воскресіння за відео (данж)''', '''## Збили з ніг: відкидає (push, м/с, гасне) і seconds секунд герой не
## керує рухом, не б'є й не котиться. Перекат, що вже йде, рятує.
func knock_down(push: Vector3, seconds: float) -> void:
	if _dead or _roll_left > 0.0:
		return
	_knock_left = seconds
	_knock_velocity = Vector3(push.x, 0.0, push.z)
	_attack_step = -1
	_abort_attacks()
	_fire("HitShot")
	CombatVfx.shockwave(get_parent(), global_position, 1.2, Color(0.9, 0.85, 0.7, 0.8), 0.3)

## Воскресіння за відео (данж)'''),
    ('''const REVIVE_SHIELD_COLOR := Color(1.0, 0.82, 0.4)''', '''const REVIVE_SHIELD_COLOR := Color(1.0, 0.82, 0.4)
## Як швидко гасне відкидання, коли героя збили з ніг (м/с за секунду).
const KNOCK_DECAY := 14.0'''),
])
print("patched")
