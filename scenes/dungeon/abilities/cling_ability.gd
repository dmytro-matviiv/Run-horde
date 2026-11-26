extends EnemyAbility

## СЛІПИЙ КИДОК (Безликий послушник). Послушник неподалік від
## героя присідає й тремтить (windup, обличчя-маска спалахує білим), тоді
## кидається на героя по прямій. Влучив — чіпляється на спину: герой
## повільніший (slow), а послушник щосекунди б'є (damage), поки не
## мине hold секунд або герой не скине його ПЕРЕКАТОМ — тоді послушник
## падає оглушений. Удвох-утрьох вони висять гроном — котись!
## Налаштування: min, max, windup, speed, hold, slow, damage.

const COLOR := Color(0.95, 0.92, 0.8)

var _dir := Vector3.FORWARD
var _rush_left := 0.0
var _hold_left := 0.0
var _tick_left := 0.0
var _crouch: Tween
var _layer := 0

func _init() -> void:
	id = "cling"
	cooldown = 7.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 2.5)) or distance > float(config.get("max", 7.0)):
		return false
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.7))
	enemy.face_point(hero.global_position)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	# Присідає й тремтить.
	var model := enemy.get("_model") as Node3D
	if model != null:
		_crouch = model.create_tween()
		_crouch.tween_property(model, "scale:y", model.scale.y * 0.78, windup * 0.6)
		_crouch.tween_property(model, "scale:y", model.scale.y, windup * 0.4).set_trans(Tween.TRANS_BACK)
		CombatVfx.flash_model(model, Color(1.0, 1.0, 0.9), windup)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var to := hero.global_position - enemy.global_position
	to.y = 0.0
	_dir = to.normalized() if to.length() > 0.1 else -enemy.global_basis.z
	_rush_left = float(config.get("max", 7.0)) / float(config.get("speed", 14.0))
	var trail := CombatVfx.make_trail(COLOR, 0.35)
	enemy.add_child(trail)
	trail.position = Vector3.UP * 0.8
	enemy.get_tree().create_timer(_rush_left + 0.3).timeout.connect(trail.queue_free)

func tick(delta: float) -> void:
	super.tick(delta)
	if not enemy.is_alive():
		return
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		_rush_left = 0.0
		_release(false)
		return
	if _rush_left > 0.0:
		_rush_left -= delta
		var step := enemy.global_position + _dir * float(config.get("speed", 14.0)) * delta
		var rows: Variant = hero.get_parent().get("_map_rows")
		var cell := DungeonBuilder.cell_of(step)
		if rows is Array and not DungeonBuilder.is_walkable(rows, cell.x, cell.y):
			_rush_left = 0.0
			return
		enemy.global_position = Vector3(step.x, enemy.global_position.y, step.z)
		var off := hero.global_position - enemy.global_position
		off.y = 0.0
		if off.length() < 1.0:
			_rush_left = 0.0
			_grab(hero)
		return
	if _hold_left <= 0.0:
		return
	_hold_left -= delta
	# Висить на спині: трохи позаду й вище героя.
	var back := Vector3.ZERO
	if hero.has_method("get_facing"):
		back = -(hero.call("get_facing") as Vector3)
	enemy.global_position = hero.global_position + back * 0.45 + Vector3.UP * 0.5
	enemy.face_point(hero.global_position - back)
	if hero.has_method("apply_slow"):
		hero.apply_slow(float(config.get("slow", 0.6)), 0.2)
	# Перекат скидає.
	if float(hero.get("_roll_left")) > 0.0:
		_release(true)
		return
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = 1.0
		if hero.take_damage(damage()):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP * 1.1, COLOR, false)
	if _hold_left <= 0.0:
		_release(false)

func _grab(hero: Node3D) -> void:
	_hold_left = float(config.get("hold", 3.0))
	_tick_left = 0.3
	# Поки висить — не штовхає героя й не заважає йому тілом.
	_layer = enemy.collision_layer
	enemy.collision_layer = 0
	CombatVfx.impact(world(), hero.global_position + Vector3.UP * 1.0, COLOR, false)

func _release(shaken: bool) -> void:
	if _hold_left <= 0.0 and _layer == 0:
		return
	_hold_left = 0.0
	if _layer != 0:
		enemy.collision_layer = _layer
		_layer = 0
	var spot := enemy.global_position
	spot.y = DungeonBuilder.FLOOR_TOP
	enemy.teleport_to(spot)
	if shaken:
		CombatVfx.smoke_puff(world(), spot + Vector3.UP * 0.4, Color(0.8, 0.78, 0.7), 1.0)
		enemy.stun_for(1.6)

func is_busy() -> bool:
	return _rush_left > 0.0 or _hold_left > 0.0

func on_death() -> void:
	_rush_left = 0.0
	if _layer != 0 and is_instance_valid(enemy):
		enemy.collision_layer = _layer
		_layer = 0
	_hold_left = 0.0
