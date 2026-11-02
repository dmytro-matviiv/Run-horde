# 4-й данж: герой — холодний дотик привида (повільніші удари) і підкидання
# хробаком (збиває з ніг і підкидає модель).
import sys
P = r"D:\Claude code\idle survivor_like\scenes\world\player_3d.gd"
s = open(P, encoding="utf-8").read()


def rep(old, new, count=1):
    global s
    n = s.count(old)
    if n != count:
        sys.exit("NOT FOUND x%d (want %d): %r" % (n, count, old[:80]))
    s = s.replace(old, new)


rep("""var _attack_speed_buff := 1.0
var _attack_speed_left := 0.0
""", """var _attack_speed_buff := 1.0
var _attack_speed_left := 0.0
## Холодний дотик (Кладовищенський привид): удари повільніші, доки не мине.
var _chill_factor := 1.0
var _chill_left := 0.0
var _chill_marker: MeshInstance3D
""")
rep("""func attack_speed() -> float:
	return _attack_speed * (_attack_speed_buff if _attack_speed_left > 0.0 else 1.0)
""", """func attack_speed() -> float:
	return _attack_speed * (_attack_speed_buff if _attack_speed_left > 0.0 else 1.0) * _chill()

func _chill() -> float:
	return _chill_factor if _chill_left > 0.0 else 1.0

## Холодний дотик: seconds секунд удари на (1 - factor) повільніші, під
## героєм блідо-блакитне коло.
func chill_attacks(factor: float, seconds: float) -> void:
	if _dead:
		return
	_chill_factor = factor
	_chill_left = maxf(_chill_left, seconds)
	_apply_attack_speed()
	CombatVfx.flash_model(model, Color(0.6, 0.85, 1.0), 0.2)
	if _chill_marker == null:
		_chill_marker = CombatVfx.make_ground_marker(Color(0.55, 0.8, 1.0, 0.6), 0.6)
		_chill_marker.set_instance_shader_parameter(&"progress", 1.0)
		_chill_marker.position.y = 0.06
		add_child(_chill_marker)
	_chill_marker.visible = true

## Підкидає (хробак вистрибнув під героєм): збиває з ніг на seconds, а
## модель злітає вгору й падає.
func toss(seconds: float) -> void:
	if _dead or _roll_left > 0.0:
		return
	knock_down(Vector3.ZERO, seconds)
	var rest := model.position.y
	var tween := model.create_tween()
	tween.tween_property(model, "position:y", rest + 1.3, seconds * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(model, "position:y", rest, seconds * 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
""")
rep("""	_bonus_damage_left = maxf(_bonus_damage_left - delta, 0.0)
	if _slow_left > 0.0:""", """	_bonus_damage_left = maxf(_bonus_damage_left - delta, 0.0)
	if _chill_left > 0.0:
		_chill_left -= delta
		if _chill_left <= 0.0:
			_apply_attack_speed()
			if _chill_marker != null:
				_chill_marker.visible = false
	if _slow_left > 0.0:""")
rep("""	_attack_time += delta * _attack_speed
""", """	_attack_time += delta * _attack_speed * _chill()
""")
open(P, "w", encoding="utf-8").write(s)
print("OK player")
