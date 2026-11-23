extends EnemyAbility

## ХУРТОВИНА (Ярл Вічної Зими). На time секунд залу накриває хуртовина,
## а довкола Ярла спалахують braziers жаровень. Поза жаровнями герой
## мерзне: щосекунди +1 холод (цифра над головою). Набрав freeze — замерз
## на stun секунд (шкода). Біля жаровні (warm метрів) холод тане. Бийся
## біля вогню — та Ярл не завжди стоїть поруч із ним.
## Налаштування: time, braziers, ring, warm, freeze, stun, damage.

const COLOR := Color(0.75, 0.9, 1.0)
const FIRE := Color(1.0, 0.55, 0.15)

var _time_left := 0.0
var _cold := 0.0
var _braziers: Array = []
var _label: Label3D
var _snow: CPUParticles3D

func _init() -> void:
	id = "blizzard"
	cooldown = 26.0

func try_use(_distance: float) -> bool:
	if _time_left > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 1.0)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_clear()
	_time_left = float(config.get("time", 12.0))
	_cold = 0.0
	var center := Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP, enemy.global_position.z)
	var count := int(config.get("braziers", 3))
	var start := randf() * TAU
	for i in count:
		var angle := start + TAU * i / count
		var spot := center + Vector3(cos(angle), 0.0, sin(angle)) * float(config.get("ring", 5.5))
		_braziers.append(_make_brazier(spot))
	_label = Label3D.new()
	_label.font_size = 90
	_label.pixel_size = 0.005
	_label.outline_size = 18
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = COLOR
	world().add_child(_label)
	_snow = BossFx.snowfall()
	world().add_child(_snow)

## Жаровня: залізна чаша на ніжках із жаром і полум'ям (BossFx).
func _make_brazier(spot: Vector3) -> Node3D:
	var root := BossFx.brazier(float(config.get("warm", 2.2)))
	world().add_child(root)
	root.global_position = spot
	root.scale = Vector3(1.0, 0.01, 1.0)
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return root

func tick(delta: float) -> void:
	super.tick(delta)
	if _time_left <= 0.0:
		return
	_time_left -= delta
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		_clear()
		return
	if _snow != null:
		_snow.global_position = hero.global_position + Vector3(-2.0, 5.0, 0.0)
	var warm := false
	for brazier: Node3D in _braziers:
		var offset := hero.global_position - brazier.global_position
		offset.y = 0.0
		if offset.length() <= float(config.get("warm", 2.2)):
			warm = true
			break
	_cold = maxf(_cold - delta * 2.5, 0.0) if warm else _cold + delta
	var freeze := float(config.get("freeze", 5.0))
	if _cold >= freeze:
		_cold = 0.0
		if hero.take_damage(damage()):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
		if hero.has_method("stun"):
			hero.stun(float(config.get("stun", 1.6)))
	if _label != null:
		_label.global_position = hero.global_position + Vector3.UP * 2.6
		_label.text = "Холод %d/%d" % [int(_cold), int(freeze)] if _cold >= 1.0 else ""
		_label.modulate = COLOR.lerp(Color(0.3, 0.5, 1.0), _cold / freeze)
	if _time_left <= 0.0:
		_clear()

func on_death() -> void:
	_clear()

func _clear() -> void:
	_time_left = 0.0
	for brazier: Node3D in _braziers:
		if is_instance_valid(brazier):
			brazier.queue_free()
	_braziers.clear()
	if _label != null and is_instance_valid(_label):
		_label.queue_free()
	_label = null
	if _snow != null and is_instance_valid(_snow):
		_snow.queue_free()
	_snow = null
