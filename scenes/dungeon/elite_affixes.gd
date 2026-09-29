extends Node3D
class_name EliteAffixes

## ЕЛІТНИЙ ВОРОГ. Більший за звичайного, зі світним колом під ногами й
## підписом над головою ("Швидкий · Орк"), удвічі живучіший і з
## однією-двома рисами:
##   Швидкий     — бігає й б'є частіше;
##   Вибуховий   — упавши, за мить вибухає (червоне коло — тікай);
##   Щитоносець  — спереду тримає щит: 70% шкоди мимо. Бий збоку, ззаду
##                 або ногою — сильний удар ламає щит на кілька секунд;
##   Цілитель    — раз на кілька секунд лікує ворогів довкола: його
##                 треба вбити першим.
## Дає вчетверо більше досвіду й утричі більше золота.
##
## Вузол висить на самому ворогові (Enemy3D.elite) і сам малює свої
## ознаки — ворогові лишається кілька гачків (шкода, смерть).

enum Affix {SWIFT, VOLATILE, SHIELDED, MENDER}

const INFO := {
	Affix.SWIFT: {"title": "Швидкий", "color": Color(0.45, 0.95, 1.0)},
	Affix.VOLATILE: {"title": "Вибуховий", "color": Color(1.0, 0.5, 0.15)},
	Affix.SHIELDED: {"title": "Щитоносець", "color": Color(0.55, 0.72, 1.0)},
	Affix.MENDER: {"title": "Цілитель", "color": Color(0.45, 1.0, 0.5)},
}

## Щит: скільки шкоди пропускає спереду, яка ширина "переду", на скільки
## ламається від сильного удару.
const SHIELD_PASS := 0.3
const SHIELD_HALF_ARC := 1.2217   # 70 градусів
const SHIELD_BREAK := 3.0
## Цілитель: як часто, кого й скільки лікує.
const MEND_INTERVAL := 3.5
const MEND_RADIUS := 6.0
const MEND_SHARE := 0.12
## Вибуховий: скільки часу тікати і як далеко б'є.
const BLAST_DELAY := 0.9
const BLAST_RADIUS := 3.0
const BLAST_DAMAGE_MULT := 1.5

var affixes: Array[int] = []

var _enemy: Enemy3D
var _player: Node3D
var _aura: MeshInstance3D
var _shield: MeshInstance3D
var _shield_broken_left := 0.0
var _mend_left := MEND_INTERVAL

func has(affix: int) -> bool:
	return affixes.has(affix)

## Підпис: риси й ім'я — "Швидкий · Щитоносець · Орк".
func title_for(name: String) -> String:
	var parts: Array[String] = []
	for affix in affixes:
		parts.append(INFO[affix].title)
	parts.append(name)
	return " · ".join(parts)

## Викликає ворог, коли вже є модель і гравець.
func attach(enemy: Enemy3D, player: Node3D) -> void:
	_enemy = enemy
	_player = player
	var color: Color = INFO[affixes[0]].color
	# Світне кільце під ногами — еліту видно здалеку.
	_aura = CombatVfx.make_ground_marker(color, 0.75 + enemy.target_height * 0.35)
	_aura.set_instance_shader_parameter(&"wave", 1.0)
	_aura.set_instance_shader_parameter(&"progress", 0.9)
	_aura.position.y = 0.06
	add_child(_aura)
	var pulse := _aura.create_tween().set_loops()
	pulse.tween_method(func(value: float) -> void:
		_aura.set_instance_shader_parameter(&"progress", value), 0.72, 0.95, 0.8)
	pulse.tween_method(func(value: float) -> void:
		_aura.set_instance_shader_parameter(&"progress", value), 0.95, 0.72, 0.8)

	var label := Label3D.new()
	label.text = title_for(enemy.display_name)
	label.font_size = 64
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_size = 16
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.position.y = enemy.target_height + enemy.hover + 0.8
	label.visibility_range_end = 26.0
	add_child(label)

	if has(Affix.SHIELDED):
		_shield = CombatVfx.make_ground_marker(INFO[Affix.SHIELDED].color, 1.35, SHIELD_HALF_ARC)
		_shield.set_instance_shader_parameter(&"progress", 1.0)
		_shield.position.y = 0.08
		add_child(_shield)

## У скільки разів змінити шкоду по цьому ворогу. Щит тримає лише
## спереду; сильний удар його ламає.
func damage_factor(heavy: bool) -> float:
	if not has(Affix.SHIELDED) or _shield_broken_left > 0.0 or _player == null:
		return 1.0
	if heavy:
		_shield_broken_left = SHIELD_BREAK
		if _shield != null:
			_shield.visible = false
		CombatVfx.impact(_enemy.get_parent(), _enemy.global_position + Vector3.UP * _enemy.target_height * 0.5,
			INFO[Affix.SHIELDED].color, true)
		return 1.0
	var to_player := _player.global_position - _enemy.global_position
	to_player.y = 0.0
	if to_player.length() < 0.05:
		return 1.0
	var facing := _enemy.facing_vector()
	if facing.dot(to_player.normalized()) >= cos(SHIELD_HALF_ARC):
		return SHIELD_PASS
	return 1.0

func _physics_process(delta: float) -> void:
	if _enemy == null or not _enemy.is_alive():
		return
	if _shield != null:
		_shield.rotation.y = _enemy.facing_angle()
		if _shield_broken_left > 0.0:
			_shield_broken_left -= delta
			if _shield_broken_left <= 0.0:
				_shield.visible = true
	if has(Affix.MENDER) and not _enemy.is_sleeping():
		_mend_left -= delta
		if _mend_left <= 0.0:
			_mend_left = MEND_INTERVAL
			_mend()

## Зелена хвиля: вороги довкола (і сам цілитель) відновлюють здоров'я.
func _mend() -> void:
	var color: Color = INFO[Affix.MENDER].color
	CombatVfx.shockwave(_enemy.get_parent(), _enemy.global_position, MEND_RADIUS, color, 0.5)
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or not other.is_aim_target():
			continue
		if other.global_position.distance_to(_enemy.global_position) <= MEND_RADIUS:
			other.heal(other.max_hp * MEND_SHARE)

## Ворог упав. Вибуховий — за мить рветься на місці смерті: коло на
## підлозі заповнюється, хто лишився всередині — отримує.
func on_death() -> void:
	if not has(Affix.VOLATILE):
		return
	var parent := _enemy.get_parent()
	var center := _enemy.global_position
	var damage := _enemy.damage * BLAST_DAMAGE_MULT
	var color: Color = INFO[Affix.VOLATILE].color
	var marker := CombatVfx.make_ground_marker(color, BLAST_RADIUS)
	parent.add_child(marker)
	marker.global_position = center + Vector3(0, 0.07, 0)
	var player := _player
	var tween := marker.create_tween()
	tween.tween_method(func(value: float) -> void:
		marker.set_instance_shader_parameter(&"progress", value), 0.0, 1.0, BLAST_DELAY)
	tween.tween_callback(func() -> void:
		marker.queue_free()
		CombatVfx.shockwave(parent, center, BLAST_RADIUS, color, 0.35)
		CombatVfx.impact(parent, center + Vector3.UP * 0.8, color, true)
		AudioManager.play(&"explosion")
		if is_instance_valid(player):
			var offset := player.global_position - center
			offset.y = 0.0
			if offset.length() <= BLAST_RADIUS:
				player.take_damage(damage))
