# 4-й данж (Кістяний Погост): Enemy3D і EnemyAbility — прохід крізь стіни,
# частково видимий (лише ланцюг), провалитись під землю, посилення тотема,
# кістяний щит, холодний дотик, стоїть на місці ("anchored"), хуки
# on_lethal / on_strike.
import sys
P = r"D:\Claude code\idle survivor_like\scenes\dungeon\enemy_3d.gd"
s = open(P, encoding="utf-8").read()


def rep(old, new, count=1):
    global s
    n = s.count(old)
    if n != count:
        sys.exit("NOT FOUND x%d (want %d): %r" % (n, count, old[:90]))
    s = s.replace(old, new)


rep("""var invulnerable := false
""", """var invulnerable := false
## Приціл героя сюди не наводиться (бос розсипався купою кісток — бити
## треба череп поруч).
var untargetable := false
## Літає крізь стіни й надгробки ("phasing" в описі): іде навпростець, без
## зіткнень, бачить героя крізь стіни.
var phasing := false
## Посилення тотема: шкода множиться, поки нитка тримається.
var _base_damage := 0.0
var _empower_left := 0.0
## Кістяний щит тотема ("bone_shield"): ударили — щит на seconds, він
## поглинає перший наступний удар; після того cooldown секунд нового нема.
const BONE_SHIELD_COLOR := Color(0.95, 0.9, 0.7)
var _bone_shield_left := 0.0
var _bone_shield_wait := 0.0
""")

# phasing — з опису
rep("""	attack_range = float(definition.get("attack_range", attack_range))
	if definition.has("projectile"):""", """	attack_range = float(definition.get("attack_range", attack_range))
	phasing = bool(definition.get("phasing", false))
	if definition.has("projectile"):""")

# у setup: без зіткнень
rep("""	if definition.has("lifetime"):
		_life_left = float(definition.lifetime)
""", """	if definition.has("lifetime"):
		_life_left = float(definition.lifetime)
	if phasing:
		collision_mask = 0
		_grounded = true
""")

# set_hidden: частково видимий
rep("""func set_hidden(hidden: bool) -> void:
	_hidden = hidden
	_model.visible = not hidden
""", """## keep_part — частина моделі, що лишається видимою (привид зникає, а
## ланцюг на руці видно): меші, у назві яких є keep_part.
func set_hidden(hidden: bool, keep_part: String = "") -> void:
	_hidden = hidden
	_model.visible = not hidden or keep_part != ""
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visible = not hidden or (keep_part != "" and keep_part in String(node.name))
""")

# провалитись під землю + посилення
rep("""## Захист тотема: поки нитка тримається, проходить лише частка шкоди.""", """## Провалитись під підлогу (чаклун тікає в могилу): модель опускається за
## seconds, ворог тим часом стоїть. Назад — emerge().
func burrow_down(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_model, "position:y", _model.position.y - target_height - 0.3, seconds).set_ease(Tween.EASE_IN)
	_hold_still(seconds)

## Посилення тотема: шкода ворога x factor, поки його оновлюють (seconds).
func apply_empower(factor: float, seconds: float) -> void:
	if _dying:
		return
	if _empower_left <= 0.0:
		_base_damage = damage
	damage = _base_damage * factor
	_empower_left = seconds

func is_empowered() -> bool:
	return _empower_left > 0.0

## Захист тотема: поки нитка тримається, проходить лише частка шкоди.""")

rep("""func is_aim_target() -> bool:
	return not _dying and not _hidden
""", """func is_aim_target() -> bool:
	return not _dying and not _hidden and not untargetable
""")

# фізика: кістяний щит тікає й у нерухомого; посилення спадає; рух крізь стіни
rep("""	if _life_left > 0.0:
		_life_left -= delta
		if _life_left <= 0.0:
			take_damage(1.0e9)
			return
	if stationary:""", """	if _life_left > 0.0:
		_life_left -= delta
		if _life_left <= 0.0:
			take_damage(1.0e9)
			return
	if definition.has("bone_shield"):
		_tick_bone_shield(delta)
	if _empower_left > 0.0:
		_empower_left -= delta
		if _empower_left <= 0.0:
			damage = _base_damage
	if stationary:""")
rep("""		velocity.x = 0.0
		velocity.z = 0.0
		_play("Idle")

	_move(delta)
""", """		velocity.x = 0.0
		velocity.z = 0.0
		_play("Idle")

	if phasing:
		_move_phasing(delta)
	else:
		_move(delta)
""")

rep("""## Сусіди надто близько — відсуваємось (з фізикою: не в стіну й не в стіл).""", """## Рух крізь стіни (привид): без фізики, просто зсув; висота — підлога.
func _move_phasing(delta: float) -> void:
	var pace := _pace()
	global_position.x += (velocity.x * pace + _knockback.x) * delta
	global_position.z += (velocity.z * pace + _knockback.z) * delta
	global_position.y = DungeonBuilder.FLOOR_TOP
	velocity.y = 0.0
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)

## Навпростець до героя (привид летить крізь стіни).
func _chase_direct(delta: float) -> void:
	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		return
	direction = direction.normalized()
	var speed := move_toward(Vector2(velocity.x, velocity.z).length(), move_speed, 12.0 * delta)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_face(direction, 10.0)
	_play("Walk")

## Кістяний щит: тікає час щита й перепочинку; щит скінчився — сфера гасне.
func _tick_bone_shield(delta: float) -> void:
	_bone_shield_wait = maxf(_bone_shield_wait - delta, 0.0)
	if _bone_shield_left > 0.0:
		_bone_shield_left -= delta
		if _bone_shield_left <= 0.0:
			_drop_absorb()
			_bone_shield_wait = float(definition.bone_shield.get("cooldown", 3.0))

## Сусіди надто близько — відсуваємось (з фізикою: не в стіну й не в стіл).""")

# melee: навпростець / стоїть на місці
rep("""func _process_melee(distance: float, delta: float) -> void:
	# Далеко — або близько, але між нами стіна: іде маршрутом в обхід.
	if distance > attack_range or not _sees_player():
		_move_along_path(delta)
		return
""", """func _process_melee(distance: float, delta: float) -> void:
	# Далеко — або близько, але між нами стіна: іде маршрутом в обхід.
	if distance > attack_range or not _sees_player():
		# "anchored": не ходить (хробак на поверхні) — лише дивиться на героя.
		if definition.get("anchored", false):
			velocity.x = 0.0
			velocity.z = 0.0
			_face_player(8.0)
			_play("Idle")
		elif phasing:
			_chase_direct(delta)
		else:
			_move_along_path(delta)
		return
""")

rep("""func _has_line_of_sight() -> bool:
	var from""", """func _has_line_of_sight() -> bool:
	if phasing:
		return true
	var from""")

# холодний дотик + on_strike
rep("""		if _zone_covers(_player.global_position, true):
			_player.take_damage(damage * 1.5)
		else:
			_check_late_dodge(true)
		return
	# Звичайний удар влучає, лише якщо герой досі в червоній зоні.
	if _zone_covers(_player.global_position, false) and _has_line_of_sight():
		_player.take_damage(damage)
	else:
		_check_late_dodge(false)
""", """		if _zone_covers(_player.global_position, true):
			_player.take_damage(damage * 1.5)
		else:
			_check_late_dodge(true)
		for ability in abilities:
			ability.on_strike()
		return
	# Звичайний удар влучає, лише якщо герой досі в червоній зоні.
	if _zone_covers(_player.global_position, false) and _has_line_of_sight():
		# Холодний дотик ("chill"): влучив — удари героя повільніші.
		if _player.take_damage(damage) and definition.has("chill") and _player.has_method("chill_attacks"):
			_player.chill_attacks(float(definition.chill.get("factor", 0.7)), float(definition.chill.get("seconds", 3.0)))
	else:
		_check_late_dodge(false)
	for ability in abilities:
		ability.on_strike()
""")

# кістяний щит у take_damage
rep("""	if _dormant:
		_wake()
	# Вогонь розтоплює крижаний щит одразу, і далі голем вразливіший.""", """	if _dormant:
		_wake()
	# Кістяний щит: стоїть — поглинає цей удар і розсипається; нема й
	# перепочинок минув — удар проходить, а щит здіймається.
	if definition.has("bone_shield"):
		if _bone_shield_left > 0.0:
			_bone_shield_left = 0.0
			_bone_shield_wait = float(definition.bone_shield.get("cooldown", 3.0))
			_drop_absorb()
			CombatVfx.impact(get_parent(), global_position + Vector3.UP * target_height * 0.6, BONE_SHIELD_COLOR, true)
			CombatVfx.shockwave(get_parent(), global_position, 1.6, BONE_SHIELD_COLOR, 0.3)
			last_hit_source = &""
			return
		if _bone_shield_wait <= 0.0:
			_bone_shield_left = float(definition.bone_shield.get("seconds", 3.0))
			add_absorb(0.0, _bone_shield_left, BONE_SHIELD_COLOR)
	# Вогонь розтоплює крижаний щит одразу, і далі голем вразливіший.""")

# on_lethal
rep("""	if current_hp <= 0.0:
		_die()
		return
	for ability in abilities:
		ability.on_damaged()
""", """	if current_hp <= 0.0:
		# Здібність може не дати впасти (Кістяний Володар розсипається й
		# збирається знову).
		for ability in abilities:
			if ability.on_lethal():
				return
		_die()
		return
	for ability in abilities:
		ability.on_damaged()
""")

rep(""""Stunned", "Idle_Rage", "Channel"])""", """"Stunned", "Idle_Rage", "Channel", "Down"])""")
open(P, "w", encoding="utf-8").write(s)

P2 = r"D:\Claude code\idle survivor_like\scenes\dungeon\abilities\enemy_ability.gd"
s = open(P2, encoding="utf-8").read()
rep("""## Ворога вдарили (і він ще живий).
func on_damaged() -> void:
	pass
""", """## Ворога вдарили (і він ще живий).
func on_damaged() -> void:
	pass

## Удар мав би вбити ворога. true — здібність не дала впасти (сама
## подбала про здоров'я й про те, що далі).
func on_lethal() -> bool:
	return false

## Звичайний удар ворога щойно впав (влучив чи ні).
func on_strike() -> void:
	pass
""")
open(P2, "w", encoding="utf-8").write(s)
print("OK enemy")
