# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/abilities/enemy_ability.gd", [
    ('''func on_death() -> void:
	pass''', '''func on_death() -> void:
	pass

## Ворога вдарили (і він ще живий).
func on_damaged() -> void:
	pass'''),
])

patch("scenes/dungeon/abilities/enemy_abilities.gd", [
    ('''	"slime_trail": preload("res://scenes/dungeon/abilities/slime_trail_ability.gd"),
''', '''	"slime_trail": preload("res://scenes/dungeon/abilities/slime_trail_ability.gd"),
	"grasp": preload("res://scenes/dungeon/abilities/grasp_ability.gd"),
	"dark_shield": preload("res://scenes/dungeon/abilities/dark_shield_ability.gd"),
	"phase_step": preload("res://scenes/dungeon/abilities/phase_step_ability.gd"),
'''),
])

patch("scenes/dungeon/abilities/lob_ability.gd", [
    ('''func try_use(distance: float) -> bool:
	if distance < MIN_DISTANCE or distance > MAX_DISTANCE or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, WINDUP, Color(_color(), 0.85), 1.2)
	return true

func resolve() -> void:
	var hero := player()
	var target := hero.global_position''', '''## "aim_first": куди впаде, видно ще під час замаху — коло на місці
## падіння (а не під кидальником), і кидок летить туди ж.
var _aim := Vector3.INF
var _aim_marker: MeshInstance3D

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", MIN_DISTANCE)) or distance > MAX_DISTANCE or not enemy.sees_player():
		return false
	start_cooldown()
	if config.get("aim_first", false):
		_aim = player().global_position
		_clear_aim()
		_aim_marker = CombatVfx.make_telegraph(Color(_color(), 0.9), float(config.get("radius", 1.6)), PI, true)
		world().add_child(_aim_marker)
		_aim_marker.global_position = Vector3(_aim.x, DungeonBuilder.FLOOR_TOP + 0.05, _aim.z)
		var marker := _aim_marker
		var tween := marker.create_tween()
		tween.tween_method(func(value: float) -> void:
			marker.set_instance_shader_parameter(&"progress", value), 0.0, 0.4, WINDUP)
		enemy.get_tree().create_timer(WINDUP + 0.4, false).timeout.connect(_clear_aim)
		enemy.begin_special(id, WINDUP, Color(_color(), 0.0), 0.1)
	else:
		enemy.begin_special(id, WINDUP, Color(_color(), 0.85), 1.2)
	return true

func _clear_aim() -> void:
	if _aim_marker != null and is_instance_valid(_aim_marker):
		_aim_marker.queue_free()
	_aim_marker = null

func on_death() -> void:
	_clear_aim()

func resolve() -> void:
	var hero := player()
	var target := hero.global_position
	if _aim != Vector3.INF:
		target = _aim
		_aim = Vector3.INF
		_clear_aim()'''),
    ('''	if hero is CharacterBody3D:''', '''	if hero is CharacterBody3D and not config.get("aim_first", false):'''),
])

patch("scenes/dungeon/enemy_3d.gd", [
    ('''var _stun_stars: Node3D
''', '''var _stun_stars: Node3D
## Темний щит від чаклуна: скільки шкоди ще поглине і скільки секунд діє.
var _absorb := 0.0
var _absorb_left := 0.0
var _absorb_bubble: MeshInstance3D
'''),
    ('''	_charge_cooldown_left -= delta
''', '''	_charge_cooldown_left -= delta
	if _absorb_left > 0.0:
		_absorb_left -= delta
		if _absorb_left <= 0.0:
			_drop_absorb()
'''),
    ('''func face_player(speed: float) -> void:
	_face_player(speed)''', '''func face_player(speed: float) -> void:
	_face_player(speed)

func face_point(point: Vector3) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		_face(direction, 100.0)

## Темний щит (DarkShieldAbility): зелена сфера поглинає amount шкоди.
func add_absorb(amount: float, seconds: float, color: Color) -> void:
	_absorb = amount
	_absorb_left = seconds
	if _absorb_bubble == null:
		_absorb_bubble = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 16
		sphere.rings = 8
		_absorb_bubble.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_color = Color(color, 0.28)
		material.cull_mode = BaseMaterial3D.CULL_BACK
		_absorb_bubble.material_override = material
		_absorb_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_absorb_bubble)
	var size := maxf(target_height * 1.25, 1.4)
	_absorb_bubble.scale = Vector3.ONE * size
	_absorb_bubble.position = Vector3(0, target_height * 0.5, 0)
	_absorb_bubble.visible = true
	CombatVfx.shockwave(get_parent(), global_position, 1.5, color, 0.35)

func has_absorb() -> bool:
	return _absorb > 0.0

func _drop_absorb() -> void:
	_absorb = 0.0
	_absorb_left = 0.0
	if _absorb_bubble != null:
		_absorb_bubble.visible = false'''),
    ('''	var blocked := _shield_blocks()''', '''	if _absorb > 0.0:
		var soaked := minf(_absorb, amount)
		_absorb -= soaked
		amount -= soaked
		if _absorb <= 0.0:
			_drop_absorb()
			CombatVfx.impact(get_parent(), global_position + Vector3.UP * target_height * 0.5, Color(0.45, 1.0, 0.5), true)
	var blocked := _shield_blocks()'''),
    ('''	if _windup_left <= 0.0 and not _wall_stunned:
		_play_once(["Block", "HitReact"] if blocked else ["HitReact", "HitRecieve"])
	if current_hp <= 0.0:
		_die()
''', '''	if _windup_left <= 0.0 and not _wall_stunned:
		_play_once(["Block", "HitReact"] if blocked else ["HitReact", "HitRecieve"])
	if current_hp <= 0.0:
		_die()
		return
	for ability in abilities:
		ability.on_damaged()
'''),
    ('''func _process_ranged(distance: float, delta: float) -> void:
	if not _sees_player() or distance > attack_range:''', '''func _process_ranged(distance: float, delta: float) -> void:
	# Втеча ("flee"): герой підійшов близько — розвертається й тікає бігом.
	var flee: Dictionary = definition.get("flee", {})
	if not flee.is_empty() and distance < float(flee.get("distance", 4.5)):
		var away := global_position - _player.global_position
		away.y = 0.0
		away = away.normalized()
		var speed := move_speed * float(flee.get("speed", 1.3))
		velocity.x = move_toward(velocity.x, away.x * speed, 20.0 * delta)
		velocity.z = move_toward(velocity.z, away.z * speed, 20.0 * delta)
		_face(away, 14.0)
		_play("Run")
		return
	if not _sees_player() or distance > attack_range:'''),
    ('''		_play("Walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_face_player(10.0)
	_try_begin_windup()''', '''		_play("Walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_face_player(10.0)
	# "no_shot": звичайних пострілів немає — лише прийоми (палій кидає глечики).
	if not definition.get("no_shot", false):
		_try_begin_windup()'''),
])

patch("scenes/world/player_3d.gd", [
    ('''var _knock_left := 0.0
''', '''var _knock_left := 0.0
## Схопили кістяні руки (чаклун): стоїть на місці, але може бити.
var _rooted_left := 0.0
var _root_marker: MeshInstance3D
'''),
    ('''	if _knock_left > 0.0:
		_knock_left -= delta''', '''	if _rooted_left > 0.0:
		_rooted_left -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if _rooted_left <= 0.0 and _root_marker != null:
			_root_marker.visible = false
		return
	if _knock_left > 0.0:
		_knock_left -= delta'''),
    ('''func dodge() -> void:
	if _dead or _knock_left > 0.0''', '''func dodge() -> void:
	if _dead or _rooted_left > 0.0 or _knock_left > 0.0'''),
    ('''## Воскресіння за відео (данж)''', '''## Схопили (кістяні руки чаклуна): seconds секунд на місці — ні кроку, ні
## перекату, бити можна. Перекат, що вже йде, рятує. true — схопили.
func root(seconds: float) -> bool:
	if _dead or _roll_left > 0.0 or _invulnerable_left > 0.0 and _roll_guard_left > 0.0:
		return false
	_rooted_left = maxf(_rooted_left, seconds)
	if _root_marker == null:
		_root_marker = CombatVfx.make_ground_marker(Color(0.45, 1.0, 0.45, 0.6), 0.7)
		_root_marker.set_instance_shader_parameter(&"progress", 1.0)
		_root_marker.position.y = 0.05
		add_child(_root_marker)
	_root_marker.visible = true
	return true

func is_rooted() -> bool:
	return _rooted_left > 0.0

## Воскресіння за відео (данж)'''),
])

patch("scenes/dungeon/dungeon_levels.gd", [
    ('''				{"name": "Чаклун", "model": "res://assets/models/monsters/Wizard.glb", "kind": "ranged", "hp": 22.0, "damage": 6.0, "speed": 2.2, "height": 1.7, "xp": 4,
					"projectile": {"color": Color(0.75, 0.35, 1.0), "speed": 10.0, "volley": 1}},''', '''				# Орк-палій (модель гравця): тримається на відстані й кидає глечики
				# з олією — коло на місці падіння видно ще під час замаху, там 4 с
				# горить калюжа. Підійшов близько — тікає бігом. Глечик поки
				# заглушка (fire_jug.tscn) — чекає 3D-модель гравця.
				{"name": "Орк-палій", "model": "res://assets/models/monsters/orc_pyro.glb", "kind": "ranged",
					"hp": 22.0, "damage": 8.0, "speed": 2.6, "height": 1.8, "xp": 4, "no_shot": true,
					"attack_range": 9.0, "flee": {"distance": 4.5, "speed": 1.3},
					"special_anims": {"lob": ["Weapon"]},
					"abilities": [{"id": "lob", "cooldown": 3.5, "first": 1.0, "min": 4.5, "radius": 1.6, "pool": 4.0,
						"aim_first": true, "color": Color(1.0, 0.45, 0.1), "shell": "res://scenes/dungeon/hazards/fire_jug.tscn"}]},
				# Склепний чаклун (модель гравця) — підтримка, пріоритетна ціль:
				# піднімає кістяні руки, що тримають героя 1 с (відкотись), кладе
				# зелений щит на найближчого орка, вдарений — телепортується
				# (раз на 10 с). Скелет і анімації — scripts/blender/rig_warlock.py.
				{"name": "Склепний чаклун", "model": "res://assets/models/monsters/crypt_warlock.glb", "kind": "ranged",
					"hp": 24.0, "damage": 6.0, "speed": 2.0, "height": 1.85, "xp": 6, "no_elite": true,
					"projectile": {"color": Color(0.45, 1.0, 0.5), "speed": 9.0, "volley": 1},
					"special_anims": {"grasp": ["Cast"], "dark_shield": ["Support"]},
					"abilities": [
						{"id": "grasp", "cooldown": 8.0, "first": 3.0, "count": 2, "radius": 1.0, "tell": 1.0, "hold": 1.0, "damage": 0.5},
						{"id": "dark_shield", "cooldown": 7.0, "first": 1.5, "range": 10.0, "amount": 0.6, "seconds": 12.0, "target": "Орк"},
						{"id": "phase_step", "cooldown": 10.0, "first": 0.0, "min": 5.0, "max": 8.0}]},'''),
])
print("patched")
