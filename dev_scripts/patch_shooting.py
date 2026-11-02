# -*- coding: utf-8 -*-
# Стрільба: темп вогню, магазин, перезарядка, куля, спалах пострілу.
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:80])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


# --- Спалах пострілу ---
patch('scenes/combat/combat_vfx.gd', [
    ('''## Цифра шкоди, що злітає над ворогом.''',
     '''## Спалах пострілу біля ствола: коротка яскрава зірка й кілька іскор
## уздовж напрямку. Без справжнього світла — телефон його не потягне на
## кожному пострілі, а видно однаково добре.
static func muzzle_flash(parent: Node, position: Vector3, direction: Vector3, color: Color) -> void:
	var flare := MeshInstance3D.new()
	flare.mesh = _get_flare_mesh()
	flare.material_override = _get_flare_material(color)
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flare)
	flare.global_position = position
	flare.scale = Vector3.ONE * 0.5
	var tween := flare.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flare, "scale", Vector3.ONE * 0.9, 0.07)
	tween.tween_property(flare, "transparency", 1.0, 0.07)
	tween.chain().tween_callback(flare.queue_free)

	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 5
	sparks.lifetime = 0.16
	sparks.mesh = _get_spark_mesh()
	sparks.material_override = _get_spark_material()
	sparks.direction = direction
	sparks.spread = 14.0
	sparks.initial_velocity_min = 4.0
	sparks.initial_velocity_max = 9.0
	sparks.gravity = Vector3(0, -4.0, 0)
	sparks.color = color
	parent.add_child(sparks)
	sparks.global_position = position
	sparks.emitting = true
	_free_after(sparks, 0.3)

## Цифра шкоди, що злітає над ворогом.'''),
])

# --- HeroBuilder повертає вузол зброї (потрібен ствол для пострілу) ---
patch('scripts/systems/hero_builder.gd', [
    ('''static func attach_weapon(model: Node3D, hero: HeroDef, weapon: WeaponDef) -> void:''',
     '''## Повертає вузол причепленої зброї (або null, якщо лишився вбудований
## у модель меч) — з нього беремо кінчик ствола для пострілу.
static func attach_weapon(model: Node3D, hero: HeroDef, weapon: WeaponDef) -> Node3D:'''),
    ('''	var builtin := model.find_child(String(hero.builtin_weapon_node), true, false)
	if builtin != null and builtin is Node3D:
		(builtin as Node3D).visible = weapon == null or weapon.style_3d == "sword"
	if weapon == null:
		return''',
     '''	var builtin := model.find_child(String(hero.builtin_weapon_node), true, false)
	if builtin != null and builtin is Node3D:
		(builtin as Node3D).visible = weapon == null or weapon.style_3d == "sword"
	if weapon == null:
		return null'''),
    ('''	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bone := skeleton.find_bone(String(hero.weapon_bone))
	if bone < 0:
		return''',
     '''	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	var skeleton := skeletons[0] as Skeleton3D
	var bone := skeleton.find_bone(String(hero.weapon_bone))
	if bone < 0:
		return null'''),
    ('''	elif weapon.style_3d == "sword":
		return   # у моделі вже є меч — лишаємо його''',
     '''	elif weapon.style_3d == "sword":
		return null   # у моделі вже є меч — лишаємо його'''),
    ('''	var bone_scale: float = skeleton.global_transform.basis.get_scale().x
	weapon_node.scale = Vector3.ONE * weapon.model_scale / maxf(bone_scale, 0.0001)''',
     '''	var bone_scale: float = skeleton.global_transform.basis.get_scale().x
	weapon_node.scale = Vector3.ONE * weapon.model_scale / maxf(bone_scale, 0.0001)
	return weapon_node'''),
])

# --- Герой: стрілецький режим ---
patch('scenes/world/player_3d.gd', [
    ('''##  - КОМБО з трьох ударів: два помахи мечем у різні боки й удар ногою,
##    що відкидає ворога. Натискання під час удару запам'ятовується, а
##    утримання кнопки б'є серією, поки є ціль.''',
     '''##  - КОМБО з трьох ударів (для ближнього бою): два помахи мечем у різні
##    боки й удар ногою, що відкидає ворога. Натискання під час удару
##    запам'ятовується, а утримання кнопки б'є серією, поки є ціль.
##  - СТРІЛЬБА (для вогнепальної зброї): свій темп вогню, магазин і
##    перезарядка. Утримуєш кнопку — герой веде вогонь, поки є набої;
##    скінчились — сам перезаряджається. Кулі летять видимо й
##    розбиваються об стіни.'''),
    ('''var _model_instance: Node3D''',
     '''var _model_instance: Node3D
var _weapon_node: Node3D

## Стрільба: скільки набоїв лишилось, коли можна наступний постріл і
## скільки триває перезарядка.
var _ammo := 0
var _fire_left := 0.0
var _reload_left := 0.0'''),
    ('''func _equip_weapon() -> void:
	if _model_instance != null:
		HeroBuilder.attach_weapon(_model_instance, hero_def, weapon_def)''',
     '''func _equip_weapon() -> void:
	if _model_instance != null:
		_weapon_node = HeroBuilder.attach_weapon(_model_instance, hero_def, weapon_def)
	if is_ranged():
		_ammo = weapon_def.magazine'''),
    # Анімації під зброю
    ('''	move.add_blend_point(_animation_node("Idle"), Vector2(0, 0), -1, &"idle")''',
     '''	# Зі стволом у руках герой і стоїть інакше, і стріляє, а не махає.
	var ranged := is_ranged()
	move.add_blend_point(_animation_node("Idle_Gun" if ranged else "Idle", ["Idle"]), Vector2(0, 0), -1, &"idle")'''),
    ('''	tree.add_node(&"SlashAnim", _animation_node("Sword_Slash"), Vector2(0, 200))''',
     '''	var attack_anim := "Gun_Shoot" if ranged else "Sword_Slash"
	tree.add_node(&"SlashAnim", _animation_node(attack_anim, ["Sword_Slash"]), Vector2(0, 200))'''),
    ('''	tree.add_node(&"SlashFastAnim", _animation_node("Sword_Slash"), Vector2(0, 400))''',
     '''	tree.add_node(&"SlashFastAnim", _animation_node(attack_anim, ["Sword_Slash"]), Vector2(0, 400))'''),
    ('''	tree.add_node(&"KickAnim", _animation_node("Kick_Right", ["Punch_Right", "Sword_Slash"]), Vector2(0, 600))''',
     '''	# Для стрільця це місце займає рух перезарядки.
	tree.add_node(&"KickAnim", _animation_node("Interact" if ranged else "Kick_Right",
		["Kick_Right", "Punch_Right", "Sword_Slash"]), Vector2(0, 600))'''),
    # Удар -> постріл
    ('''func attack() -> void:
	if _dead:
		return
	if _attack_step >= 0 or _roll_left > 0.0 or _spin_left > 0.0:
		_attack_queued = true
		return
	_start_attack()''',
     '''## Чи в руках вогнепальна зброя.
func is_ranged() -> bool:
	return weapon_def != null and weapon_def.ranged_3d

func attack() -> void:
	if _dead:
		return
	if is_ranged():
		_try_shoot()
		return
	if _attack_step >= 0 or _roll_left > 0.0 or _spin_left > 0.0:
		_attack_queued = true
		return
	_start_attack()

# --- стрільба ---

## Набої в магазині: (скільки лишилось, скільки всього).
func get_ammo() -> Vector2i:
	if not is_ranged():
		return Vector2i.ZERO
	return Vector2i(_ammo, weapon_def.magazine)

## Скільки лишилось перезаряджатись і скільки вона триває.
func get_reload() -> Vector2:
	return Vector2(_reload_left, weapon_def.reload_time if is_ranged() else 0.0)

func reload() -> void:
	if not is_ranged() or _reload_left > 0.0 or _ammo >= weapon_def.magazine:
		return
	_reload_left = weapon_def.reload_time / maxf(attack_speed(), 0.1)
	_fire("KickShot", true)

## Постріл, якщо ствол готовий: не в перезарядці, минула затримка після
## попереднього і є набої.
func _try_shoot() -> void:
	if _roll_left > 0.0 or _reload_left > 0.0 or _fire_left > 0.0:
		return
	if _ammo <= 0:
		reload()
		return
	_shoot()

func _shoot() -> void:
	_ammo -= 1
	_fire_left = weapon_def.fire_interval / maxf(attack_speed(), 0.1)
	_combat_left = COMBAT_MEMORY
	_since_attack = 0.0
	_refresh_target()

	var aim := _aim_angle()
	var direction := Vector3(sin(aim), 0.0, cos(aim))
	if _target != null and is_instance_valid(_target):
		# Ціль трохи вища за підлогу — цілимось у груди.
		direction = (_target.global_position + Vector3.UP * 0.9 - _muzzle_position()).normalized()
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	_fire("SlashShot", moving)

	var parent := get_parent()
	var muzzle := _muzzle_position()
	for i in maxi(weapon_def.bullets_per_shot, 1):
		var spread := deg_to_rad(weapon_def.bullet_spread_deg)
		var shot_direction := direction.rotated(Vector3.UP, randf_range(-spread, spread))
		var bullet := PlayerProjectile.create(self, 1.0, weapon_def.color, 1.2)
		parent.add_child(bullet)
		bullet.launch(muzzle, shot_direction, weapon_def.bullet_speed)
	CombatVfx.muzzle_flash(parent, muzzle, direction, weapon_def.color)
	_shake_camera(0.03)
	if _ammo <= 0:
		reload()

## Кінчик ствола: беремо з моделі зброї в руці, а якщо її немає —
## приблизно від плеча героя.
func _muzzle_position() -> Vector3:
	if _weapon_node != null and is_instance_valid(_weapon_node):
		return _weapon_node.global_transform * weapon_def.muzzle_offset
	return global_position + Vector3.UP * 1.2 + _facing_vector() * 0.5

func _update_ranged(delta: float) -> void:
	if not is_ranged():
		return
	_fire_left = maxf(_fire_left - delta, 0.0)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_ammo = weapon_def.magazine
	# Утримання кнопки — вогонь чергою, поки є набої.
	elif _attack_held and _fire_left <= 0.0:
		_try_shoot()'''),
    ('''	var direction := _get_world_direction()
	_update_attack(delta)
	_tick_skills(delta)''',
     '''	var direction := _get_world_direction()
	_update_attack(delta)
	_update_ranged(delta)
	_tick_skills(delta)'''),
])
