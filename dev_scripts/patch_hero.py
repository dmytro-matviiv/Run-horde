# -*- coding: utf-8 -*-
p = r'D:\Claude code\idle survivor_like\scenes\run\hero.gd'
s = open(p, encoding='utf-8').read()


def rep(a, b):
    global s
    assert a in s, a[:60]
    s = s.replace(a, b, 1)


rep('''## Герой. Керування — аналоговий джойстик від точки дотику: гравець
## притискає палець (або мишу — для тестів на ПК) і тягне в потрібну
## сторону, герой рухається в цьому напрямку з силою, пропорційною
## відстані відтягування. Зброя стріляє сама по найближчому ворогу.''', '''## Герой. Керування — аналоговий джойстик від точки дотику: гравець
## притискає палець (або мишу — для тестів на ПК) і тягне в потрібну
## сторону, герой рухається в цьому напрямку з силою, пропорційною
## відстані відтягування.
##
## Сам герой НЕ вміє атакувати: чим і як він б'є, вирішує WeaponModule
## за спорядженою зброєю (WeaponDef), а чим він унікальний як клас —
## HeroAbility (рунна нова, ривок люті, фенікс, тіні асасина). Герой
## лише зберігає стати й роздає обом події бою.''')

rep('''signal died
signal leveled_up(levels_gained: int)
signal gold_collected(amount: int)''', '''signal died
signal leveled_up(levels_gained: int)
signal gold_collected(amount: int)

const WEAPON_MODULE_SCRIPT := preload("res://scenes/run/weapon_module.gd")''')

rep('''var _invulnerable := false
var _weapon_cooldown_left := 0.0
var _projectile_pool: ObjectPool''', '''var _invulnerable := false

var _weapon: WeaponModule
var _ability: HeroAbility

# Тимчасові ефекти від класових умінь (ривок люті, димова завіса).
var _temp_attack_speed_bonus := 0.0
var _temp_attack_speed_left := 0.0
var _stealth_left := 0.0
var _stealth_damage_bonus := 0.0
var _last_seen_position := Vector2.ZERO''')

rep('''func _ready() -> void:
	pickup_area.area_entered.connect(_on_pickup_area_entered)

func setup(projectile_pool: ObjectPool) -> void:
	_projectile_pool = projectile_pool''', '''func _ready() -> void:
	pickup_area.area_entered.connect(_on_pickup_area_entered)

## Пули приходять з run.gd: снаряди, вибухи й зони на землі потрібні
## новій системі зброї та класовим умінням.
func setup(projectile_pool: ObjectPool, blast_pool: ObjectPool, zone_pool: ObjectPool) -> void:
	_weapon = WEAPON_MODULE_SCRIPT.new()
	add_child(_weapon)
	_weapon.setup(self, projectile_pool, blast_pool, zone_pool)
	_weapon.attacked.connect(_on_weapon_attacked)

## Спорядити зброю (WeaponPool). Викликається на старті рану з тим,
## що гравець обрав у магазині зброї.
func equip_weapon(def: WeaponDef) -> void:
	if _weapon == null or def == null:
		return
	_weapon.equip(def)

func get_weapon_def() -> WeaponDef:
	return null if _weapon == null else _weapon.get_def()''')

rep('''func apply_hero_def(def: HeroDef) -> void:
	sprite.color = def.color
	max_hp += def.bonus_max_hp
	current_hp = max_hp
	_hero_move_speed_percent = def.move_speed_percent''', '''func apply_hero_def(def: HeroDef) -> void:
	sprite.color = def.color
	max_hp += def.bonus_max_hp
	current_hp = max_hp
	_hero_move_speed_percent = def.move_speed_percent
	_setup_ability(def.ability_id)''')

rep('''func _physics_process(delta: float) -> void:
	velocity = _get_move_direction() * Balance.HERO_MOVE_SPEED * _move_speed_multiplier
	move_and_slide()
	_process_weapon(delta)
	_process_contact_damage()''', '''func _physics_process(delta: float) -> void:
	velocity = _get_move_direction() * Balance.HERO_MOVE_SPEED * _move_speed_multiplier
	move_and_slide()
	_process_temp_effects(delta)
	if _weapon != null:
		_weapon.process_attack(delta, _get_weapon_stats())
	_process_contact_damage()''')

rep('''func _process_weapon(delta: float) -> void:
	_weapon_cooldown_left -= delta
	if _weapon_cooldown_left > 0.0:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	_fire_at(target)
	_weapon_cooldown_left = Balance.WEAPON_COOLDOWN * _cooldown_multiplier

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.visible:
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest

func _fire_at(target: Node2D) -> void:
	if _projectile_pool == null:
		return
	var base_direction := global_position.direction_to(target.global_position)
	var shots := 1 + _extra_projectiles
	var spread := deg_to_rad(12.0)
	var damage := Balance.WEAPON_DAMAGE * _damage_multiplier
	var pierce := Balance.WEAPON_PIERCE + _pierce_bonus
	for i in shots:
		var angle_offset := 0.0
		if shots > 1:
			angle_offset = spread * (i - float(shots - 1) / 2.0)
		var direction := base_direction.rotated(angle_offset)
		var projectile: Node = _projectile_pool.acquire()
		projectile.spawn(global_position, direction, damage, pierce, _ricochet_count)
''', '''## Бонуси героя, які модуль зброї домішує до чисел самої зброї.
func _get_weapon_stats() -> Dictionary:
	return {
		"damage_mult": get_damage_multiplier(),
		"cooldown_mult": _cooldown_multiplier / (1.0 + _temp_attack_speed_bonus),
		"pierce_bonus": _pierce_bonus,
		"extra_shots": _extra_projectiles,
		"ricochet": _ricochet_count,
	}

## Спільний множник шкоди: апгрейди рану + мета + бонус димової завіси.
func get_damage_multiplier() -> float:
	return _damage_multiplier * (1.0 + _stealth_damage_bonus)

func _setup_ability(ability_id: StringName) -> void:
	_ability = AbilityPool.create(ability_id)
	if _ability == null:
		return
	add_child(_ability)
	_ability.setup(self, _weapon)

func get_ability() -> HeroAbility:
	return _ability

## Події бою для класового вміння — їх пробрасує run.gd (шкода й
## вбивства рахуються там, бо там же живуть пули ворогів).
func notify_damage_dealt(amount: float) -> void:
	if _ability != null:
		_ability.on_damage_dealt(amount)

func notify_enemy_killed(at_position: Vector2) -> void:
	if _ability != null:
		_ability.on_enemy_killed(at_position)

func _on_weapon_attacked(target: Node2D) -> void:
	if _ability != null:
		_ability.on_attack(target)

func _process_temp_effects(delta: float) -> void:
	if _temp_attack_speed_left > 0.0:
		_temp_attack_speed_left -= delta
		if _temp_attack_speed_left <= 0.0:
			_temp_attack_speed_bonus = 0.0
	if _stealth_left > 0.0:
		_stealth_left -= delta
		if _stealth_left <= 0.0:
			_stealth_damage_bonus = 0.0
			modulate.a = 1.0

## Ривок люті: героїня стрибає в точку, а не йде до неї — тому
## переставляємо позицію напряму, обходячи звичайний рух.
func dash_to(target_position: Vector2) -> void:
	global_position = target_position

func add_temp_attack_speed(bonus: float, duration: float) -> void:
	_temp_attack_speed_bonus = maxf(_temp_attack_speed_bonus, bonus)
	_temp_attack_speed_left = maxf(_temp_attack_speed_left, duration)

func grant_iframes(duration: float) -> void:
	_start_iframes(duration)

func restore_hp_fraction(fraction: float) -> void:
	current_hp = maxf(current_hp, max_hp * fraction)

## Димова завіса асасина: вороги біжать у точку, де його бачили
## востаннє (enemy.gd), сам він невразливий і б'є сильніше.
func enter_stealth(duration: float, damage_bonus: float) -> void:
	_last_seen_position = global_position
	_stealth_left = duration
	_stealth_damage_bonus = damage_bonus
	modulate.a = 0.35

func is_stealthed() -> bool:
	return _stealth_left > 0.0

func get_last_seen_position() -> Vector2:
	return _last_seen_position
''')

rep('''func _process_contact_damage() -> void:
	if _invulnerable:
		return''', '''func _process_contact_damage() -> void:
	if _invulnerable or is_stealthed():
		return''')

rep('''func is_invulnerable() -> bool:
	return _invulnerable''', '''func is_invulnerable() -> bool:
	return _invulnerable or is_stealthed()''')

rep('''	var actual_damage := maxf(1.0, amount - _armor_flat_reduction)
	current_hp -= actual_damage
	if current_hp <= 0.0:
		current_hp = 0.0
		set_physics_process(false)
		died.emit()
	else:
		_start_iframes(Balance.HERO_IFRAMES + _iframe_bonus)''', '''	var actual_damage := maxf(1.0, amount - _armor_flat_reduction)
	current_hp -= actual_damage
	if _ability != null:
		_ability.on_hero_damaged(actual_damage)
	if current_hp > 0.0:
		_start_iframes(Balance.HERO_IFRAMES + _iframe_bonus)
		return
	# Останнє слово за класовим умінням: Фенікс жриці скасовує смерть
	# і сам повертає героїні частину HP.
	if _ability != null and _ability.try_prevent_death():
		return
	current_hp = 0.0
	set_physics_process(false)
	died.emit()''')

open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('hero patched')
