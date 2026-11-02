# -*- coding: utf-8 -*-
# Друга частина: бій рахує зброю, таланти, пасивку й тимчасові підсилення.
import os
os.chdir(r'D:\Claude code\idle survivor_like')
path = 'scenes/world/player_3d.gd'
s = open(path, encoding='utf-8').read()


def rep(a, b):
    global s
    assert a in s, a[:90]
    s = s.replace(a, b, 1)


rep('''	var direction := _get_world_direction()
	_update_attack(delta)
	_update_skill(delta)''',
    '''	var direction := _get_world_direction()
	_update_attack(delta)
	_tick_skills(delta)''')

rep('''	_combat_left = maxf(_combat_left - delta, 0.0)
	_since_attack += delta''',
    '''	_combat_left = maxf(_combat_left - delta, 0.0)
	_attack_speed_left = maxf(_attack_speed_left - delta, 0.0)
	_since_attack += delta
	if _spin_left > 0.0:
		_spin_left -= delta
	if _concealed_left > 0.0:
		_concealed_left = maxf(_concealed_left - delta, 0.0)
		if _concealed_left <= 0.0:
			_set_model_transparency(0.0)''')

rep('''	var factor := 1.0 + _speed_bonus''',
    '''	var factor := 1.0 + _speed_bonus + (_concealed_speed if _concealed_left > 0.0 else 0.0)''')

# --- удари: зброя вирішує дальність, ширину й вагу ---
rep('''		var reach: float = step.reach''',
    '''		var reach: float = _reach(step)''')

rep('''		if distance > step.reach + 0.5:
			continue''',
    '''		if distance > _reach(step) + 0.5:
			continue''')

rep('''		if distance > 0.4 and forward.angle_to(offset / distance) > half_arc:''',
    '''		if distance > 0.4 and forward.angle_to(offset / distance) > half_arc:''')

rep('''func _apply_hit(step: Dictionary) -> void:
	var aim := _aim_angle()
	var forward := Vector3(sin(aim), 0.0, cos(aim))
	var half_arc := deg_to_rad(step.arc) * 0.5''',
    '''## Дальність і ширина замаху залежать від зброї: сокира б'є широко,
## глефа — далеко й вузько.
func _reach(step: Dictionary) -> float:
	if weapon_def == null:
		return step.reach
	return step.reach * weapon_def.reach_3d / 2.9

func _arc(step: Dictionary) -> float:
	if weapon_def == null:
		return step.arc
	return clampf(step.arc * weapon_def.arc_3d / 150.0, 40.0, 359.0)

func _apply_hit(step: Dictionary) -> void:
	var aim := _aim_angle()
	var forward := Vector3(sin(aim), 0.0, cos(aim))
	var half_arc := deg_to_rad(_arc(step)) * 0.5''')

rep('''		_deal_damage(enemy, step.damage, offset.normalized() * step.knockback, step.heavy)''',
    '''		var knockback: float = step.knockback * (weapon_def.knockback_mult_3d if weapon_def != null else 1.0)
		deal_damage(enemy, step.damage, offset.normalized() * knockback, step.heavy)''')

rep('''		CombatVfx.slash(get_parent(), global_position + Vector3.UP * 1.0, _aim_angle(),
			step.reach + 0.2, step.arc, color, step.reverse, step.tilt, 0.24)''',
    '''		CombatVfx.slash(get_parent(), global_position + Vector3.UP * 1.0, _aim_angle(),
			_reach(step) + 0.2, _arc(step), color, step.reverse, step.tilt, 0.24)''')

# --- здібності й пасивка замість старого "вихору" ---
old_skill_start = s.index('func _update_skill(delta: float) -> void:')
old_skill_end = s.index('func _deal_damage(enemy: Enemy3D, multiplier: float, knockback: Vector3, heavy: bool) -> void:')
s = s[:old_skill_start] + '''## Здібності й пасивка живуть своїм життям: перезарядка, накопичення
## люті, тик вогняного кола.
func _tick_skills(delta: float) -> void:
	for skill: HeroSkill3D in _skills:
		skill.tick(self, delta)
	if passive != null:
		passive.tick(self, delta)

''' + s[old_skill_end:]

rep('''func _deal_damage(enemy: Enemy3D, multiplier: float, knockback: Vector3, heavy: bool) -> void:
	var crit := randf() < CRIT_CHANCE
	var amount := _damage * multiplier * (CRIT_MULTIPLIER if crit else 1.0)
	enemy.take_damage(amount, knockback, crit, heavy)''',
    '''## Єдине місце, де героєві рахується шкода: сюди приходять і звичайні
## удари, і здібності, і пасивки. Тут же діють мітка ворога, димова
## завіса й критичні удари.
func deal_damage(enemy: Enemy3D, multiplier: float, knockback: Vector3, heavy: bool) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	var crit := randf() < CRIT_CHANCE
	var amount := _damage * multiplier * (CRIT_MULTIPLIER if crit else 1.0)
	if _concealed_left > 0.0:
		amount *= _concealed_damage
	if passive != null:
		amount = passive.modify_damage(self, enemy, amount)
	enemy.take_damage(amount, knockback, crit, heavy)
	if passive == null:
		return
	passive.on_hit(self, enemy, amount, heavy)
	if not enemy.is_alive():
		passive.on_kill(self, enemy)''')

# --- отримана шкода: пасивка може врятувати ---
rep('''	current_hp = maxf(current_hp - amount, 0.0)
	_invulnerable_left = HURT_INVULNERABLE
	_combat_left = COMBAT_MEMORY''',
    '''	current_hp = maxf(current_hp - amount, 0.0)
	_invulnerable_left = HURT_INVULNERABLE
	_combat_left = COMBAT_MEMORY
	if passive != null:
		passive.on_damage_taken(self, amount)
		# Фенікс: смертельний удар не вбиває, а піднімає героя знову.
		if current_hp <= 0.0 and passive.on_lethal(self):
			_update_health_bar()
			health_changed.emit(current_hp, max_hp)
			return true''')

# --- оберт моделі ---
rep('''		_facing_angle = wrapf(_facing_angle + TAU / SKILL_TIME * delta, -PI, PI)''',
    '''		_facing_angle = wrapf(_facing_angle + TAU / _spin_total * delta, -PI, PI)''')

open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('player part 2 ok')
