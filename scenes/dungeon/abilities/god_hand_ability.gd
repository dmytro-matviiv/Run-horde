extends EnemyAbility

## ДОЛОНЯ БОГА (Безликий Бог). З неба падає велетенська кам'яна долоня —
## count разів поспіль, кожна туди, де герой зараз, і кожна більша за
## попередню (radius + grow). Перед ударом — тінь на підлозі (warn).
## Не зупиняйся: кожна наступна долоня ширша.
## Налаштування: count, radius, grow, warn, gap, damage.

const COLOR := Color(1.0, 0.9, 0.55, 0.85)

var _queue := 0
var _mark: MeshInstance3D
var _hand: Node3D
var _shadow: MeshInstance3D
var _spot := Vector3.ZERO
var _radius := 0.0
var _warn_left := 0.0
var _gap_left := 0.0

func _init() -> void:
	id = "god_hand"
	cooldown = 13.0

func try_use(_distance: float) -> bool:
	if _queue > 0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.6)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_queue = int(config.get("count", 3))
	_radius = float(config.get("radius", 1.8))
	_gap_left = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	if _queue <= 0:
		return
	if _warn_left > 0.0:
		_warn_left -= delta
		var warn := float(config.get("warn", 0.9))
		var t := clampf(1.0 - _warn_left / warn, 0.0, 1.0)
		if is_instance_valid(_mark):
			CombatVfx.set_param(_mark, &"progress", t)
		if is_instance_valid(_hand):
			_hand.global_position = _spot + Vector3.UP * lerpf(9.0, 0.0, t * t)
		if is_instance_valid(_shadow):
			(_shadow.material_override as StandardMaterial3D).albedo_color.a = 0.7 * t
		if _warn_left <= 0.0:
			_slam()
		return
	_gap_left -= delta
	if _gap_left > 0.0:
		return
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		_queue = 0
		return
	_spot = Vector3(hero.global_position.x, DungeonBuilder.FLOOR_TOP, hero.global_position.z)
	_mark = CombatVfx.make_telegraph(COLOR, _radius, PI, false)
	world().add_child(_mark)
	_mark.global_position = _spot + Vector3.UP * 0.05
	# Кам'яна долоня бога падає з неба; на підлозі — її тінь, що густішає.
	_hand = BossFx.stone_hand(_radius * 1.1)
	world().add_child(_hand)
	_hand.global_position = _spot + Vector3.UP * 9.0
	_hand.rotation.y = randf() * TAU
	_shadow = Fx.make_sprite("smoke_10", Color(0.0, 0.0, 0.0, 0.0), true)
	world().add_child(_shadow)
	_shadow.global_position = _spot + Vector3.UP * 0.07
	_shadow.scale = Vector3.ONE * _radius * 2.4
	_warn_left = float(config.get("warn", 0.9))

func _slam() -> void:
	CombatVfx.ground_hit(world(), _spot, _radius)
	var hero := player()
	if hero != null and is_instance_valid(hero):
		var offset := hero.global_position - _spot
		offset.y = 0.0
		if offset.length() <= _radius + 0.2 and hero.take_damage(damage()):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
	if is_instance_valid(_mark):
		_mark.queue_free()
	if is_instance_valid(_shadow):
		_shadow.queue_free()
	_shadow = null
	if is_instance_valid(_hand):
		var hand := _hand
		var tween := hand.create_tween()
		tween.tween_interval(0.25)
		tween.tween_property(hand, "position:y", hand.position.y + 9.0, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(hand.queue_free)
	_mark = null
	_hand = null
	_queue -= 1
	_radius += float(config.get("grow", 0.6))
	_gap_left = float(config.get("gap", 0.35))

func on_death() -> void:
	_queue = 0
	if is_instance_valid(_mark):
		_mark.queue_free()
	if is_instance_valid(_hand):
		_hand.queue_free()
	if is_instance_valid(_shadow):
		_shadow.queue_free()
