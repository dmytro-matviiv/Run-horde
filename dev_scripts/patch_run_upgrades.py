# -*- coding: utf-8 -*-
# Здібності походу: свої для кожного героя і з реальним ефектом у бою.
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:80])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


# --- Герой: набуті в поході підсилення ---
patch('scenes/world/player_3d.gd', [
    ('''var _ammo := 0''',
     '''## --- Що дали здібності, набрані в поході (RunUpgrades) ---
## Кожне поле хтось читає в бою, тож жодна здібність не буває "пустою".
var _crit_chance := CRIT_CHANCE
var _lifesteal := 0.0
var _damage_taken_factor := 1.0
var _knockback_factor := 1.0
var _arc_factor := 1.0
var _reach_bonus := 0.0
var _skill_cooldown_factor := 1.0
var _dodge_cooldown_factor := 1.0
var _rage_gain_factor := 1.0
var _dash_power := 1.0
var _whirl_power := 1.0
var _mark_bonus := 0.0
var _smoke_bonus := 0.0
var _bullet_pierce := 0
var _bullets_extra := 0
var _spread_factor := 1.0
var _magazine_factor := 1.0
var _reload_factor := 1.0
var _fire_rate_factor := 1.0
var _explosive_bullets := 0

var _ammo := 0'''),
    # --- ефекти в бою ---
    ('''	if weapon_def == null:
		return step.reach
	return step.reach * weapon_def.reach_3d / 2.9''',
     '''	if weapon_def == null:
		return step.reach + _reach_bonus
	return step.reach * weapon_def.reach_3d / 2.9 + _reach_bonus'''),
    ('''	if weapon_def == null:
		return step.arc
	return clampf(step.arc * weapon_def.arc_3d / 150.0, 40.0, 359.0)''',
     '''	if weapon_def == null:
		return step.arc * _arc_factor
	return clampf(step.arc * weapon_def.arc_3d / 150.0 * _arc_factor, 40.0, 359.0)'''),
    ('''	var crit := randf() < CRIT_CHANCE
	var amount := _damage * multiplier * (CRIT_MULTIPLIER if crit else 1.0)
	if _concealed_left > 0.0:
		amount *= _concealed_damage
	if passive != null:
		amount = passive.modify_damage(self, enemy, amount)
	enemy.take_damage(amount, knockback, crit, heavy)''',
     '''	var crit := randf() < _crit_chance
	var amount := _damage * multiplier * (CRIT_MULTIPLIER if crit else 1.0)
	if _concealed_left > 0.0:
		amount *= _concealed_damage
	if passive != null:
		amount = passive.modify_damage(self, enemy, amount)
	enemy.take_damage(amount, knockback * _knockback_factor, crit, heavy)
	# Вампіризм: частина завданої шкоди повертається здоров'ям.
	if _lifesteal > 0.0:
		heal(amount * _lifesteal)'''),
    ('''	current_hp = maxf(current_hp - amount, 0.0)
	_invulnerable_left = HURT_INVULNERABLE''',
     '''	amount *= _damage_taken_factor
	current_hp = maxf(current_hp - amount, 0.0)
	_invulnerable_left = HURT_INVULNERABLE'''),
    ('''	_dodge_cooldown_left = DODGE_COOLDOWN''',
     '''	_dodge_cooldown_left = DODGE_COOLDOWN * _dodge_cooldown_factor'''),
    ('''func get_dodge_cooldown() -> Vector2:
	return Vector2(_dodge_cooldown_left, DODGE_COOLDOWN)''',
     '''func get_dodge_cooldown() -> Vector2:
	return Vector2(_dodge_cooldown_left, DODGE_COOLDOWN * _dodge_cooldown_factor)

# --- що здібності походу віддають бою й умінням ---

func skill_cooldown_factor() -> float:
	return _skill_cooldown_factor

func rage_gain_factor() -> float:
	return _rage_gain_factor

func dash_power() -> float:
	return _dash_power

func whirl_power() -> float:
	return _whirl_power

func mark_bonus() -> float:
	return _mark_bonus

func smoke_bonus() -> float:
	return _smoke_bonus

## Вороги біля точки — потрібно розривним кулям, які б'ють по площі.
func enemies_near(position: Vector3, radius: float) -> Array[Enemy3D]:
	var result: Array[Enemy3D] = []
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.is_alive() and enemy.global_position.distance_to(position) <= radius:
			result.append(enemy)
	return result'''),
    # --- стрільба з урахуванням здібностей ---
    ('''	if is_ranged():
		_ammo = weapon_def.magazine''',
     '''	if is_ranged():
		_ammo = magazine_size()'''),
    ('''func get_ammo() -> Vector2i:
	if not is_ranged():
		return Vector2i.ZERO
	return Vector2i(_ammo, weapon_def.magazine)''',
     '''func get_ammo() -> Vector2i:
	if not is_ranged():
		return Vector2i.ZERO
	return Vector2i(_ammo, magazine_size())

## Розмір магазина з урахуванням здібності "Розширений магазин".
func magazine_size() -> int:
	return maxi(1, int(round(weapon_def.magazine * _magazine_factor)))'''),
    ('''func get_reload() -> Vector2:
	return Vector2(_reload_left, weapon_def.reload_time if is_ranged() else 0.0)

func reload() -> void:
	if not is_ranged() or _reload_left > 0.0 or _ammo >= weapon_def.magazine:
		return
	_reload_left = weapon_def.reload_time / maxf(attack_speed(), 0.1)''',
     '''func get_reload() -> Vector2:
	return Vector2(_reload_left, weapon_def.reload_time * _reload_factor if is_ranged() else 0.0)

func reload() -> void:
	if not is_ranged() or _reload_left > 0.0 or _ammo >= magazine_size():
		return
	_reload_left = weapon_def.reload_time * _reload_factor / maxf(attack_speed(), 0.1)'''),
    ('''	_fire_left = weapon_def.fire_interval / maxf(attack_speed(), 0.1)''',
     '''	_fire_left = weapon_def.fire_interval * _fire_rate_factor / maxf(attack_speed(), 0.1)'''),
    ('''	for i in maxi(weapon_def.bullets_per_shot, 1):
		var spread := deg_to_rad(weapon_def.bullet_spread_deg)
		var shot_direction := direction.rotated(Vector3.UP, randf_range(-spread, spread))
		var bullet := PlayerProjectile.create(self, 1.0, weapon_def.color, 1.2)
		parent.add_child(bullet)
		bullet.launch(muzzle, shot_direction, weapon_def.bullet_speed)''',
     '''	var shots := maxi(weapon_def.bullets_per_shot, 1) + _bullets_extra
	for i in shots:
		var spread := deg_to_rad(weapon_def.bullet_spread_deg) * _spread_factor
		# Додаткові кулі йдуть трохи вбік, щоб їх було видно як чергу.
		var offset := 0.0 if shots == 1 else lerpf(-0.05, 0.05, float(i) / float(shots - 1))
		var shot_direction := direction.rotated(Vector3.UP, randf_range(-spread, spread) + offset)
		var bullet := PlayerProjectile.create(self, 1.0, weapon_def.color, 1.2)
		bullet.pierce = _bullet_pierce
		bullet.explosion_radius = 1.9 if _explosive_bullets > 0 else 0.0
		bullet.explosion_damage = 0.35 * _explosive_bullets
		parent.add_child(bullet)
		bullet.launch(muzzle, shot_direction, weapon_def.bullet_speed)'''),
    ('''		if _reload_left <= 0.0:
			_ammo = weapon_def.magazine''',
     '''		if _reload_left <= 0.0:
			_ammo = magazine_size()'''),
    # --- застосування здібності ---
    ('''## Здібності з вибору на рівні. Ідентифікатори ті самі, що й у
## 2D-частині гри, тож окремого списку заводити не довелось.
func apply_ability(id: StringName) -> void:
	match id:
		&"weapon_damage":
			_damage *= 1.25
		&"weapon_cooldown", &"weapon_multishot":
			_attack_speed *= 1.12
			_damage *= 1.05
			_apply_attack_speed()
		&"move_speed":
			_speed_bonus += 0.12
		&"max_hp":
			max_hp += 25.0
			current_hp += 25.0
		&"regen":
			_regen_per_second += 1.0
		_:
			# Невідома здібність — просто невелике посилення, щоб вибір
			# ніколи не був порожнім.
			_damage *= 1.08
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)''',
     '''## Здібність, обрана в поході (див. RunUpgrades). Кожен випадок тут
## щось реально змінює в бою — саме тому список здібностей у кожного
## героя свій: мечниці не пропонують пробивних куль, а стрільцю —
## ширшого замаху.
func apply_run_upgrade(id: StringName) -> void:
	match id:
		&"hp_up":
			max_hp += 25.0
			heal(25.0)
		&"regen":
			_regen_per_second += 1.0
		&"speed":
			_speed_bonus += 0.08
		&"damage":
			_damage *= 1.12
		&"crit":
			_crit_chance += 0.06
		&"lifesteal":
			_lifesteal += 0.05
		&"armor":
			_damage_taken_factor *= 0.9
		&"skill_cd":
			_skill_cooldown_factor *= 0.88
		&"dodge_cd":
			_dodge_cooldown_factor *= 0.82
		&"arc":
			_arc_factor *= 1.2
			_reach_bonus += 0.25
		&"knockback":
			_knockback_factor *= 1.6
		&"combo_speed":
			_attack_speed *= 1.12
			_apply_attack_speed()
		&"rage_gain":
			_rage_gain_factor *= 1.3
		&"dash_power":
			_dash_power *= 1.6
		&"whirl_power":
			_whirl_power *= 1.25
		&"pierce":
			_bullet_pierce += 1
		&"magazine":
			_magazine_factor += 0.4
			_ammo = magazine_size()
		&"reload":
			_reload_factor *= 0.75
		&"extra_bullet":
			_bullets_extra += 1
		&"accuracy":
			_spread_factor *= 0.5
			_damage *= 1.1
		&"fire_rate":
			_fire_rate_factor *= 0.85
		&"explosive":
			_explosive_bullets += 1
		&"mark_power":
			_mark_bonus += 0.15
		&"smoke_power":
			_smoke_bonus += 1.0
		_:
			push_warning("Невідома здібність походу: %s" % id)
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)

## Стара назва — щоб не ламати 2D-частину гри, яка ще жива в проєкті.
func apply_ability(id: StringName) -> void:
	apply_run_upgrade(id)'''),
])

# --- Куля: пробиття й розрив ---
patch('scenes/combat/player_projectile.gd', [
    ('''var damage_multiplier := 1.0
var knockback := 1.0
var color := Color(1.0, 0.9, 0.5)''',
     '''var damage_multiplier := 1.0
var knockback := 1.0
var color := Color(1.0, 0.9, 0.5)
## Скільки ворогів куля прошиває наскрізь ("Пробивний набій").
var pierce := 0
## Розрив на влучанні ("Розривні кулі"): радіус і частка шкоди сусідам.
var explosion_radius := 0.0
var explosion_damage := 0.0

## Кого вже зачепили — щоб та сама куля не била одного двічі.
var _hit_ids: Array = []'''),
    ('''func _impact(position: Vector3, collider: Variant) -> void:
	var enemy := collider as Enemy3D
	if enemy != null and enemy.is_alive() and _player != null and is_instance_valid(_player):
		var push: Vector3 = _velocity
		push.y = 0.0
		_player.deal_damage(enemy, damage_multiplier, push.normalized() * knockback, false)
		CombatVfx.impact(get_parent(), position, color, false)
	else:
		# Об стіну — дрібні іскри, щоб було видно, куди пішла куля.
		CombatVfx.impact(get_parent(), position, color, false)
	queue_free()''',
     '''func _impact(position: Vector3, collider: Variant) -> void:
	var enemy := collider as Enemy3D
	var alive_player: bool = _player != null and is_instance_valid(_player)
	if enemy != null and enemy.is_alive() and alive_player:
		if _hit_ids.has(enemy.get_instance_id()):
			return   # цього вже зачепили — летимо далі
		_hit_ids.append(enemy.get_instance_id())
		var push: Vector3 = _velocity
		push.y = 0.0
		_player.deal_damage(enemy, damage_multiplier, push.normalized() * knockback, false)
		_explode(position)
		CombatVfx.impact(get_parent(), position, color, false)
		# "Пробивний набій": куля не зупиняється, поки не витратить
		# пробиття. Вороги позаду отримують те саме влучання.
		if pierce > 0:
			pierce -= 1
			global_position = position + _velocity.normalized() * 0.25
			return
		queue_free()
		return
	# Об стіну — дрібні іскри, щоб було видно, куди пішла куля.
	_explode(position)
	CombatVfx.impact(get_parent(), position, color, false)
	queue_free()

## Розривна куля зачіпає всіх поруч із точкою влучання.
func _explode(position: Vector3) -> void:
	if explosion_radius <= 0.0 or _player == null or not is_instance_valid(_player):
		return
	CombatVfx.shockwave(get_parent(), position, explosion_radius, color, 0.25)
	for enemy: Enemy3D in _player.enemies_near(position, explosion_radius):
		if _hit_ids.has(enemy.get_instance_id()):
			continue
		_player.deal_damage(enemy, explosion_damage, Vector3.ZERO, false)'''),
])

# --- Здібності героїв читають набуте в поході ---
patch('scenes/combat/skills/hero_skill_3d.gd', [
    ('''func try_use(player: Node) -> bool:
	if not is_ready(player) or not _use(player):
		return false
	_cooldown_left = cooldown
	return true''',
     '''func try_use(player: Node) -> bool:
	if not is_ready(player) or not _use(player):
		return false
	# Здібність "Тактика" з походу скорочує перезарядку всіх умінь.
	_cooldown_left = cooldown * player.skill_cooldown_factor()
	return true'''),
])

patch('scenes/combat/skills/whirlwind.gd', [
    ('''	var radius := RADIUS + 0.15 * level
	var damage := DAMAGE * (1.0 + 0.18 * level)''',
     '''	var power: float = player.whirl_power()
	var radius := (RADIUS + 0.15 * level) * (1.0 + (power - 1.0) * 0.5)
	var damage := DAMAGE * (1.0 + 0.18 * level) * power'''),
    ('''	var radius := RADIUS + 0.15 * level
	player.spin_model(SPIN_TIME)''',
     '''	var radius := (RADIUS + 0.15 * level) * (1.0 + (player.whirl_power() - 1.0) * 0.5)
	player.spin_model(SPIN_TIME)'''),
])

patch('scenes/combat/skills/rage_dash.gd', [
    ('''	_dash_left = TIME
	_hit_ids.clear()
	player.dash(player.facing_vector(), DISTANCE / TIME, TIME)''',
     '''	_dash_left = TIME
	_hit_ids.clear()
	# "Таран" із походу робить ривок довшим і болючішим.
	var distance: float = DISTANCE * (1.0 + (player.dash_power() - 1.0) * 0.5)
	player.dash(player.facing_vector(), distance / TIME, TIME)'''),
    ('''		player.deal_damage(enemy, DAMAGE, push.normalized() * KNOCKBACK, true)''',
     '''		player.deal_damage(enemy, DAMAGE * player.dash_power(), push.normalized() * KNOCKBACK, true)'''),
])

patch('scenes/combat/skills/passive_rage.gd', [
    ('''func on_hit(_player: Node, _enemy: Node, _amount: float, heavy: bool) -> void:
	_add(PER_HEAVY_HIT if heavy else PER_HIT)

func on_damage_taken(_player: Node, amount: float) -> void:
	_add(PER_DAMAGE_TAKEN * amount)''',
     '''func on_hit(player: Node, _enemy: Node, _amount: float, heavy: bool) -> void:
	# Здібність "Невгамовна лють" із походу пришвидшує накопичення.
	_add((PER_HEAVY_HIT if heavy else PER_HIT) * player.rage_gain_factor())

func on_damage_taken(player: Node, amount: float) -> void:
	_add(PER_DAMAGE_TAKEN * amount * player.rage_gain_factor())'''),
])

patch('scenes/combat/skills/passive_death_mark.gd', [
    ('''func modify_damage(_player: Node, enemy: Node, amount: float) -> float:
	return amount * MARK_BONUS if _is_marked(enemy) else amount''',
     '''func modify_damage(player: Node, enemy: Node, amount: float) -> float:
	# "Мисливець" із походу робить мітку ще болючішою.
	return amount * (MARK_BONUS + player.mark_bonus()) if _is_marked(enemy) else amount'''),
])

patch('scenes/combat/skills/smoke_veil.gd', [
    ('''	var duration := DURATION + 0.5 * talent_level(player)''',
     '''	var duration: float = DURATION + 0.5 * talent_level(player) + player.smoke_bonus()'''),
])

# --- Вікно вибору вміє показувати нові картки ---
patch('scenes/ui/level_up_choice.gd', [
    ('''func setup(new_level: int, choices: Array[UpgradeDef], current_levels: Dictionary) -> void:''',
     '''## Картки нового зразка: кожна вже знає свій рівень і межу. Саме ними
## користується данж (RunUpgrades), бо його здібності залежать від
## героя та його зброї.
func setup_cards(new_level: int, cards: Array) -> void:
	level_label.text = "Рівень %d!" % new_level
	for card: Dictionary in cards:
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 190)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\\n\\n%s\\n\\nРівень %d/%d" % [card.title, card.text, card.level, card.max]
		button.pressed.connect(_on_card_pressed.bind(card.id))
		cards_container.add_child(button)

func setup(new_level: int, choices: Array[UpgradeDef], current_levels: Dictionary) -> void:'''),
])

# --- Данж роздає здібності з нового набору ---
patch('scenes/dungeon/dungeon.gd', [
    ('''var _run_gold := 0''', '''var _run_gold := 0
## Що герой уже взяв у цьому поході: id здібності -> рівень.
var _run_upgrades: Dictionary = {}'''),
    ('''func _offer_ability() -> void:
	var luck := TALENT_LUCK_PER_LEVEL * GameState.get_meta_level(GameState.selected_hero_id, &"meta_luck")
	var choices := UpgradePool.pick_choices({}, luck)
	if choices.is_empty():
		return''',
     '''func _offer_ability() -> void:
	var luck := TALENT_LUCK_PER_LEVEL * GameState.get_meta_level(GameState.selected_hero_id, &"meta_luck")
	# Здібності підбираються під ГЕРОЯ та його зброю: стрільцю — набої й
	# перезарядка, мечниці — замахи й лють.
	var choices := RunUpgrades.pick(player, _run_upgrades, luck)
	if choices.is_empty():
		return'''),
    ('''	choice_ui.setup(_hero_level, choices, {})
	var picked: StringName = await choice_ui.upgrade_chosen
	choice_ui.queue_free()
	get_tree().paused = false
	player.apply_ability(picked)''',
     '''	choice_ui.setup_cards(_hero_level, choices)
	var picked: StringName = await choice_ui.upgrade_chosen
	choice_ui.queue_free()
	get_tree().paused = false
	_run_upgrades[picked] = int(_run_upgrades.get(picked, 0)) + 1
	player.apply_run_upgrade(picked)'''),
])
