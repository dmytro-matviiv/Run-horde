extends EnemyAbility

## РОЗПЕЧЕНА ШКІРА (Владика Магми). Владика розжарюється (windup) і time
## секунд світиться: кожен удар по ньому обпікає героя у відповідь
## (reflect частка завданої шкоди, не більше cap від шкоди Владики).
## Поки світиться — відійди й перечекай або бий рідше.
## Налаштування: time, reflect, cap.

const COLOR := Color(1.0, 0.5, 0.1)

var _hot_left := 0.0
var _burn_left := 0.0
var _overlay: ShaderMaterial

func _init() -> void:
	id = "molten_skin"
	cooldown = 15.0

func try_use(_distance: float) -> bool:
	if _hot_left > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.6)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_hot_left = float(config.get("time", 4.0))
	if _overlay == null:
		# Розплавлена кірка поверх тіла: лава тече по шкірі Владики.
		_overlay = BossFx.molten_overlay()
		for node in CombatVfx.body_meshes(enemy._model):
			(node as GeometryInstance3D).material_overlay = _overlay
	CombatVfx.smoke_puff(world(), enemy.global_position + Vector3.UP * enemy.target_height * 0.5, Color(0.25, 0.18, 0.15), 1.8)

func tick(delta: float) -> void:
	super.tick(delta)
	_burn_left -= delta
	if _hot_left <= 0.0:
		return
	_hot_left -= delta
	if _overlay != null:
		_overlay.set_shader_parameter(&"alpha", 0.0 if _hot_left <= 0.0 else 0.7 + 0.15 * sin(Time.get_ticks_msec() * 0.012))

func is_hot() -> bool:
	return _hot_left > 0.0

func filter_damage(amount: float, _heavy: bool) -> float:
	if _hot_left <= 0.0 or _burn_left > 0.0:
		return amount
	var hero := player()
	if hero != null and is_instance_valid(hero):
		_burn_left = 0.3
		var back := minf(amount * float(config.get("reflect", 0.35)), enemy.damage * float(config.get("cap", 0.6)))
		if hero.take_damage(back):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, false)
	return amount

func on_death() -> void:
	_hot_left = 0.0
	if _overlay != null:
		_overlay.set_shader_parameter(&"alpha", 0.0)
