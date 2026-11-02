# -*- coding: utf-8 -*-
# Нові вороги: вибуховий, таран, голем, залп, боси-закликач і дракон.
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:80])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


# --- Лінія на підлозі для тарана ---
patch('scenes/combat/combat_vfx.gd', [
    ('''## Спалах поверх моделі, коли в неї влучили.''',
     '''## Смуга на підлозі: куди зараз розженеться таран. Заповнюється від
## нього вперед — видно, скільки лишилось до ривка.
const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.3, 0.2, 1.0);
instance uniform float progress = 0.0;

void fragment() {
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float border = 1.0 - smoothstep(0.03, 0.08, edge);
	float fill = step(UV.y, progress);
	ALBEDO = color.rgb;
	ALPHA = clamp(max(border * 0.9, fill * 0.42 + 0.08), 0.0, 1.0) * color.a;
}
"""

## Спалах поверх моделі, коли в неї влучили.'''),
    ('''static var _ring_mesh: PlaneMesh''',
     '''static var _ring_mesh: PlaneMesh
static var _line_materials: Dictionary = {}'''),
    ('''## Хвиля, що розбігається від центру''',
     '''## Смуга-попередження для тарана. length — довжина ривку, width — ширина.
static func make_line_marker(color: Color, length: float, width: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _get_ring_mesh()
	instance.material_override = _get_material(_line_materials, LINE_SHADER, color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.scale = Vector3(width, 1.0, length)
	instance.set_instance_shader_parameter(&"progress", 0.0)
	return instance

## Хвиля, що розбігається від центру'''),
])

# --- Снаряд: колір і швидкість задає ворог ---
patch('scenes/combat/enemy_projectile.gd', [
    ('''static var _core_material: StandardMaterial3D
static var _core_mesh: SphereMesh

var damage := 6.0''',
     '''static var _core_materials: Dictionary = {}
static var _core_mesh: SphereMesh

var damage := 6.0
var color := COLOR
var speed := SPEED'''),
    ('''static func create(shot_damage: float) -> EnemyProjectile:
	var projectile := EnemyProjectile.new()
	projectile.damage = shot_damage
	return projectile''',
     '''## Колір і швидкість — свої в кожного стрільця: отруйні плювки в
## печерах повільні й зелені, крижані стріли в цитаделі швидкі й сині.
static func create(shot_damage: float, shot_color: Color = COLOR, shot_speed: float = SPEED) -> EnemyProjectile:
	var projectile := EnemyProjectile.new()
	projectile.damage = shot_damage
	projectile.color = shot_color
	projectile.speed = shot_speed
	return projectile'''),
    ('''	_core.material_override = _get_core_material()''',
     '''	_core.material_override = _get_core_material(color)'''),
    ('''	_velocity = direction.normalized() * SPEED''',
     '''	_velocity = direction.normalized() * speed'''),
    ('''	CombatVfx.impact(get_parent(), position, COLOR, false)''',
     '''	CombatVfx.impact(get_parent(), position, color, false)'''),
    ('''static func _get_core_material() -> StandardMaterial3D:
	if _core_material == null:
		_core_material = StandardMaterial3D.new()
		_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core_material.albedo_color = COLOR.lightened(0.35)
		_core_material.emission_enabled = true
		_core_material.emission = COLOR
		_core_material.emission_energy_multiplier = 3.0
		_core_material.rim_enabled = false
	return _core_material''',
     '''static func _get_core_material(tint: Color) -> StandardMaterial3D:
	var key := tint.to_html()
	if _core_materials.has(key):
		return _core_materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint.lightened(0.35)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 3.0
	_core_materials[key] = material
	return material'''),
])

# --- Ворог ---
patch('scenes/dungeon/enemy_3d.gd', [
    ('''signal died(position: Vector3, xp_reward: int)

enum Kind {MELEE, RANGED, BOSS}''',
     '''signal died(position: Vector3, xp_reward: int)
## Бос-закликач просить данж привести йому підмогу.
signal summon_requested(position: Vector3, count: int)

## MELEE — б'є впритул, RANGED — стріляє, BOSS — бос, EXPLODER — біжить
## до героя й вибухає, CHARGER — розганяється по прямій.
## Голем — це MELEE з tank = true.
enum Kind {MELEE, RANGED, BOSS, EXPLODER, CHARGER}'''),
    ('''## Стрілець тримається не ближче за це.
const RANGED_MIN_DISTANCE := 3.5''',
     '''## Стрілець тримається не ближче за це.
const RANGED_MIN_DISTANCE := 3.5

## ВИБУХОВИЙ: підбіг — запалює ґніт (коло на підлозі), за мить вибухає.
## Убив раніше — вибуху не буде: це й є спосіб грати проти нього.
const FUSE_DISTANCE := 2.2
const FUSE_TIME := 0.95
const EXPLODE_RADIUS := 3.0
const EXPLODE_COLOR := Color(1.0, 0.55, 0.15, 0.9)

## ТАРАН: показує смугу, куди розженеться, і мчить по ній. Ухилитись —
## крок убік. Врізався в стіну — довше оговтується.
const CHARGE_WINDUP := 0.85
const CHARGE_SPEED := 13.0
const CHARGE_TIME := 0.7
const CHARGE_RECOVER := 1.0
const CHARGE_WALL_STUN := 1.6
const CHARGE_MIN_DISTANCE := 3.5
const CHARGE_MAX_DISTANCE := 13.0
const CHARGE_COLOR := Color(1.0, 0.3, 0.2, 0.85)

## Боси.
const SUMMON_COOLDOWN := 9.0
const SUMMON_COUNT := 3
const SUMMON_COLOR := Color(0.5, 1.0, 0.4, 0.9)
const VOLLEY_COOLDOWN := 5.0
const DRAGON_CHARGE_COOLDOWN := 7.5'''),
    ('''## Зріст ворога на екрані в метрах. Моделі з різних наборів приходять
## у зовсім різному масштабі, тож приводимо кожну до потрібного розміру.
@export var target_height := 1.7''',
     '''## Зріст ворога на екрані в метрах. Моделі з різних наборів приходять
## у зовсім різному масштабі, тож приводимо кожну до потрібного розміру.
@export var target_height := 1.7

## Налаштування з опису рівня (DungeonLevels), див. configure().
var display_name := ""
var tank := false
var slam_every := 0
var boss_style := "demon"
## Скільки метрів ворог ширяє над землею (летючі істоти).
var hover := 0.0
var projectile_color := Color(0.75, 0.35, 1.0)
var projectile_speed := 10.0
var volley := 1

var _fuse_left := -1.0
var _flash_left := 0.0
## 0 — нічого, 1 — прицілюється, 2 — мчить, 3 — оговтується.
var _charge_state := 0
var _charge_left := 0.0
var _charge_dir := Vector3.ZERO
var _charge_hit := false
var _summon_left := 4.0
var _volley_left := 3.0
var _dragon_charge_left := 5.0
var _special := ""'''),
    ('''func setup(player: Node3D, model_scene: PackedScene) -> void:''',
     '''## Налаштовує ворога за описом із DungeonLevels. Викликати ДО того, як
## ворога додано в сцену: від цих чисел залежать смужка здоров'я й
## дальність, на якій він зупиняється.
func configure(definition: Dictionary, hp_scale: float, damage_scale: float) -> void:
	display_name = definition.get("name", "")
	match String(definition.get("kind", "melee")):
		"ranged":
			kind = Kind.RANGED
			attack_range = 9.0
			aggro_range = 16.0
		"exploder":
			kind = Kind.EXPLODER
			aggro_range = 13.0
			attack_range = FUSE_DISTANCE
		"charger":
			kind = Kind.CHARGER
			aggro_range = 15.0
		"tank":
			kind = Kind.MELEE
			tank = true
			slam_every = 3
			attack_range = 2.6
		"boss":
			kind = Kind.BOSS
		_:
			kind = Kind.MELEE
	max_hp = float(definition.get("hp", max_hp)) * hp_scale
	damage = float(definition.get("damage", damage)) * damage_scale
	move_speed = float(definition.get("speed", move_speed))
	target_height = float(definition.get("height", target_height))
	hover = float(definition.get("hover", 0.0))
	xp_reward = int(definition.get("xp", xp_reward))
	attack_cooldown = float(definition.get("cooldown", attack_cooldown))
	attack_range = float(definition.get("attack_range", attack_range))
	if definition.has("projectile"):
		var shot: Dictionary = definition.projectile
		projectile_color = shot.get("color", projectile_color)
		projectile_speed = float(shot.get("speed", projectile_speed))
		volley = int(shot.get("volley", 1))

## Бос: окремі числа й свій набір прийомів.
func configure_boss(definition: Dictionary, hp_scale: float, damage_scale: float) -> void:
	configure(definition, hp_scale, damage_scale)
	kind = Kind.BOSS
	boss_style = String(definition.get("style", "demon"))
	aggro_range = 18.0
	attack_range = 3.0
	slam_every = 3

func setup(player: Node3D, model_scene: PackedScene) -> void:'''),
    ('''	_model.scale = Vector3.ONE * factor
	# Модель має стояти на підлозі, а не тонути в ній.
	_model.position.y = -bounds.position.y * factor''',
     '''	_model.scale = Vector3.ONE * factor
	# Модель має стояти на підлозі, а не тонути в ній. Летючі ширяють.
	_model.position.y = -bounds.position.y * factor + hover'''),
    ('''	_health_bar.setup(ENEMY_BAR_COLOR, target_height + 0.45, is_boss, 1.0 if not is_boss else 1.8)''',
     '''	_health_bar.setup(ENEMY_BAR_COLOR, target_height + hover + 0.45, is_boss, 1.0 if not is_boss else 1.8)'''),
    # --- гілки поведінки ---
    ('''	if _windup_left > 0.0:
		_process_windup(delta)
	elif _stagger_left > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	elif _aggro:
		if kind == Kind.RANGED:
			_process_ranged(distance, delta)
		else:
			_process_melee(distance, delta)''',
     '''	if _fuse_left >= 0.0:
		_process_fuse(delta)
	elif _charge_state != 0:
		_process_charge(delta)
	elif _windup_left > 0.0:
		_process_windup(delta)
	elif _stagger_left > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	elif _aggro:
		match kind:
			Kind.RANGED:
				_process_ranged(distance, delta)
			Kind.EXPLODER:
				_process_exploder(distance, delta)
			Kind.CHARGER:
				_process_charger(distance, delta)
			Kind.BOSS:
				if not _boss_special(distance, delta):
					_process_melee(distance, delta)
			_:
				_process_melee(distance, delta)'''),
    # --- удар по площі: у голема й боса ---
    ('''	_attack_counter += 1
	_windup_slam = kind == Kind.BOSS and _attack_counter % SLAM_EVERY == 0''',
     '''	_attack_counter += 1
	_special = ""
	_windup_slam = slam_every > 0 and _attack_counter % slam_every == 0'''),
    ('''	if kind == Kind.RANGED:
		# Снаряд "набухає" в руці — це і є попередження для гравця.
		_charging_shot = EnemyProjectile.create(damage)''',
     '''	if kind == Kind.RANGED:
		# Снаряд "набухає" в руці — це і є попередження для гравця.
		_charging_shot = EnemyProjectile.create(damage, projectile_color, projectile_speed)'''),
    ('''func _resolve_attack() -> void:
	_windup_left = 0.0
	_attack_left = attack_cooldown
	_hide_telegraph()
	if kind == Kind.RANGED:
		_release_shot()
		return''',
     '''func _resolve_attack() -> void:
	_windup_left = 0.0
	_attack_left = attack_cooldown
	_hide_telegraph()
	if kind == Kind.RANGED:
		_release_shot()
		return
	if _special == "summon":
		_special = ""
		CombatVfx.shockwave(get_parent(), global_position, 3.5, SUMMON_COLOR, 0.5)
		summon_requested.emit(global_position, SUMMON_COUNT)
		return
	if _special == "volley":
		_special = ""
		_fire_volley()
		return'''),
    ('''func _release_shot() -> void:
	if _charging_shot == null or not is_instance_valid(_charging_shot):
		return
	var shot := _charging_shot
	_charging_shot = null
	var target := _player.global_position + Vector3.UP * 1.0
	shot.launch(target - shot.global_position, _player, get_parent())''',
     '''func _release_shot() -> void:
	if _charging_shot == null or not is_instance_valid(_charging_shot):
		return
	var shot := _charging_shot
	_charging_shot = null
	var target := _player.global_position + Vector3.UP * 1.0
	var direction := target - shot.global_position
	var origin := shot.global_position
	shot.launch(direction, _player, get_parent())
	# Залп: ще кілька снарядів віялом навколо основного.
	for i in range(1, volley):
		var side := 1.0 if i % 2 == 1 else -1.0
		var angle := side * deg_to_rad(11.0) * ceilf(i / 2.0)
		_spawn_shot(origin, direction.rotated(Vector3.UP, angle))

func _spawn_shot(origin: Vector3, direction: Vector3) -> void:
	var extra := EnemyProjectile.create(damage, projectile_color, projectile_speed)
	get_parent().add_child(extra)
	extra.global_position = origin
	extra.set_charge(1.0)
	extra.launch(direction, _player, get_parent())

## Залп Дракона: віяло снарядів із пащі.
func _fire_volley() -> void:
	var origin := global_position + Vector3.UP * (target_height * 0.6 + hover) + _model_forward() * 1.2
	var direction := _player.global_position + Vector3.UP - origin
	var count := maxi(volley, 3)
	for i in count:
		var angle := lerpf(-0.5, 0.5, float(i) / float(count - 1))
		_spawn_shot(origin, direction.rotated(Vector3.UP, angle))
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.08)

# --- вибуховий ---

func _process_exploder(distance: float, delta: float) -> void:
	if distance <= FUSE_DISTANCE and _sees_player():
		_light_fuse()
		return
	_move_along_path(delta)

func _light_fuse() -> void:
	_fuse_left = FUSE_TIME
	velocity.x = 0.0
	velocity.z = 0.0
	_show_telegraph(EXPLODE_RADIUS, PI, EXPLODE_COLOR)
	_play_once(["Jump", "Headbutt", "Punch", "Bite_Front"])

func _process_fuse(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_fuse_left -= delta
	if _telegraph != null:
		_telegraph.set_instance_shader_parameter(&"progress", 1.0 - _fuse_left / FUSE_TIME)
	# Блимає дедалі частіше — видно, що зараз рвоне.
	_flash_left -= delta
	if _flash_left <= 0.0:
		_flash_left = lerpf(0.25, 0.08, 1.0 - _fuse_left / FUSE_TIME)
		CombatVfx.flash_model(_model, Color(1.0, 0.6, 0.2), 0.05)
	if _fuse_left <= 0.0:
		_explode()

func _explode() -> void:
	_fuse_left = -1.0
	_hide_telegraph()
	var parent := get_parent()
	CombatVfx.shockwave(parent, global_position, EXPLODE_RADIUS, EXPLODE_COLOR, 0.35)
	CombatVfx.impact(parent, global_position + Vector3.UP * 0.8, EXPLODE_COLOR, true)
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.18)
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() <= EXPLODE_RADIUS + 0.3:
		_player.take_damage(damage)
	# Вибухнув сам — досвіду не дає: винагорода лише за те, щоб убити раніше.
	xp_reward = 0
	current_hp = 0.0
	_die()

# --- таран ---

func _process_charger(distance: float, delta: float) -> void:
	if distance <= attack_range and _sees_player():
		velocity.x = 0.0
		velocity.z = 0.0
		_face_player(10.0)
		_try_begin_windup()
		return
	if _attack_left <= 0.0 and distance >= CHARGE_MIN_DISTANCE and distance <= CHARGE_MAX_DISTANCE \\
			and _sees_player():
		_begin_charge()
		return
	_move_along_path(delta)

func _begin_charge() -> void:
	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction.length() < 0.1:
		return
	_charge_dir = direction.normalized()
	_charge_state = 1
	_charge_left = CHARGE_WINDUP
	_charge_hit = false
	velocity.x = 0.0
	velocity.z = 0.0
	_model.rotation.y = atan2(_charge_dir.x, _charge_dir.z)
	_hide_telegraph()
	var length := CHARGE_SPEED * CHARGE_TIME
	_telegraph = CombatVfx.make_line_marker(CHARGE_COLOR, length, 1.8)
	add_child(_telegraph)
	_telegraph.position = Vector3(0, 0.05, 0) + _charge_dir * length * 0.5
	_telegraph.rotation.y = atan2(_charge_dir.x, _charge_dir.z)
	_play_once(["Jump", "No", "Headbutt", "Punch"])

func _process_charge(delta: float) -> void:
	_charge_left -= delta
	match _charge_state:
		1:
			velocity.x = 0.0
			velocity.z = 0.0
			if _telegraph != null:
				_telegraph.set_instance_shader_parameter(&"progress", 1.0 - _charge_left / CHARGE_WINDUP)
			if _charge_left <= 0.0:
				_hide_telegraph()
				_charge_state = 2
				_charge_left = CHARGE_TIME
		2:
			velocity.x = _charge_dir.x * CHARGE_SPEED
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
				CombatVfx.impact(get_parent(), global_position + Vector3.UP + _charge_dir * 0.8, HIT_COLOR, true)
			elif _charge_left <= 0.0:
				_charge_state = 3
				_charge_left = CHARGE_RECOVER
		3:
			velocity.x = 0.0
			velocity.z = 0.0
			_play("Idle")
			if _charge_left <= 0.0:
				_charge_state = 0
				_attack_left = attack_cooldown

# --- боси ---

## Прийоми, які бос робить сам, поза звичайними ударами. true — прийом
## почався, і цього кадру звичайна поведінка не потрібна.
func _boss_special(distance: float, delta: float) -> bool:
	_summon_left -= delta
	_volley_left -= delta
	_dragon_charge_left -= delta
	if _attack_left > 0.0 or not _sees_player():
		return false
	match boss_style:
		"summoner":
			if _summon_left <= 0.0:
				_summon_left = SUMMON_COOLDOWN
				_begin_special("summon", 1.0, SUMMON_COLOR, 3.5)
				return true
		"dragon":
			if distance > 4.5 and _dragon_charge_left <= 0.0 and distance <= CHARGE_MAX_DISTANCE + 2.0:
				_dragon_charge_left = DRAGON_CHARGE_COOLDOWN
				_begin_charge()
				return true
			if distance > 4.0 and _volley_left <= 0.0:
				_volley_left = VOLLEY_COOLDOWN
				_begin_special("volley", 0.8, Color(0.55, 0.9, 1.0, 0.85), 2.0)
				return true
	return false

func _begin_special(special: String, windup: float, color: Color, radius: float) -> void:
	_special = special
	_windup_slam = true   # не довертається за героєм під час прийому
	_windup_total = windup
	_windup_left = windup
	velocity.x = 0.0
	velocity.z = 0.0
	_face_player(20.0)
	_play_once(["Weapon", "Punch", "Headbutt", "Wave"])
	_show_telegraph(radius, PI, color)'''),
    # --- удари по голему ---
    ('''	# Бос важкий: його майже не зрушити й лише сильним ударом збити замах.
	var is_boss := kind == Kind.BOSS
	_knockback = knockback * (0.25 if is_boss else 1.0)''',
     '''	# Бос і голем важкі: їх майже не зрушити й лише сильним ударом збити
	# замах. Таран, що мчить, не зупинити нічим.
	var is_boss := kind == Kind.BOSS or tank
	_knockback = knockback * (0.25 if is_boss else 1.0)
	if _charge_state == 2 or _fuse_left >= 0.0:
		_knockback = Vector3.ZERO'''),
    ('''func _die() -> void:
	_dying = true''',
     '''func _die() -> void:
	# Убитий до вибуху — не вибухає; таран, убитий на бігу, падає.
	_fuse_left = -1.0
	_charge_state = 0
	_dying = true'''),
    # --- анімації летючих ---
    ('''	var name := _find_animation([wanted, "Idle", "Flying_Idle"])''',
     '''	# Летючі не ходять, а ширяють: шукаємо і їхні назви анімацій.
	var candidates: Array = [wanted]
	if wanted == "Walk":
		candidates.append_array(["Fast_Flying", "Run"])
	candidates.append_array(["Idle", "Flying_Idle"])
	var name := _find_animation(candidates)'''),
])
