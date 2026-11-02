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
('''var _roll_guard_left := 0.0
var _perfect_this_roll := false''', '''var _roll_guard_left := 0.0
var _roll_origin := Vector3.INF
var _roll_started_msec := 0
var _perfect_this_roll := false'''),
('''	_roll_guard_left = DODGE_INVULNERABLE
	_perfect_this_roll = false''', '''	_roll_guard_left = DODGE_INVULNERABLE
	_roll_origin = global_position
	_roll_started_msec = Time.get_ticks_msec()
	_perfect_this_roll = false'''),
('''## Чи діють зараз гарантовані крити після ідеального перекату.''', '''## Звідки герой почав перекат, якщо це було щойно (не давніше за window
## секунд) і ідеальний перекат за нього ще не зараховано; інакше INF.
## Ворог перевіряє: чи накрив би його удар ту точку — тоді герой
## вискочив із червоної зони в останню мить.
func late_dodge_origin(window: float) -> Vector3:
	if _perfect_this_roll or _roll_origin == Vector3.INF:
		return Vector3.INF
	if Time.get_ticks_msec() - _roll_started_msec > int(window * 1000.0):
		return Vector3.INF
	return _roll_origin

func register_perfect_dodge() -> void:
	if not _perfect_this_roll and not _dead:
		_on_perfect_dodge()

## Чи діють зараз гарантовані крити після ідеального перекату.'''),
])

edit('scenes/dungeon/enemy_3d.gd', [
('''const SLAM_EVERY := 3
''', '''const SLAM_EVERY := 3
## Ідеальний перекат: герой почав перекат у червоній зоні не раніше, ніж
## за стільки секунд до удару, — і вискочив.
const LATE_DODGE_WINDOW := 0.3
'''),
('''		if offset.length() <= SLAM_RADIUS + 0.3:
			_player.take_damage(damage * 1.5)
		return
	# Звичайний удар влучає, лише якщо герой досі в червоній зоні.
	var in_reach := offset.length() <= _melee_reach() + 0.35
	var in_front := offset.length() < 0.5 or _model_forward().angle_to(offset.normalized()) <= deg_to_rad(65.0)
	if in_reach and in_front and _has_line_of_sight():
		_player.take_damage(damage)''', '''		if _zone_covers(_player.global_position, true):
			_player.take_damage(damage * 1.5)
		else:
			_check_late_dodge(true)
		return
	# Звичайний удар влучає, лише якщо герой досі в червоній зоні.
	if _zone_covers(_player.global_position, false) and _has_line_of_sight():
		_player.take_damage(damage)
	else:
		_check_late_dodge(false)

## Чи накриває червона зона удару точку на підлозі.
func _zone_covers(point: Vector3, slam: bool) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	if slam:
		return offset.length() <= SLAM_RADIUS + 0.3
	var in_reach := offset.length() <= _melee_reach() + 0.35
	var in_front := offset.length() < 0.5 or _model_forward().angle_to(offset.normalized()) <= deg_to_rad(65.0)
	return in_reach and in_front

## Герой вискочив перекатом із зони в останню мить — ідеальний перекат.
func _check_late_dodge(slam: bool) -> void:
	if not _player.has_method("late_dodge_origin"):
		return
	var origin: Vector3 = _player.late_dodge_origin(LATE_DODGE_WINDOW)
	if origin != Vector3.INF and _zone_covers(origin, slam):
		_player.register_perfect_dodge()'''),
])
print('ok')
