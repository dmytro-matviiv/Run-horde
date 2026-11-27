extends EnemyAbility

## ТВЕРДНЕННЯ (Обсидіановий голем). Кожен удар по голему загартовує його
## склоподібну шкіру: мінус step шкоди за удар (до max). Варто героєві
## перестати бити на calm секунд — шкіра знову крихка. Бий серіями з
## паузами, а не безперервно.
## Налаштування: step, max, calm.

const COLOR := Color(1.0, 0.45, 0.15)

var _stacks := 0
var _calm_left := 0.0

func _init() -> void:
	id = "harden"
	cooldown = 0.0

func filter_damage(amount: float, _heavy: bool) -> float:
	var cut := minf(_stacks * float(config.get("step", 0.12)), float(config.get("max", 0.7)))
	_stacks += 1
	_calm_left = float(config.get("calm", 1.4))
	_paint()
	return amount * (1.0 - cut)

func tick(delta: float) -> void:
	super.tick(delta)
	if _stacks <= 0:
		return
	_calm_left -= delta
	if _calm_left <= 0.0:
		_stacks = 0
		_paint()
		CombatVfx.impact(world(), enemy.global_position + Vector3.UP * enemy.target_height * 0.6, COLOR, false)

func damage_cut() -> float:
	return minf(_stacks * float(config.get("step", 0.12)), float(config.get("max", 0.7)))

## Що твердіший — то густіше чорне скло поверх (накладка на модель).
var _overlay: StandardMaterial3D

func _paint() -> void:
	var t := damage_cut() / maxf(float(config.get("max", 0.7)), 0.01)
	if _overlay == null:
		_overlay = StandardMaterial3D.new()
		_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay.albedo_color = Color(0.05, 0.05, 0.1, 0.0)
		_overlay.metallic = 0.8
		_overlay.roughness = 0.05
		for node in CombatVfx.body_meshes(enemy._model):
			(node as GeometryInstance3D).material_overlay = _overlay
	_overlay.albedo_color.a = 0.75 * t
