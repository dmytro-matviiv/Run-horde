extends EnemyAbility

## "ЗАВМРИ" (Вартовий-статуя, Скарбниця Тіней). Поки герой рухається —
## статуя мчить на нього (rush — множник швидкості). Герой постояв still
## секунд — статуя кам'яніє: стоїть, не б'є й отримує frozen_factor шкоди.
## Ворухнувся — оживає. Перемога — стояти на місці й бити.

const STONE := Color(0.72, 0.72, 0.68, 0.85)

var _still_time := 0.0
var _frozen := false
var _base_speed := 0.0
var _stone: StandardMaterial3D

func _init() -> void:
	id = "freeze_tag"
	cooldown = 0.0

func setup(owner: Enemy3D, settings: Dictionary) -> void:
	super.setup(owner, settings)
	_base_speed = owner.move_speed
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = STONE
	_stone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stone.roughness = 1.0

func is_busy() -> bool:
	return _frozen

func tick(delta: float) -> void:
	super.tick(delta)
	var hero := player()
	if hero == null or not is_instance_valid(hero) or not enemy.is_alive() or not enemy.is_aggro():
		return
	var moving: bool = hero.is_moving() if hero.has_method("is_moving") else true
	if moving:
		_still_time = 0.0
		if _frozen:
			_set_frozen(false)
		enemy.move_speed = _base_speed * float(config.get("rush", 1.8))
	else:
		_still_time += delta
		if not _frozen and _still_time >= float(config.get("still", 0.4)):
			_set_frozen(true)
	if _frozen:
		enemy.velocity = Vector3.ZERO

func _set_frozen(on: bool) -> void:
	_frozen = on
	enemy.move_speed = _base_speed
	for node in CombatVfx.body_meshes(enemy):
		(node as GeometryInstance3D).material_overlay = _stone if on else null
	if on:
		enemy.play_loop("Frozen")
		CombatVfx.smoke_puff(world(), enemy.global_position + Vector3.UP * enemy.target_height * 0.5, STONE, 1.2)
	else:
		CombatVfx.shockwave(world(), enemy.global_position, 1.4, Color(1.0, 0.85, 0.35, 0.8), 0.25)

func filter_damage(amount: float, _heavy: bool) -> float:
	return amount * (float(config.get("frozen_factor", 2.0)) if _frozen else 1.0)

func on_death() -> void:
	if _frozen:
		_set_frozen(false)
