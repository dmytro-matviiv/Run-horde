import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:80])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


edit('scenes/world/player_3d.gd', [
('''signal died
signal health_changed(current: float, maximum: float)
''', '''signal died
signal health_changed(current: float, maximum: float)
## Удар героя влучив (для лічильника серії в данжі).
signal hit_landed(amount: float, crit: bool)
## Ворожий удар прилетів у перші миті перекату — ухилився в останню мить.
signal perfect_dodge
'''),
('''const HURT_INVULNERABLE := 0.35
''', '''const HURT_INVULNERABLE := 0.35

## ІДЕАЛЬНИЙ ПЕРЕКАТ: ворожий удар (меч, куля, вибух) влучив би, але
## герой саме котився. Світ на мить сповільнюється, наступні кілька
## секунд усі удари критичні, а перекат одразу готовий знову. Червоні
## зони замаху для цього й існують: перекотитись треба тоді, коли зона
## вже майже заповнилась.
const PERFECT_SLOWMO := 0.5
const PERFECT_SLOWMO_SCALE := 0.35
const PERFECT_CRIT_TIME := 2.0
const PERFECT_COLOR := Color(0.5, 0.95, 1.0)
'''),
('''var _roll_left := 0.0
var _dodge_cooldown_left := 0.0
var _invulnerable_left := 0.0
''', '''var _roll_left := 0.0
var _dodge_cooldown_left := 0.0
var _invulnerable_left := 0.0
## Скільки ще триває невразливість саме від перекату (не після поранення).
var _roll_guard_left := 0.0
var _perfect_this_roll := false
var _perfect_crit_left := 0.0
## Тимчасовий множник шкоди (серія ударів у данжі).
var _bonus_damage := 1.0
var _bonus_damage_left := 0.0
'''),
('''	_roll_left = DODGE_TIME
	_invulnerable_left = maxf(_invulnerable_left, DODGE_INVULNERABLE)''', '''	_roll_left = DODGE_TIME
	_invulnerable_left = maxf(_invulnerable_left, DODGE_INVULNERABLE)
	_roll_guard_left = DODGE_INVULNERABLE
	_perfect_this_roll = false'''),
('''	_attack_speed_left = maxf(_attack_speed_left - delta, 0.0)
	_shrine_left = maxf(_shrine_left - delta, 0.0)
''', '''	_attack_speed_left = maxf(_attack_speed_left - delta, 0.0)
	_shrine_left = maxf(_shrine_left - delta, 0.0)
	_roll_guard_left = maxf(_roll_guard_left - delta, 0.0)
	_perfect_crit_left = maxf(_perfect_crit_left - delta, 0.0)
	_bonus_damage_left = maxf(_bonus_damage_left - delta, 0.0)
'''),
('''func take_damage(amount: float) -> bool:
	if _dead or _invulnerable_left > 0.0:
		return false''', '''func take_damage(amount: float) -> bool:
	if _dead:
		return false
	if _invulnerable_left > 0.0:
		if _roll_guard_left > 0.0 and not _perfect_this_roll:
			_on_perfect_dodge()
		return false'''),
('''func _die() -> void:
	_dead = true''', '''func _on_perfect_dodge() -> void:
	_perfect_this_roll = true
	_perfect_crit_left = PERFECT_CRIT_TIME
	_dodge_cooldown_left = 0.0
	CombatVfx.hitstop(get_tree(), PERFECT_SLOWMO, PERFECT_SLOWMO_SCALE)
	CombatVfx.shockwave(get_parent(), global_position, 2.2, PERFECT_COLOR, 0.45)
	perfect_dodge.emit()

## Чи діють зараз гарантовані крити після ідеального перекату.
func has_perfect_crits() -> bool:
	return _perfect_crit_left > 0.0

## Тимчасово сильніші удари (серія ударів у данжі).
func add_damage_buff(multiplier: float, seconds: float) -> void:
	_bonus_damage = multiplier
	_bonus_damage_left = seconds

func _die() -> void:
	_dead = true'''),
('''	var crit := randf() < _crit_chance
	var amount := _damage * multiplier * (CRIT_MULTIPLIER if crit else 1.0)''', '''	var crit := randf() < _crit_chance or _perfect_crit_left > 0.0
	var amount := _damage * multiplier * (CRIT_MULTIPLIER if crit else 1.0)
	if _bonus_damage_left > 0.0:
		amount *= _bonus_damage'''),
('''	enemy.take_damage(amount, knockback * _knockback_factor, crit, heavy)
''', '''	enemy.take_damage(amount, knockback * _knockback_factor, crit, heavy)
	hit_landed.emit(amount, crit)
'''),
])
print('ok')
