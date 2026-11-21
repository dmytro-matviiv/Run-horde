extends EnemyAbility

## ПЕРЕГРІВ (Залізний голем-заготовка, Кузня Присмерку). Ритм бою
## "тікай — бий":
##   розжарений (hot с) — отримує лише hot_factor шкоди й лишає за собою
##     розплавлені сліди (калюжі, що печуть);
##   перегрівся (vent с) — випускає пару, завмирає й отримує vent_factor
##     шкоди (удвічі більше).
## Налаштування: hot, vent, hot_factor, vent_factor, step (м між слідами),
## pool (с калюжі), pool_damage (частка шкоди голема за тік).

const HOT_COLOR := Color(1.0, 0.45, 0.12)
const STEAM := Color(0.85, 0.85, 0.85, 0.7)

var _hot := true
var _phase_left := 0.0
var _last_step := Vector3.INF
var _steam_left := 0.0

func _init() -> void:
	id = "overheat"
	cooldown = 0.0

func setup(owner: Enemy3D, settings: Dictionary) -> void:
	super.setup(owner, settings)
	_phase_left = float(config.get("hot", 8.0))

func tick(delta: float) -> void:
	super.tick(delta)
	if not enemy.is_alive():
		return
	_phase_left -= delta
	if _hot:
		_leave_footprint()
		if _phase_left <= 0.0:
			_start_vent()
	else:
		_steam_left -= delta
		if _steam_left <= 0.0:
			_steam_left = 0.35
			CombatVfx.smoke_puff(world(), enemy.global_position + Vector3.UP * enemy.target_height * 0.95
				+ Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)), STEAM, 1.1)
		if _phase_left <= 0.0:
			_hot = true
			_phase_left = float(config.get("hot", 8.0))
			CombatVfx.flash_model(enemy, HOT_COLOR, 0.25)

func _leave_footprint() -> void:
	var here := enemy.global_position
	if _last_step == Vector3.INF:
		_last_step = here
		return
	if here.distance_to(_last_step) < float(config.get("step", 1.4)):
		return
	_last_step = here
	HazardPool.spawn(world(), Vector3(here.x, DungeonBuilder.FLOOR_TOP, here.z), player(), 0.7,
		enemy.damage * float(config.get("pool_damage", 0.15)), float(config.get("pool", 2.5)), HOT_COLOR)

func _start_vent() -> void:
	_hot = false
	var vent := float(config.get("vent", 3.0))
	_phase_left = vent
	_steam_left = 0.0
	enemy.hold_still(vent)
	enemy.play_loop("Stunned")
	CombatVfx.shockwave(world(), enemy.global_position, 1.8, STEAM, 0.4)

func filter_damage(amount: float, _heavy: bool) -> float:
	if _hot:
		return amount * float(config.get("hot_factor", 0.5))
	CombatVfx.impact(world(), enemy.global_position + Vector3.UP * enemy.target_height * 0.6, HOT_COLOR, false)
	return amount * float(config.get("vent_factor", 2.0))
