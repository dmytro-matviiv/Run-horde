# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/health_bar_3d.gd", [
    ('''func set_ratio(ratio: float) -> void:''', '''## Інший колір смужки (щит голема — жовтий, далі здоров'я — червоне).
func set_color(color: Color) -> void:
	if _bar != null:
		_bar.set_instance_shader_parameter(&"fill_color", color)
	_ratio = 1.0
	_trail = 1.0
	_push()

func set_ratio(ratio: float) -> void:'''),
])

patch("scenes/world/player_3d.gd", [
    ('''	enemy.take_damage(amount, knockback * _knockback_factor, crit, heavy)''',
     '''	enemy.last_hit_source = source
	enemy.take_damage(amount, knockback * _knockback_factor, crit, heavy)'''),
])

patch("scenes/combat/enemy_projectile.gd", [
    ('''var on_hit: Callable
''', '''var on_hit: Callable
## "spear" — крижаний спис: довгий кристал, летить вістрям уперед.
var shape := ""
'''),
    ('''func _ready() -> void:
	_core = MeshInstance3D.new()
	_core.mesh = _get_core_mesh()''', '''func _ready() -> void:
	_core = MeshInstance3D.new()
	_core.mesh = _get_spear_mesh() if shape == "spear" else _get_core_mesh()
	if shape == "spear":
		# Кристал уздовж Y — кладемо вістрям уперед (-Z вузла).
		_core.rotation.x = -PI * 0.5'''),
    ('''	_velocity = direction.normalized() * speed
	reparent(world, true)
	scale = Vector3.ONE
	_launched = true''', '''	_velocity = direction.normalized() * speed
	reparent(world, true)
	scale = Vector3.ONE
	_launched = true
	if shape == "spear" and _velocity.length() > 0.01:
		look_at(global_position + _velocity, Vector3.UP)'''),
    ('''## Наскільки снаряд "набухнув" під час замаху (0..1).''', '''static var _spear_mesh: CylinderMesh

static func _get_spear_mesh() -> CylinderMesh:
	if _spear_mesh == null:
		_spear_mesh = CylinderMesh.new()
		_spear_mesh.top_radius = 0.0
		_spear_mesh.bottom_radius = 0.09
		_spear_mesh.height = 0.95
		_spear_mesh.radial_segments = 5
		_spear_mesh.rings = 1
	return _spear_mesh

## Наскільки снаряд "набухнув" під час замаху (0..1).'''),
])

patch("scenes/dungeon/hazards/hazard_ring.gd", [
    ('''static func spawn(world: Node, center: Vector3, player: Node3D, max_radius: float, speed: float, damage: float,
		color: Color, owner: Enemy3D = null) -> HazardRing:
	var ring := HazardRing.new()''', '''## Скільки секунд кільце тримає героя вмерзлим на місці (0 — не тримає).
var freeze := 0.0

static func spawn(world: Node, center: Vector3, player: Node3D, max_radius: float, speed: float, damage: float,
		color: Color, owner: Enemy3D = null) -> HazardRing:
	var ring := HazardRing.new()'''),
    ('''		_hit = true
		_player.take_damage(_damage)''', '''		_hit = true
		if _player.take_damage(_damage) and freeze > 0.0 and _player.has_method("root"):
			_player.root(freeze)'''),
])

patch("scenes/dungeon/abilities/ring_slam_ability.gd", [
    ('''	HazardRing.spawn(world(), enemy.global_position, player(), float(config.get("radius", 12.0)),
		float(config.get("speed", 8.0)), damage() * 1.2, _color(), enemy)''', '''	var ring := HazardRing.spawn(world(), enemy.global_position, player(), float(config.get("radius", 12.0)),
		float(config.get("speed", 8.0)), damage() * 1.2, _color(), enemy)
	ring.freeze = float(config.get("freeze", 0.0))'''),
    ('''	enemy.begin_special(id, WINDUP, Color(_color(), 0.85), 3.0)''',
     '''	enemy.begin_special(id, float(config.get("windup", WINDUP)), Color(_color(), 0.85), 3.0)'''),
])

patch("scenes/dungeon/enemy_3d.gd", [
    ('''var _absorb := 0.0
''', '''var _absorb := 0.0
## Хто вдарив останнім (Player3D.deal_damage: &"weapon" чи id здібності).
var last_hit_source: StringName = &""
## Крижаний щит голема ("ice_shield"): спершу б'ють щит (жовта смуга), поки
## він цілий — здоров'я не міняється; вогонь розтоплює його одразу, і далі
## голем отримує більше ("melt_vuln").
var _shield_hp := 0.0
var _shield_max := 0.0
var _damage_taken := 1.0
## Морозна аура ("frost_aura"): поруч — герой повільніший.
var _aura_left := 0.0
var _aura_marker: MeshInstance3D
## Прикидається статуєю ("dormant"): стоїть кам'яний, доки герой не підійде.
var _dormant := false
var _visor: MeshInstance3D
## Скільки ще живе (стіна льоду: "lifetime").
var _life_left := -1.0
## Невразливий (дракон у небі).
var invulnerable := false
'''),
    # take_damage: invulnerable, shield, melt, wall-stun x2, dormant wake
    ('''func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, crit: bool = false, heavy: bool = false) -> void:
	if _dying or _hidden:
		return''', '''func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, crit: bool = false, heavy: bool = false) -> void:
	if _dying or _hidden or invulnerable:
		return
	if _dormant:
		_wake()
	# Вогонь розтоплює крижаний щит одразу, і далі голем вразливіший.
	if _shield_max > 0.0 and String(last_hit_source) in ["fire_ring", "phoenix"] and _damage_taken == 1.0:
		_damage_taken = float(definition.ice_shield.get("melt_vuln", 1.3))
		if _shield_hp > 0.0:
			_break_shield(true)
	amount *= _damage_taken
	# Протаранив стіну — подвійна шкода ("stun_damage" у "charge").
	if _wall_stunned:
		amount *= float(definition.get("charge", {}).get("stun_damage", 1.0))
	if _shield_hp > 0.0:
		_shield_hp = maxf(_shield_hp - amount, 0.0)
		if _health_bar != null:
			_health_bar.set_ratio(_shield_hp / _shield_max)
			_health_bar.flash()
		CombatVfx.impact(get_parent(), global_position + Vector3.UP * target_height * 0.55, Color(1.0, 0.85, 0.35), false)
		if _shield_hp <= 0.0:
			_break_shield(false)
		return'''),
    ('''func _die() -> void:
	if elite != null:
		elite.on_death()''', '''## Щит голема розбито (або розтоплено вогнем): смужка стає червоною.
func _break_shield(melted: bool) -> void:
	_shield_hp = 0.0
	if _health_bar != null:
		_health_bar.set_color(ENEMY_BAR_COLOR)
		_health_bar.set_ratio(current_hp / max_hp)
	var color := Color(1.0, 0.55, 0.2) if melted else Color(0.7, 0.9, 1.0)
	CombatVfx.impact(get_parent(), global_position + Vector3.UP * target_height * 0.6, color, true)
	CombatVfx.shockwave(get_parent(), global_position, 2.4, color, 0.4)

## Вартовий оживає: руни спалахують, кам'яна шкіра сходить, і він б'є з
## розвороту по колу.
func _wake() -> void:
	if not _dormant:
		return
	_dormant = false
	_aggro = true
	_repath_left = 0.0
	for node in _model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_overlay = null
	if _visor != null:
		_visor.queue_free()
		_visor = null
	var color := Color(0.45, 0.9, 1.0)
	CombatVfx.shockwave(get_parent(), global_position, 3.0, color, 0.4)
	CombatVfx.impact(get_parent(), global_position + Vector3.UP * target_height * 0.8, color, true)
	_play_once(["Wake", "Weapon"])
	_hold_still(0.8)
	var dormant: Dictionary = definition.get("dormant", {})
	get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
		if _dying or _player == null or not is_instance_valid(_player):
			return
		var offset := _player.global_position - global_position
		offset.y = 0.0
		if offset.length() <= float(dormant.get("spin_radius", 2.8)):
			_player.take_damage(damage * float(dormant.get("spin_damage", 1.2))))

## Кам'яна "шкіра" статуї й ледь яскравіший візор — єдина підказка.
func _make_dormant() -> void:
	_dormant = true
	var stone := StandardMaterial3D.new()
	stone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stone.albedo_color = Color(0.72, 0.8, 0.88, 0.78)
	stone.roughness = 1.0
	for node in _model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_overlay = stone
	var dormant: Dictionary = definition.dormant
	_visor = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	sphere.radial_segments = 8
	sphere.rings = 4
	_visor.mesh = sphere
	_visor.material_override = CombatVfx.get_glow_material(Color(0.35, 0.8, 1.0))
	_visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visor)
	_visor.position = Vector3(0, target_height * float(dormant.get("visor_height", 0.88)), 0) + _model_forward() * float(dormant.get("visor_forward", 0.12)) * target_height
	if _animation != null:
		_animation.stop()

func is_dormant() -> bool:
	return _dormant

func _die() -> void:
	if elite != null:
		elite.on_death()'''),
    # physics: dormant, aura, lifetime
    ('''	if stationary:
		_process_stationary(delta)
		return

	var distance := global_position.distance_to(_player.global_position)''', '''	if _life_left > 0.0:
		_life_left -= delta
		if _life_left <= 0.0:
			take_damage(1.0e9)
			return
	if stationary:
		_process_stationary(delta)
		return

	var distance := global_position.distance_to(_player.global_position)
	if _dormant:
		velocity = Vector3.ZERO
		if distance <= float(definition.dormant.get("wake", 3.5)):
			_wake()
		return
	if definition.has("frost_aura"):
		_tick_frost_aura(delta, distance)'''),
    ('''## Ворог опинився НА чомусь''', '''## Морозна аура: герой поруч — повільніший; під ворогом інеєве коло.
func _tick_frost_aura(delta: float, distance: float) -> void:
	var aura_cfg: Dictionary = definition.frost_aura
	var radius := float(aura_cfg.get("radius", 3.0))
	if _aura_marker == null:
		_aura_marker = CombatVfx.make_ground_marker(Color(0.6, 0.85, 1.0, 0.3), radius)
		_aura_marker.set_instance_shader_parameter(&"progress", 1.0)
		add_child(_aura_marker)
		_aura_marker.position = Vector3(0, 0.05, 0)
	_aura_left -= delta
	if _aura_left > 0.0:
		return
	_aura_left = 0.25
	if distance <= radius and _player.has_method("apply_slow"):
		_player.apply_slow(float(aura_cfg.get("slow", 0.75)), 0.4)

## Ворог опинився НА чомусь'''),
    # setup: shield, dormant, blocker, lifetime, facing
    ('''	_add_health_bar()
	_add_screen_notifier()''', '''	_add_health_bar()
	_add_screen_notifier()
	if definition.has("ice_shield"):
		_shield_max = max_hp * float(definition.ice_shield.get("ratio", 0.6))
		_shield_hp = _shield_max
		if _health_bar != null:
			_health_bar.set_color(Color(1.0, 0.82, 0.25))
	if definition.has("face_yaw"):
		_model.rotation.y = float(definition.face_yaw)
	if definition.has("dormant"):
		_make_dormant.call_deferred()
	if definition.has("lifetime"):
		_life_left = float(definition.lifetime)
	# Тверда перешкода (стіна льоду): героя й ворогів не пропускає.
	if definition.has("blocker"):
		var size: Vector3 = definition.blocker
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = Vector3(0, size.y * 0.5, 0)
		body.add_child(shape)
		body.rotation.y = float(definition.get("face_yaw", 0.0))
		add_child(body)'''),
    ('''		_loop(["Idle", "Walk", "Run", "Flying_Idle", "Fast_Flying", "Turn"])''',
     '''		_loop(["Idle", "Walk", "Run", "Flying_Idle", "Fast_Flying", "Turn", "Fly", "Spin", "Unlock", "Charge", "Stunned", "Idle_Rage"])'''),
    # projectiles shape
    ('''		_charging_shot = EnemyProjectile.create(damage, projectile_color, projectile_speed)''',
     '''		_charging_shot = EnemyProjectile.create(damage, projectile_color, projectile_speed)
		_charging_shot.shape = String(definition.get("projectile", {}).get("shape", ""))'''),
    ('''	var extra := EnemyProjectile.create(damage, projectile_color, projectile_speed)''',
     '''	var extra := EnemyProjectile.create(damage, projectile_color, projectile_speed)
	extra.shape = String(definition.get("projectile", {}).get("shape", ""))'''),
    # melee arc
    ('''		_show_telegraph(_melee_reach(), deg_to_rad(55.0), TELEGRAPH_COLOR)''',
     '''		_show_telegraph(_melee_reach(), deg_to_rad(float(definition.get("attack_arc", 55.0))), TELEGRAPH_COLOR)'''),
    ('''	var in_front := offset.length() < 0.5 or _model_forward().angle_to(offset.normalized()) <= deg_to_rad(65.0)''',
     '''	var in_front := offset.length() < 0.5 or _model_forward().angle_to(offset.normalized()) <= deg_to_rad(float(definition.get("attack_arc", 55.0)) + 10.0)'''),
    # charge windup configurable
    ('''	_charge_left = CHARGE_WINDUP''', '''	_charge_left = _charge_windup()'''),
    ('''				_telegraph.set_instance_shader_parameter(&"progress", 1.0 - _charge_left / CHARGE_WINDUP)''',
     '''				_telegraph.set_instance_shader_parameter(&"progress", 1.0 - _charge_left / _charge_windup())'''),
    ('''## Радіус тіла (як у капсули, яку ставить данж).''', '''## Прицілювання тарана ("windup" у "charge").
func _charge_windup() -> float:
	return float(definition.get("charge", {}).get("windup", CHARGE_WINDUP))

## Радіус тіла (як у капсули, яку ставить данж).'''),
])
print("patched")
